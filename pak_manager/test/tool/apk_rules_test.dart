import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/ci/apk_rules.dart';

// Golden fixture: output thô thật của aapt2/unzip/readelf trên APK prod và dev
// do CI build (xem test/fixtures/apk/SOURCE). Ca kiểm âm sửa golden bằng cách
// thay/chèn/xóa dòng, không dựng output viết tay.
const _golden = 'test/fixtures/apk';
const _flavors = ['prod', 'dev'];

const _prodId = 'io.github.truongthanhnam.pakmanager';
const _devId = 'io.github.truongthanhnam.pakmanager.dev';
const _ids = {'prod': _prodId, 'dev': _devId};

String _read(String flavor, String name) =>
    File('$_golden/$flavor/$name').readAsStringSync();

String _manifest([String flavor = 'prod']) => _read(flavor, 'manifest.txt');
String _listing([String flavor = 'prod']) => _read(flavor, 'listing.txt');
String _badging(String flavor) => _read(flavor, 'badging.txt');

/// Output readelf golden của mọi `.so` trong listing, khóa `<abi>/<tên>.so`.
Map<String, String> _goodElf([String flavor = 'prod']) => {
  for (final so in soFilesInListing(_listing(flavor)))
    so: _read(flavor, 'readelf/$so.txt'),
};

/// Xóa mọi dòng thỏa [match]; fail nếu golden không có dòng nào như vậy.
String _removeLines(String text, bool Function(String line) match) {
  final lines = text.split('\n');
  final kept = lines.where((l) => !match(l)).toList();
  expect(
    kept.length,
    lessThan(lines.length),
    reason: 'golden thiếu dòng cần xóa',
  );
  return kept.join('\n');
}

/// Thay mọi dòng thỏa [match] bằng [replace]; fail nếu không có dòng nào.
String _replaceLines(
  String text,
  bool Function(String line) match,
  String Function(String line) replace,
) {
  final lines = text.split('\n');
  var count = 0;
  for (var i = 0; i < lines.length; i++) {
    if (match(lines[i])) {
      lines[i] = replace(lines[i]);
      count++;
    }
  }
  expect(count, greaterThan(0), reason: 'golden thiếu dòng cần thay');
  return lines.join('\n');
}

bool _isAllowBackup(String l) => l.contains(':allowBackup(');

/// Chèn `uses-permission INTERNET` sau quyền có sẵn trong golden, giữ đúng
/// định dạng dòng của aapt2.
String _withInternet(String manifest) {
  final lines = manifest.split('\n');
  final at = lines.indexWhere((l) => l.trim().startsWith('E: uses-permission'));
  expect(at, isNot(-1), reason: 'golden thiếu uses-permission');
  final name = lines[at + 1];
  expect(name, contains('DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'));
  final internet = name.replaceAll(
    RegExp('"[^"]*DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"'),
    '"android.permission.INTERNET"',
  );
  lines.insertAll(at + 2, [lines[at], internet]);
  return lines.join('\n');
}

String _withAllowBackup(String manifest, String value) => _replaceLines(
  manifest,
  _isAllowBackup,
  (l) => l.replaceFirst(RegExp(r'=.*$'), '=$value'),
);

/// Xóa khỏi listing các dòng file có đường dẫn thỏa [match].
String _withoutPath(String listing, bool Function(String path) match) =>
    _removeLines(listing, (l) {
      final paths = parseListing(l);
      return paths.isNotEmpty && match(paths.single);
    });

bool _isLoad(String l) => l.trim().startsWith('LOAD ');

/// Đổi align của mọi segment LOAD thành [align].
String _withLoadAlign(String readelf, String align) => _replaceLines(
  readelf,
  _isLoad,
  (l) => l.replaceFirst(RegExp(r'0x[0-9a-fA-F]+\s*$'), align),
);

