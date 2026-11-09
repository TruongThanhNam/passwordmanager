// Sinh fixture golden `test/fixtures/vault/v1/{header,cards,recent,README.md}`
// theo AD-20, tất định (cùng đầu vào → cùng byte).
//
// Cố ý không import `lib/` của app: script tự ghép byte theo đặc tả để golden
// test bắt được lỗi của codec trong app. Chỉ dùng dữ liệu giả.
//
// Chạy trong pak_manager/:
//   dart run tool/fixtures/gen_vault_v1.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

const _outDir = 'test/fixtures/vault/v1';

// ---- Đầu vào cố định (ghi lại trong README.md) ----

const _password = 'fixture-only correct horse 42';
const _opsLimit = 2;
const _memLimit = 19 * 1024 * 1024;

/// Dãy byte cố định `start, start+1, …` (mod 256).
Uint8List _seq(int start, int length) =>
    Uint8List.fromList([for (var i = 0; i < length; i++) (start + i) & 0xff]);

final _dek = _seq(0x00, 32);
final _salt = _seq(0x20, 16);
final _wrapNonce = _seq(0x40, 24);
final _cardsNonce = _seq(0x60, 24);
final _recentNonce = _seq(0x80, 24);

final _cardsJson = <String, Object?>{
  'v': 1,
  'cards': [
    <String, Object?>{
      'id': '3f2b8c1e-5d4a-4e6f-9a7b-1c2d3e4f5a6b',
      'title': 'Example Mail',
      'username': 'alice@example.com',
      'password': 'Fake-Pass-0001!',
      'note': '',
      'createdAt': 1762300800000,
    },
    <String, Object?>{
      'id': 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
      'title': 'Ngân hàng giả',
      'username': 'nguyen.van.a',
      'password': 'p@ss word ~ demo',
      'note': 'Ghi chú: dữ liệu giả, không dùng thật.',
      'createdAt': 1762387200000,
    },
  ],
};

final _recentJson = <String, Object?>{
  'v': 1,
  'items': [
    <String, Object?>{
      'password': 'K9#mVq2!xLp7wZr',
      'recordedAt': 1762390800000,
    },
  ],
};

Future<void> main() async {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Chạy trong thư mục pak_manager/.');
    exit(2);
  }
  final sodium = await SodiumSumoInit.init();
  final aead = sodium.crypto.aeadXChaCha20Poly1305IETF;

  final kek = sodium.crypto.pwhash.callRaw(
    outLen: 32,
    password: Int8List.fromList(ascii.encode(_password)),
    salt: _salt,
    opsLimit: _opsLimit,
    memLimit: _memLimit,
    alg: CryptoPwhashAlgorithm.argon2id13,
  );
  final dek = sodium.secureCopy(_dek);

  // Header: magic · version u16 · kdfAlg u8 · ops u32 · mem u64 · salt.
  final prefix = Uint8List(35)..setAll(0, ascii.encode('PAKV'));
  ByteData.sublistView(prefix)
    ..setUint16(4, 1, Endian.little)
    ..setUint8(6, 1)
    ..setUint32(7, _opsLimit, Endian.little)
    ..setUint64(11, _memLimit, Endian.little);
  prefix.setAll(19, _salt);

  final wrappedDek = aead.encrypt(
    message: _dek,
    nonce: _wrapNonce,
    key: kek,
    additionalData: prefix,
  );
  final kcv = sodium.crypto.genericHash(
    message: ascii.encode('PAK-KCV-v1'),
    outLen: 16,
    key: kek,
  );
  final body = BytesBuilder()
    ..add(prefix)
    ..add(_wrapNonce)
    ..add(wrappedDek)
    ..add(kcv);
  final checksum = sodium.crypto.genericHash(
    message: body.toBytes(),
    outLen: 32,
  );
  final header = (body..add(checksum)).toBytes();
  if (header.length != 155) {
    throw StateError('header dài ${header.length}, phải là 155');
  }

  Uint8List seal(Map<String, Object?> json, Uint8List nonce, String kind) {
    final ct = aead.encrypt(
      message: utf8.encode(jsonEncode(json)),
      nonce: nonce,
      key: dek,
      additionalData: ascii.encode('PAK-VAULT/$kind/v1'),
    );
    return (BytesBuilder()
          ..add(nonce)
          ..add(ct))
        .toBytes();
  }

  final dir = Directory(_outDir)..createSync(recursive: true);
  File('${dir.path}/header').writeAsBytesSync(header);
  File('${dir.path}/cards')
      .writeAsBytesSync(seal(_cardsJson, _cardsNonce, 'cards'));
  File('${dir.path}/recent')
      .writeAsBytesSync(seal(_recentJson, _recentNonce, 'recent'));
  File('${dir.path}/README.md').writeAsBytesSync(utf8.encode(_readme()));

  kek.dispose();
  dek.dispose();
  stdout.writeln('Đã sinh $_outDir/{header,cards,recent,README.md}');
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

String _readme() =>
    '''
# Fixture vault v1 (AD-20)

Sinh bằng `dart run tool/fixtures/gen_vault_v1.dart` (trong `pak_manager/`).
Không sửa tay: CI chạy lại script và đòi `git status` sạch. Mọi dữ liệu là giả.

Script không import `lib/` của app; nó tự ghép byte theo AD-20 để golden test
(`test/core/format/`) bắt được lỗi của `HeaderCodec`/`VaultFileCodec`.

## Đầu vào cố định

| Trường | Giá trị |
|---|---|
| Mật khẩu (ASCII) | `$_password` |
| KDF | Argon2id13, opslimit $_opsLimit, memlimit $_memLimit byte (19 MiB), p=1, KEK 32 byte |
| DEK | `${_hex(_dek)}` |
| salt | `${_hex(_salt)}` |
| wrapNonce (header) | `${_hex(_wrapNonce)}` |
| nonce `cards` | `${_hex(_cardsNonce)}` |
| nonce `recent` | `${_hex(_recentNonce)}` |

## Bản rõ

`cards` (AD `PAK-VAULT/cards/v1`):

```json
${jsonEncode(_cardsJson)}
```

`recent` (AD `PAK-VAULT/recent/v1`):

```json
${jsonEncode(_recentJson)}
```

## File

- `header`: 155 byte, layout AD-20 little-endian; AD bọc DEK = byte [0,35);
  `kcv` = BLAKE2b-16 khóa KEK trên `PAK-KCV-v1`; `checksum` = BLAKE2b-256 trên
  [0,123).
- `cards`, `recent`: `nonce[24] ‖ ciphertext‖tag`, XChaCha20-Poly1305 bằng DEK.
''';
