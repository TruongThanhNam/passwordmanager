import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/crypto/kdf.dart';
import 'package:pak_manager/core/format/header_codec.dart';
import 'package:sodium/sodium_sumo.dart';

import '../vault_fixture.dart';

enum _Unlock { ok, wrongPassword, corrupt }

void main() {
  late SodiumSumo sodium;
  late HeaderCodec codec;
  late SecureKey kek;

  setUpAll(() async {
    sodium = await initSodium();
    codec = HeaderCodec(sodium);
    kek = (await deriveKek(
      sodium,
      fixturePassword(),
      fixtureSalt(),
      fixtureParams,
    ))!;
  });
  tearDownAll(() => kek.dispose());

  Uint8List golden() => vaultFixture('header');

  VaultHeader decodeOk(List<int> bytes) =>
      (codec.decode(bytes) as HeaderOk).header;

  /// Ghi lại checksum sau khi sửa [bytes] để chạm tới các bước kiểm sau
  /// checksum.
  Uint8List withChecksum(Uint8List bytes) {
    final sum = sodium.crypto.genericHash(
      message: Uint8List.sublistView(bytes, 0, 123),
      outLen: 32,
    );
    return bytes..setAll(123, sum);
  }

  Uint8List patched(void Function(ByteData data, Uint8List bytes) edit) {
    final bytes = golden();
    edit(ByteData.sublistView(bytes), bytes);
    return withChecksum(bytes);
  }

  /// Trình tự mở khóa tối giản của AD-4 (bước 1, 2, 3, 4) trên codec.
  Future<(_Unlock, int)> unlock(
    List<int> bytes,
    Future<SecureKey?> Function(VaultHeader header) derive,
  ) async {
    var derives = 0;
    final decoded = codec.decode(bytes);
    if (decoded is! HeaderOk) {
      return (_Unlock.corrupt, derives);
    }
    derives++;
    final key = await derive(decoded.header);
    if (key == null) {
      return (_Unlock.corrupt, derives);
    }
    try {
      if (!codec.kcvMatches(decoded.header, key)) {
        return (_Unlock.wrongPassword, derives);
      }
      final dek = codec.unwrapDek(decoded.header, key);
      if (dek == null) {
        return (_Unlock.corrupt, derives);
      }
      dek.dispose();
      return (_Unlock.ok, derives);
    } finally {
      if (!identical(key, kek)) {
        key.dispose();
      }
    }
  }

  group('golden', () {
    test('ad20_create_and_encode_match_fixture_byte_for_byte', () {
      final dek = sodium.secureCopy(fixtureDek());
      addTearDown(dek.dispose);
      final random = QueueRandomSource([fixtureWrapNonce()]);

      final header = codec.create(
        kek: kek,
        dek: dek,
        salt: fixtureSalt(),
        params: fixtureParams,
        random: random,
      );

      expect(random.requested, [24]);
      expect(codec.encode(header!), golden());
    });

    test('ad20_decode_reads_every_field_and_round_trips', () {
      final header = decodeOk(golden());

      expect(header.kdf, fixtureParams);
      expect(header.salt, fixtureSalt());
      expect(header.wrapNonce, fixtureWrapNonce());
      expect(header.wrappedDek, hasLength(48));
      expect(header.kcv, hasLength(16));
      expect(codec.encode(header), golden());
    });

    test('ad20_layout_offsets_are_little_endian', () {
      final bytes = golden();
      final data = ByteData.sublistView(bytes);

      expect(bytes, hasLength(HeaderCodec.length));
      expect(ascii.decode(bytes.sublist(0, 4)), 'PAKV');
      expect(data.getUint16(4, Endian.little), 1);
      expect(bytes[6], 1);
      expect(data.getUint32(7, Endian.little), 2);
      expect(data.getUint64(11, Endian.little), 19 * mib);
      expect(bytes.sublist(19, 35), fixtureSalt());
      expect(bytes.sublist(35, 59), fixtureWrapNonce());
    });
  });

  group('mở khóa', () {
    test('ad04_right_password_kcv_matches_and_unwraps_fixture_dek', () {
      final header = decodeOk(golden());

      expect(codec.kcvMatches(header, kek), isTrue);
      final dek = codec.unwrapDek(header, kek);
      addTearDown(() => dek?.dispose());
      expect(dek!.extractBytes(), fixtureDek());
    });

    test('ad04_wrong_password_is_header_ok_but_kcv_mismatch', () async {
      final other = await deriveKek(
        sodium,
        ascii.encode('fixture-only wrong horse 43'),
        fixtureSalt(),
        fixtureParams,
      );
      addTearDown(() => other?.dispose());
      final decoded = codec.decode(golden());

      expect(decoded, isA<HeaderOk>());
      expect(codec.kcvMatches((decoded as HeaderOk).header, other!), isFalse);
      final (result, derives) = await unlock(
        golden(),
        (_) async => other.copy(),
      );
      expect((result, derives), (_Unlock.wrongPassword, 1));
    });

    test('ad04_flipped_checksum_is_corrupt_and_kdf_never_runs', () async {
      final bytes = golden();
      bytes[154] ^= 0x01;

      final (result, derives) = await unlock(bytes, (_) async => kek);

      expect(codec.decode(bytes), isA<HeaderCorrupt>());
      expect((result, derives), (_Unlock.corrupt, 0));
    });

    test('ad04_full_unlock_with_fixture_password_succeeds', () async {
      final (result, derives) = await unlock(
        golden(),
        (h) => deriveKek(sodium, fixturePassword(), h.salt, h.kdf),
      );

      expect((result, derives), (_Unlock.ok, 1));
    });

    test('ad04_tampered_wrapped_dek_matches_kcv_but_unwrap_is_null', () {
      for (final offset in [59, 80, 106]) {
        final header = decodeOk(patched((_, b) => b[offset] ^= 0x80));

        expect(codec.kcvMatches(header, kek), isTrue);
        expect(codec.unwrapDek(header, kek), isNull, reason: 'byte $offset');
      }
    });

    test('ad04_tampered_wrap_nonce_unwrap_is_null', () {
      final header = decodeOk(patched((_, b) => b[40] ^= 0x01));

      expect(codec.unwrapDek(header, kek), isNull);
    });
  });

  group('header hỏng → corrupt', () {
    void expectCorrupt(List<int> bytes, String reason) =>
        expect(codec.decode(bytes), isA<HeaderCorrupt>(), reason: reason);

    test('ad20_wrong_length_is_corrupt', () {
      final g = golden();
      expectCorrupt(const [], 'rỗng');
      expectCorrupt(g.sublist(0, 154), '154');
      expectCorrupt([...g, 0], '156');
    });

    test('ad20_wrong_magic_is_corrupt', () {
      expectCorrupt(patched((_, b) => b[0] = 0x51), 'QAKV');
      expectCorrupt(patched((_, b) => b[3] = 0x58), 'PAKX');
    });

    test('ad20_wrong_version_is_corrupt', () {
      for (final v in [0, 2, 0x0100]) {
        expectCorrupt(
          patched((d, _) => d.setUint16(4, v, Endian.little)),
          'v$v',
        );
      }
    });

    test('ad04_any_flipped_bit_before_or_in_checksum_is_corrupt', () {
      for (var i = 0; i < HeaderCodec.length; i++) {
        final bytes = golden();
        bytes[i] ^= 0x01;
        expectCorrupt(bytes, 'byte $i');
      }
    });

    test('ad20_wrong_kdf_alg_is_corrupt', () {
      for (final alg in [0, 2, 255]) {
        expectCorrupt(patched((d, _) => d.setUint8(6, alg)), 'kdfAlg $alg');
      }
    });

    test('ad05_out_of_range_params_are_corrupt_before_kdf', () async {
      final cases = {
        'ops 1': patched((d, _) => d.setUint32(7, 1, Endian.little)),
        'ops 11': patched((d, _) => d.setUint32(7, 11, Endian.little)),
        'ops u32 max': patched(
          (d, _) => d.setUint32(7, 0xffffffff, Endian.little),
        ),
        'mem 19 MiB - 1': patched(
          (d, _) => d.setUint64(11, 19 * mib - 1, Endian.little),
        ),
        'mem 128 MiB + 1': patched(
          (d, _) => d.setUint64(11, 128 * mib + 1, Endian.little),
        ),
        'mem u64 max': patched((d, _) => d.setInt64(11, -1, Endian.little)),
      };
      for (final MapEntry(:key, :value) in cases.entries) {
        final (result, derives) = await unlock(value, (_) async => kek);

        expectCorrupt(value, key);
        expect((result, derives), (_Unlock.corrupt, 0), reason: key);
      }
    });

    test('ad05_boundary_params_decode_ok', () {
      for (final (ops, mem) in [(2, 19 * mib), (10, 128 * mib)]) {
        final header = decodeOk(
          patched((d, _) {
            d
              ..setUint32(7, ops, Endian.little)
              ..setUint64(11, mem, Endian.little);
          }),
        );

        expect(header.kdf, KdfParams(ops, mem));
      }
    });
  });

  group('create từ chối đầu vào sai', () {
    test('ad20_create_returns_null_on_bad_input', () {
      final dek = sodium.secureCopy(fixtureDek());
      final shortDek = sodium.secureCopy(seq(0, 16));
      addTearDown(dek.dispose);
      addTearDown(shortDek.dispose);

      VaultHeader? create({
        SecureKey? dekKey,
        Uint8List? salt,
        KdfParams params = fixtureParams,
      }) => codec.create(
        kek: kek,
        dek: dekKey ?? dek,
        salt: salt ?? fixtureSalt(),
        params: params,
        random: QueueRandomSource([fixtureWrapNonce()]),
      );

      expect(create(salt: seq(0, 15)), isNull);
      expect(create(dekKey: shortDek), isNull);
      expect(create(params: const KdfParams(1, 19 * mib)), isNull);
      expect(create(params: const KdfParams(2, 129 * mib)), isNull);
      expect(create(), isNotNull);
    });

    test('ad04_create_round_trips_with_another_nonce', () {
      final dek = sodium.secureCopy(fixtureDek());
      addTearDown(dek.dispose);
      final random = QueueRandomSource([seq(0x10, 24)]);

      final header = codec.create(
        kek: kek,
        dek: dek,
        salt: fixtureSalt(),
        params: fixtureParams,
        random: random,
      )!;
      final round = decodeOk(codec.encode(header));

      expect(round.wrapNonce, seq(0x10, 24));
      expect(codec.kcvMatches(round, kek), isTrue);
      final unwrapped = codec.unwrapDek(round, kek);
      addTearDown(() => unwrapped?.dispose());
      expect(unwrapped!.extractBytes(), fixtureDek());
    });
  });

  test('ad22_header_to_string_has_no_key_material', () {
    final text = decodeOk(golden()).toString();

    expect(text, isNot(contains('salt')));
    expect(text, isNot(contains('kcv')));
    expect(text, contains('KdfParams'));
  });
}
