import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import '../crypto/kdf.dart';
import '../crypto/random_source.dart';
import '../crypto/wipe.dart';

/// Độ dài DEK (byte).
const int dekBytes = 32;

/// Nội dung file `vault/header` (AD-20), trừ `checksum` (tính khi
/// [HeaderCodec.encode]). Chỉ [HeaderCodec] tạo được, nên mọi trường luôn
/// đúng độ dài và [kdf] luôn trong khoảng cho phép. Bất biến.
final class VaultHeader {
  VaultHeader._({
    required this.kdf,
    required Uint8List salt,
    required Uint8List wrapNonce,
    required Uint8List wrappedDek,
    required Uint8List kcv,
  }) : salt = Uint8List.fromList(salt).asUnmodifiableView(),
       wrapNonce = Uint8List.fromList(wrapNonce).asUnmodifiableView(),
       wrappedDek = Uint8List.fromList(wrappedDek).asUnmodifiableView(),
       kcv = Uint8List.fromList(kcv).asUnmodifiableView();

  /// Tham số Argon2id13 (`kdfAlg` luôn là [HeaderCodec.kdfAlgArgon2id13]).
  final KdfParams kdf;

  /// 16 byte.
  final Uint8List salt;

  /// 24 byte, nonce XChaCha20-Poly1305 khi bọc DEK.
  final Uint8List wrapNonce;

  /// 48 byte, DEK bọc bằng KEK (ciphertext‖tag).
  final Uint8List wrappedDek;

  /// 16 byte, BLAKE2b-16 khóa KEK trên `PAK-KCV-v1`.
  final Uint8List kcv;

  @override
  String toString() => 'VaultHeader(kdf: $kdf)';
}

/// Kết quả [HeaderCodec.decode].
sealed class HeaderDecodeResult {
  const HeaderDecodeResult();
}

final class HeaderOk extends HeaderDecodeResult {
  const HeaderOk(this.header);

  final VaultHeader header;
}

/// Header hỏng; không kèm thông điệp (AD-20).
final class HeaderCorrupt extends HeaderDecodeResult {
  const HeaderCorrupt();
}

/// Codec duy nhất của file `vault/header` (AD-20). Nhị phân little-endian,
/// 155 byte:
///
/// | offset | độ dài | trường                                  |
/// |-------:|-------:|-----------------------------------------|
/// |      0 |      4 | magic `PAKV`                            |
/// |      4 |      2 | version u16 = 1                         |
/// |      6 |      1 | kdfAlg u8 = 1 (Argon2id13)              |
/// |      7 |      4 | opslimit u32                            |
/// |     11 |      8 | memlimit u64 (byte)                     |
/// |     19 |     16 | salt                                    |
/// |     35 |     24 | wrapNonce                               |
/// |     59 |     48 | wrappedDek (XChaCha20-Poly1305, AD [0,35)) |
/// |    107 |     16 | kcv = BLAKE2b-16(key KEK, `PAK-KCV-v1`)  |
/// |    123 |     32 | checksum = BLAKE2b-256 của [0,123)      |
///
/// Không method nào ném: lỗi đầu vào trả [HeaderCorrupt], `null` hoặc
/// `false`, không kèm thông điệp.
final class HeaderCodec {
  HeaderCodec(this._sodium);

  final SodiumSumo _sodium;

  static const int length = 155;
  static const int version = 1;
  static const int kdfAlgArgon2id13 = 1;

  static const int _offVersion = 4;
  static const int _offKdfAlg = 6;
  static const int _offOps = 7;
  static const int _offMem = 11;
  static const int _offSalt = 19;
  static const int _offWrapNonce = 35;
  static const int _offWrappedDek = 59;
  static const int _offKcv = 107;
  static const int _offChecksum = 123;

  static const int _wrapNonceBytes = 24;
  static const int _kcvBytes = 16;
  static const int _checksumBytes = 32;

  static final Uint8List _magic = ascii.encode('PAKV');
  static final Uint8List _kcvMessage = ascii.encode('PAK-KCV-v1');

