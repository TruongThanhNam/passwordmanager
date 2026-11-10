import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/policy/blocklist_filter.dart';

import 'policy_test_support.dart';

void main() {
  group('MurmurHash3 x86_32', () {
    test('ad15_murmur3_matches_public_vectors', () {
      for (final (input, seed, expected) in murmurVectors) {
        expect(
          murmur3X86x32(Uint8List.fromList(utf8.encode(input)), seed),
          expected,
          reason: '"$input" / 0x${seed.toRadixString(16)}',
        );
      }
    });
  });

  group('parse', () {
    test('ad15_parse_accepts_well_formed_bytes', () {
      expect(BlocklistFilter.parse(fakeBloomBytes()), isNotNull);
      expect(BlocklistFilter.parse(fakeBloomBytes(mBits: 1)), isNotNull);
      expect(
        BlocklistFilter.parse(fakeBloomBytes(mBits: 13, k: 255)),
        isNotNull,
      );
    });

    test('ad15_corrupt_bloom_returns_null', () {
      final good = fakeBloomBytes();
      final cases = <String, Uint8List>{
        'rỗng': Uint8List(0),
        'chỉ một phần header': Uint8List.sublistView(good, 0, 19),
        'sai magic': Uint8List.fromList(good)..[0] = 0x58,
        'sai version 0': fakeBloomBytes(version: 0),
        'sai version 2': fakeBloomBytes(version: 2),
        'k = 0': fakeBloomBytes(k: 0),
        'reserved khác 0': fakeBloomBytes(reserved: 1),
        'mBits = 0': fakeBloomBytes(mBits: 0),
        'thiếu một byte bit': Uint8List.sublistView(good, 0, good.length - 1),
        'thừa một byte': Uint8List.fromList([...good, 0]),
        'mBits lớn hơn mảng bit': (Uint8List.fromList(good)
          ..buffer.asByteData().setUint32(8, 65, Endian.little)),
      };
      for (final MapEntry(:key, :value) in cases.entries) {
        expect(BlocklistFilter.parse(value), isNull, reason: key);
      }
    });

    test('ad15_parse_copies_input_buffer', () {
      final bytes = fakeBloomBytes(fill: 0xFF);
      final filter = BlocklistFilter.parse(bytes)!;
      bytes.fillRange(BlocklistFilter.headerLength, bytes.length, 0);
      expect(filter.contains('still present after caller wipes'), isTrue);
    });
  });

  group('contains', () {
    test('ad15_empty_and_full_filters', () {
      expect(emptyFilter().contains('anything at all here'), isFalse);
      expect(fullFilter().contains('anything at all here'), isTrue);
      expect(fullFilter().contains(''), isTrue);
    });

    test('ad15_non_ascii_never_contained', () {
      expect(fullFilter().contains('mật khẩu tiếng việt'), isFalse);
    });

    test('fr02_asset_contains_every_sample_line', () {
      final filter = assetFilter();
      for (final line in blocklistSample()) {
        expect(filter.contains(line), isTrue, reason: line);
      }
    });

    test('ad15_asset_false_positive_rate_within_bound', () {
      final filter = assetFilter();
      final sample = blocklistSample().toSet();
      final rng = Xorshift32(0x1BADB002);
      var positives = 0;
      var tried = 0;
      while (tried < 100000) {
        final s = rng.printableAscii(20).toLowerCase();
        if (sample.contains(s)) {
          continue;
        }
        tried++;
        if (filter.contains(s)) {
          positives++;
        }
      }
      // 0,15%: biên cho dao động quanh tỷ lệ thiết kế 0,1%.
      expect(positives, lessThanOrEqualTo(150));
    });
  });
}
