import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/policy/blocklist_filter.dart' as core;

import '../../tool/blocklist/build_blocklist.dart' as tool;
import '../core/policy/policy_test_support.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

/// Một mục tar 512 byte + dữ liệu đệm tới bội số 512.
List<int> _tarEntry(String name, int type, List<int> data) {
  final header = Uint8List(512)..setAll(0, ascii.encode(name));
  final size = data.length.toRadixString(8).padLeft(11, '0');
  header
    ..setAll(124, ascii.encode(size))
    ..[156] = type;
  return [
    ...header,
    ...data,
    ...List.filled((512 - data.length % 512) % 512, 0),
  ];
}

void main() {
  group('MurmurHash3 của script', () {
    test('ad15_script_murmur3_matches_public_vectors', () {
      for (final (input, seed, expected) in murmurVectors) {
        expect(tool.murmur3(_bytes(input), seed), expected, reason: input);
      }
    });

    test('ad15_script_and_core_murmur3_agree', () {
      final rng = Xorshift32(0xC0FFEE11);
      final inputs = [
        ...blocklistSample(),
        for (var i = 0; i < 2000; i++) rng.printableAscii(i % 140),
      ];
      for (final s in inputs) {
        final seed = rng.next();
        expect(
          tool.murmur3(_bytes(s), seed),
          core.murmur3X86x32(_bytes(s), seed),
          reason: s,
        );
      }
    });
  });

  group('Bloom của script', () {
    test('ad15_script_bloom_readable_by_core', () {
      final entries = [
        'correct horse battery staple',
        'another fake entry 001',
        'x' * 128,
      ]..sort();
      final bytes = tool.buildBloom(entries);
      final view = ByteData.sublistView(bytes);
      expect(ascii.decode(bytes.sublist(0, 4)), 'PAKB');
      expect(view.getUint8(4), 1);
      expect(view.getUint8(5), 10);
      expect(view.getUint16(6, Endian.little), 0);
      expect(view.getUint32(12, Endian.little), 3);
      expect(view.getUint32(16, Endian.little), 0x50414B31);

      final filter = core.BlocklistFilter.parse(bytes);
      expect(filter, isNotNull);
      for (final e in entries) {
        expect(filter!.contains(e), isTrue, reason: e);
      }
      expect(filter!.contains('not in this tiny filter at all'), isFalse);
    });

    test('ad15_bit_count_formula', () {
      // ⌈−n·ln 0,001 / (ln 2)²⌉
      expect(tool.bloomBitCount(1000), 14378);
      expect(tool.bloomBitCount(647380), 9307763);
    });

    test('ad15_committed_asset_header_and_sample_bits', () {
      final asset = File(blocklistAssetPath).readAsBytesSync();
      final view = ByteData.sublistView(asset);
      final mBits = view.getUint32(8, Endian.little);
      final n = view.getUint32(12, Endian.little);
      expect(mBits, tool.bloomBitCount(n));
      expect(asset.length, tool.headerLength + ((mBits + 7) >> 3));
      expect(asset.length, lessThanOrEqualTo(tool.maxAssetBytes));
      for (final line in blocklistSample()) {
        for (final i in tool.bloomIndices(line, mBits)) {
          expect(
            asset[tool.headerLength + (i >> 3)] & (1 << (i & 7)),
            isNot(0),
          );
        }
      }
    });
  });

  group('lọc dòng', () {
    test('ad15_collect_filters_lowercases_and_dedupes', () {
      final data = BytesBuilder()
        ..add(ascii.encode('${'a' * 14}\n')) // quá ngắn
        ..add(ascii.encode('${'B' * 15}\r\n')) // giữ, bỏ \r, chữ thường
        ..add(ascii.encode('${'b' * 15}\n')) // trùng sau khi chữ thường
        ..add(ascii.encode('${'c' * 128}\n')) // giữ
        ..add(ascii.encode('${'d' * 129}\n')) // quá dài
        ..add([...ascii.encode('e' * 15), 0xE9, 0x0A]) // byte ngoài ASCII
        ..add(ascii.encode('${'f' * 14}\t\n')) // ký tự điều khiển
        ..add(ascii.encode('  spaces kept inside  \n'))
        ..add(ascii.encode('\r\n\n'))
        ..add(ascii.encode('last line no newline'));
      final out = <String>{};
      final accepted = tool.collectEntries(data.toBytes(), out);
      expect(accepted, 5);
      expect(out, {
        'b' * 15,
        'c' * 128,
        '  spaces kept inside  ',
        'last line no newline',
      });
    });
  });

  group('tar', () {
    test('ad15_tar_extracts_single_regular_file', () {
      final content = ascii.encode('fake password line one\n');
      final tar = Uint8List.fromList([
        ..._tarEntry('./PaxHeaders/rockyou.txt', 0x78, ascii.encode('9 x=y\n')),
        ..._tarEntry('dir/', 0x35, const []),
        ..._tarEntry('rockyou.txt', 0x30, content),
        ...List.filled(1024, 0),
      ]);
      expect(tool.extractSingleTarFile(tar), content);
    });

    test('ad15_tar_rejects_zero_or_many_files_and_truncation', () {
      final one = _tarEntry('a.txt', 0x30, ascii.encode('aaa'));
      expect(
        () => tool.extractSingleTarFile(Uint8List(1024)),
        throwsFormatException,
      );
      expect(
        () => tool.extractSingleTarFile(Uint8List.fromList([...one, ...one])),
        throwsFormatException,
      );
      final big = _tarEntry('b.txt', 0x30, List.filled(600, 0x62));
      expect(
        () =>
            tool.extractSingleTarFile(Uint8List.fromList(big.sublist(0, 700))),
        throwsFormatException,
      );
    });
  });

  group('SOURCE', () {
    test('ad15_source_pins_seclists_commit', () {
      final source = tool.parseSource(File(tool.sourcePath).readAsStringSync());
      expect(source.repo, 'danielmiessler/SecLists');
      expect(source.commit, 'a1a06ab57c3f4efc450d80738a72c11597aac81a');
      expect(source.license, 'MIT');
      expect(source.paths, [
        'Passwords/Common-Credentials/Pwdb_top-10000000.txt',
        'Passwords/Common-Credentials/xato-net-10-million-passwords.txt',
        'Passwords/Leaked-Databases/rockyou.txt.tar.gz',
      ]);
      expect(
        source.urlFor(source.paths.first).toString(),
        'https://raw.githubusercontent.com/danielmiessler/SecLists/'
        'a1a06ab57c3f4efc450d80738a72c11597aac81a/'
        'Passwords/Common-Credentials/Pwdb_top-10000000.txt',
      );
    });

    test('ad15_source_rejects_malformed', () {
      final ok = 'repo: a/b\ncommit: ${'0' * 40}\nlicense: MIT\npath: x.txt\n';
      expect(tool.parseSource(ok).paths, ['x.txt']);
      for (final bad in [
        ok.replaceFirst('repo: a/b\n', ''),
        ok.replaceFirst('0' * 40, 'master'),
        ok.replaceFirst('license: MIT\n', ''),
        ok.replaceFirst('path: x.txt\n', ''),
        '${ok}mirror: elsewhere\n',
        '${ok}no colon here\n',
      ]) {
        expect(() => tool.parseSource(bad), throwsFormatException, reason: bad);
      }
    });
  });

  group('mẫu', () {
    test('ad15_sample_picks_every_floor_n_over_500th', () {
      final sorted = [
        for (var i = 0; i < 1234; i++) i.toString().padLeft(15, '0'),
      ];
      final sample = tool.pickSample(sorted);
      expect(sample, hasLength(500));
      expect(sample.first, sorted[0]);
      expect(sample[1], sorted[2]);
      expect(sample.last, sorted[499 * 2]);
      expect(() => tool.pickSample(sorted.sublist(0, 499)), throwsStateError);
    });
  });
}