void main() {
  group('golden', () {
    test('ad19_golden_is_raw_tool_output', () {
      // Golden phải là output thật: nhiều ABI, .so thật, LOAD thật.
      for (final flavor in _flavors) {
        final sos = soFilesInListing(_listing(flavor));
        expect(sos, contains('arm64-v8a/libsodium.so'));
        expect(sos, contains('x86_64/libapp.so'));
        expect(sos, contains('armeabi-v7a/libflutter.so'));
        expect(parseListing(_listing(flavor)), contains(blocklistAsset));
        expect(
          _goodElf(flavor).values.every((t) => t.split('\n').any(_isLoad)),
          isTrue,
        );
      }
    });
  });

  group('manifest', () {
    test('ad12_good_manifest_passes', () {
      for (final flavor in _flavors) {
        expect(checkManifest(_manifest(flavor)), isEmpty, reason: flavor);
      }
    });

    test('ad12_internet_permission_rejected', () {
      for (final flavor in _flavors) {
        final v = checkManifest(_withInternet(_manifest(flavor)));
        expect(v, hasLength(1), reason: flavor);
        expect(v.single, contains('INTERNET'));
      }
    });

    test('nfr8_allow_backup_true_rejected', () {
      final v = checkManifest(_withAllowBackup(_manifest(), 'true'));
      expect(v, hasLength(1));
      expect(v.single, contains('allowBackup'));
    });

    test('nfr8_allow_backup_typed_zero_accepted', () {
      expect(
        checkManifest(_withAllowBackup(_manifest(), '(type 0x12)0x0')),
        isEmpty,
      );
      expect(
        checkManifest(_withAllowBackup(_manifest(), '(type 0x12)0xffffffff')),
        hasLength(1),
      );
    });

    test('nfr8_missing_allow_backup_rejected', () {
      final m = _removeLines(_manifest(), _isAllowBackup);
      expect(checkManifest(m).single, contains('allowBackup'));
    });

    test('nfr8_missing_data_extraction_rules_rejected', () {
      final m = _removeLines(
        _manifest(),
        (l) => l.contains(':dataExtractionRules('),
      );
      expect(checkManifest(m).single, contains('dataExtractionRules'));
    });

    test('nfr8_missing_full_backup_content_rejected', () {
      final m = _removeLines(
        _manifest(),
        (l) => l.contains(':fullBackupContent('),
      );
      expect(checkManifest(m).single, contains('fullBackupContent'));
    });
  });

  group('listing', () {
    test('ad19_good_listing_passes', () {
      for (final flavor in _flavors) {
        final listing = _listing(flavor);
        final paths = parseListing(listing);
        // Chỉ lấy tên file: không lẫn dòng tiêu đề, kẻ ngang hay tổng kết.
        expect(paths, contains('AndroidManifest.xml'));
        expect(paths, contains('lib/arm64-v8a/libsodium.so'));
        final total = RegExp(
          r'^\s*\d+\s+(\d+) files$',
          multiLine: true,
        ).firstMatch(listing)!.group(1)!;
        expect(paths, hasLength(int.parse(total)), reason: flavor);
        expect(checkListing(listing), isEmpty, reason: flavor);
      }
    });

    test('ad19_missing_libsodium_rejected', () {
      final listing = _withoutPath(
        _listing(),
        (p) => p == 'lib/x86_64/libsodium.so',
      );
      final v = checkListing(listing);
      expect(v.single, contains('lib/x86_64/libsodium.so'));
    });

    test('ad19_missing_arm64_rejected', () {
      final listing = _withoutPath(
        _listing(),
        (p) => p.startsWith('lib/arm64-v8a/'),
      );
      expect(checkListing(listing).single, contains('arm64-v8a'));
    });

    test('ad19_arm64_dir_without_so_rejected', () {
      // Giữ một dòng arm64 nhưng đổi thành file không phải .so.
      final listing = _replaceLines(
        _withoutPath(
          _listing(),
          (p) =>
              p.startsWith('lib/arm64-v8a/') &&
              p != 'lib/arm64-v8a/libsodium.so',
        ),
        (l) => l.endsWith('lib/arm64-v8a/libsodium.so'),
        (l) => l.replaceFirst('libsodium.so', 'README.txt'),
      );
      expect(parseListing(listing), contains('lib/arm64-v8a/README.txt'));
      expect(checkListing(listing).single, contains('arm64-v8a'));
    });

    test('ad19_no_native_libs_rejected', () {
      final listing = _withoutPath(_listing(), (p) => p.startsWith('lib/'));
      final v = checkListing(listing);
      expect(v, hasLength(2));
      expect(v.first, contains('lib/*/*.so'));
    });

    test('ad15_missing_blocklist_rejected', () {
      final listing = _withoutPath(_listing(), (p) => p == blocklistAsset);
      expect(checkListing(listing).single, contains('blocklist.bloom'));
    });
  });

  group('readelf', () {
    test('ad19_good_aligns_pass', () {
      for (final flavor in _flavors) {
        expect(checkElfAligns(_goodElf(flavor)), isEmpty, reason: flavor);
      }
    });

    test('ad19_arm64_4k_align_rejected', () {
      // Chỉ segment LOAD cuối bị căn 4 KB.
      final elf = _goodElf();
      final lines = elf['arm64-v8a/libapp.so']!.split('\n');
      final last = lines.lastIndexWhere(_isLoad);
      lines[last] = _withLoadAlign(lines[last], '0x1000');
      elf['arm64-v8a/libapp.so'] = lines.join('\n');
      final v = checkElfAligns(elf);
      expect(v.single, contains('arm64-v8a/libapp.so'));
      expect(v.single, contains('0x1000'));
    });

    test('ad19_x86_64_4k_align_rejected', () {
      final elf = _goodElf();
      elf['x86_64/libsodium.so'] = _withLoadAlign(
        elf['x86_64/libsodium.so']!,
        '0x1000',
      );
      expect(checkElfAligns(elf).single, contains('x86_64/libsodium.so'));
    });

    test('ad19_32bit_4k_align_ignored', () {
      final elf = _goodElf();
      final v7 = _withLoadAlign(elf['armeabi-v7a/libapp.so']!, '0x1000');
      elf['armeabi-v7a/libapp.so'] = v7;
      elf['x86/libapp.so'] = v7;
      expect(checkElfAligns(elf), isEmpty);
    });

    test('ad19_no_load_segment_rejected', () {
      final elf = _goodElf();
      elf['arm64-v8a/libflutter.so'] = _removeLines(
        elf['arm64-v8a/libflutter.so']!,
        _isLoad,
      );
      expect(checkElfAligns(elf).single, contains('không có segment LOAD'));
    });
  });

  group('badging', () {
    test('ad19_prod_and_dev_ids_pass', () {
      expect(checkBadging(_badging('prod'), _prodId), isEmpty);
      expect(checkBadging(_badging('dev'), _devId), isEmpty);
    });

    test('ad19_prod_with_dev_suffix_rejected', () {
      expect(checkBadging(_badging('dev'), _prodId), hasLength(1));
    });

    test('ad19_dev_missing_suffix_rejected', () {
      expect(checkBadging(_badging('prod'), _devId), hasLength(1));
    });

    test('ad19_missing_package_line_rejected', () {
      final badging = _removeLines(
        _badging('prod'),
        (l) => l.startsWith('package:'),
      );
      expect(checkBadging(badging, _prodId), hasLength(1));
    });
  });

  group('run', () {
    late Directory work;

    setUp(() {
      work = Directory.systemTemp.createTempSync('apk_rules_test');
    });

    tearDown(() {
      work.deleteSync(recursive: true);
    });

    /// Chép golden [flavor] vào thư mục làm việc (giữ nguyên byte).
    void copyGolden([String flavor = 'prod']) {
      final from = Directory('$_golden/$flavor');
      for (final entity in from.listSync(recursive: true)) {
        if (entity is File) {
          final rel = entity.path
              .substring(from.path.length + 1)
              .replaceAll(r'\', '/');
          File('${work.path}/$rel')
            ..createSync(recursive: true)
            ..writeAsBytesSync(entity.readAsBytesSync());
        }
      }
    }

    /// Sửa một file trong thư mục làm việc.
    void edit(String name, String Function(String text) change) {
      final file = File('${work.path}/$name');
      file.writeAsStringSync(change(file.readAsStringSync()));
    }

    test('ad19_run_good_work_dir_exit_0', () {
      for (final flavor in _flavors) {
        copyGolden(flavor);
        final out = StringBuffer();
        final err = StringBuffer();
        expect(run([work.path, _ids[flavor]!], out: out, err: err), 0);
        expect(out.toString().trim(), 'OK');
        expect(err.toString(), isEmpty);
      }
    });

    test('ad12_run_internet_exit_1', () {
      copyGolden();
      edit('manifest.txt', _withInternet);
      final err = StringBuffer();
      expect(run([work.path], out: StringBuffer(), err: err), 1);
      expect(err.toString(), contains('INTERNET'));
    });

    test('ad19_run_bad_align_exit_1', () {
      copyGolden();
      edit(
        'readelf/arm64-v8a/libapp.so.txt',
        (t) => _withLoadAlign(t, '0x1000'),
      );
      expect(run([work.path], out: StringBuffer(), err: StringBuffer()), 1);
    });

    test('ad19_run_missing_readelf_output_exit_1', () {
      copyGolden();
      File('${work.path}/readelf/arm64-v8a/libapp.so.txt').deleteSync();
      final err = StringBuffer();
      expect(run([work.path], out: StringBuffer(), err: err), 1);
      expect(err.toString(), contains('readelf'));
    });

    test('ad19_run_wrong_application_id_exit_1', () {
      copyGolden();
      expect(
        run([work.path, _devId], out: StringBuffer(), err: StringBuffer()),
        1,
      );
    });

    test('ad19_run_missing_badging_exit_1', () {
      copyGolden();
      File('${work.path}/badging.txt').deleteSync();
      expect(run([work.path], out: StringBuffer(), err: StringBuffer()), 0);
      expect(
        run([work.path, _prodId], out: StringBuffer(), err: StringBuffer()),
        1,
      );
    });

    test('ad19_run_empty_work_dir_exit_1', () {
      expect(run([work.path], out: StringBuffer(), err: StringBuffer()), 1);
      expect(run([], out: StringBuffer(), err: StringBuffer()), 1);
    });
  });
}
