import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/crypto/random_source.dart';
import 'package:pak_manager/core/crypto/wipe.dart';
import 'package:sodium/sodium_sumo.dart';

import '../vault_fixture.dart';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  group('uuidV4', () {
    test('ad16_uuid_v4_sets_version_and_variant_bits', () {
      for (final fill in [0x00, 0xff, 0x5a, 0xa5]) {
        final random = QueueRandomSource([
          Uint8List.fromList(List.filled(16, fill)),
        ]);

        final id = uuidV4(random);

        expect(
          id,
          matches(_uuidV4),
          reason: 'fill 0x${fill.toRadixString(16)}',
        );
        expect(random.requested, [16]);
      }
    });

    test('ad16_uuid_v4_is_lowercase_hex_of_random_bytes', () {
      final random = QueueRandomSource([seq(0xa0, 16)]);

      // a0a1a2a3-a4a5-[4]6a7-[a]8a9-aaabacadaeaf: byte 6 → 0x46, byte 8 → 0xa8.
      expect(uuidV4(random), 'a0a1a2a3-a4a5-46a7-a8a9-aaabacadaeaf');
    });
  });

  group('SodiumRandomSource', () {
    late SodiumSumo sodium;
    setUpAll(() async => sodium = await initSodium());

    test('ad16_sodium_random_source_returns_requested_length', () {
      final random = SodiumRandomSource(sodium);

      expect(random.bytes(0), isEmpty);
      expect(random.bytes(24), hasLength(24));
      expect(random.bytes(32), isNot(random.bytes(32)));
      expect(uuidV4(random), matches(_uuidV4));
    });
  });

  test('ad22_wipe_zeroes_every_byte', () {
    final bytes = seq(1, 40);

    wipe(bytes);

    expect(bytes, everyElement(0));
    expect(bytes, hasLength(40));
  });
}