  /// Đọc header theo thứ tự của AD-20: độ dài → magic → version →
  /// checksum → kdfAlg → khoảng tham số. Không chạy KDF.
  HeaderDecodeResult decode(List<int> input) {
    try {
      if (input.length != length) {
        return const HeaderCorrupt();
      }
      final bytes = Uint8List.fromList(input);
      final data = ByteData.sublistView(bytes);
      for (var i = 0; i < _magic.length; i++) {
        if (bytes[i] != _magic[i]) {
          return const HeaderCorrupt();
        }
      }
      if (data.getUint16(_offVersion, Endian.little) != version) {
        return const HeaderCorrupt();
      }
      final checksum = _checksum(Uint8List.sublistView(bytes, 0, _offChecksum));
      if (!_sodium.memcmp(
        checksum,
        Uint8List.sublistView(bytes, _offChecksum, length),
      )) {
        return const HeaderCorrupt();
      }
      if (bytes[_offKdfAlg] != kdfAlgArgon2id13) {
        return const HeaderCorrupt();
      }
      final kdf = KdfParams(
        data.getUint32(_offOps, Endian.little),
        data.getUint64(_offMem, Endian.little),
      );
      if (!kdf.isAllowed) {
        return const HeaderCorrupt();
      }
      return HeaderOk(
        VaultHeader._(
          kdf: kdf,
          salt: Uint8List.sublistView(bytes, _offSalt, _offWrapNonce),
          wrapNonce: Uint8List.sublistView(
            bytes,
            _offWrapNonce,
            _offWrappedDek,
          ),
          wrappedDek: Uint8List.sublistView(bytes, _offWrappedDek, _offKcv),
          kcv: Uint8List.sublistView(bytes, _offKcv, _offChecksum),
        ),
      );
    } on Object {
      return const HeaderCorrupt();
    }
  }

  /// Header mới: bọc [dek] bằng [kek] với nonce lấy từ [random], AD là các
  /// byte từ magic đến hết salt; tính `kcv` từ [kek]. Trả `null` khi đầu
  /// vào sai (salt ≠ 16 byte, DEK ≠ 32 byte, [params] ngoài khoảng, khóa
  /// đã dispose…).
  VaultHeader? create({
    required SecureKey kek,
    required SecureKey dek,
    required Uint8List salt,
    required KdfParams params,
    required RandomSource random,
  }) {
    try {
      if (salt.length != kdfSaltBytes ||
          dek.length != dekBytes ||
          kek.length != kekBytes ||
          !params.isAllowed) {
        return null;
      }
      final wrapNonce = random.bytes(_wrapNonceBytes);
      if (wrapNonce.length != _wrapNonceBytes) {
        return null;
      }
      final ad = _prefix(params, salt);
      final wrappedDek = dek.runUnlockedSync(
        (dekData) => _sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
          message: dekData,
          nonce: wrapNonce,
          key: kek,
          additionalData: ad,
        ),
      );
      return VaultHeader._(
        kdf: params,
        salt: salt,
        wrapNonce: wrapNonce,
        wrappedDek: wrappedDek,
        kcv: _kcv(kek),
      );
    } on Object {
      return null;
    }
  }

  /// 155 byte của [header], kèm checksum.
  Uint8List encode(VaultHeader header) {
    final out = Uint8List(length)
      ..setAll(0, _prefix(header.kdf, header.salt))
      ..setAll(_offWrapNonce, header.wrapNonce)
      ..setAll(_offWrappedDek, header.wrappedDek)
      ..setAll(_offKcv, header.kcv);
    out.setAll(
      _offChecksum,
      _checksum(Uint8List.sublistView(out, 0, _offChecksum)),
    );
    return out;
  }

  /// `true` khi `kcv` tính từ [kek] khớp [header] (so hằng thời gian).
  /// `false` = sai mật khẩu.
  bool kcvMatches(VaultHeader header, SecureKey kek) {
    try {
      return _sodium.memcmp(_kcv(kek), header.kcv);
    } on Object {
      return false;
    }
  }

  /// Mở bọc DEK bằng [kek]. `null` = `corrupt` (tag sai, DEK sai độ dài).
  /// Buffer DEK tạm trên heap Dart bị ghi đè 0 ngay sau khi chép vào
  /// `SecureKey`.
  SecureKey? unwrapDek(VaultHeader header, SecureKey kek) {
    Uint8List? plain;
    try {
      plain = _sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
        cipherText: header.wrappedDek,
        nonce: header.wrapNonce,
        key: kek,
        additionalData: _prefix(header.kdf, header.salt),
      );
      if (plain.length != dekBytes) {
        return null;
      }
      return _sodium.secureCopy(plain);
    } on Object {
      return null;
    } finally {
      if (plain != null) {
        wipe(plain);
      }
    }
  }

  /// Byte [0,35): magic, version, kdfAlg, opslimit, memlimit, salt. Đây
  /// cũng là AD khi bọc DEK.
  static Uint8List _prefix(KdfParams kdf, Uint8List salt) {
    final out = Uint8List(_offWrapNonce)..setAll(0, _magic);
    ByteData.sublistView(out)
      ..setUint16(_offVersion, version, Endian.little)
      ..setUint8(_offKdfAlg, kdfAlgArgon2id13)
      ..setUint32(_offOps, kdf.opsLimit, Endian.little)
      ..setUint64(_offMem, kdf.memLimitBytes, Endian.little);
    out.setAll(_offSalt, salt);
    return out;
  }

  Uint8List _kcv(SecureKey kek) => _sodium.crypto.genericHash(
    message: _kcvMessage,
    outLen: _kcvBytes,
    key: kek,
  );

  Uint8List _checksum(Uint8List bytes) =>
      _sodium.crypto.genericHash(message: bytes, outLen: _checksumBytes);
}
