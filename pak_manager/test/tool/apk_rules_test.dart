import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/ci/apk_rules.dart';

const _ns = 'http://schemas.android.com/apk/res/android';

String _manifest({
  bool internet = false,
  String allowBackup = 'false',
  bool dataExtraction = true,
  bool fullBackup = true,
}) {
  final b = StringBuffer()
    ..writeln('N: android=$_ns (line=2)')
    ..writeln('  E: manifest (line=2)')
    ..writeln('    A: $_ns:versionCode(0x0101021b)=1')
    ..writeln('      E: uses-permission (line=10)')
    ..writeln(
      '        A: $_ns:name(0x01010003)="android.permission.VIBRATE" '
      '(Raw: "android.permission.VIBRATE")',
    );
  if (internet) {
    b
      ..writeln('      E: uses-permission (line=11)')
      ..writeln(
        '        A: $_ns:name(0x01010003)="android.permission.INTERNET" '
        '(Raw: "android.permission.INTERNET")',
      );
  }
  b
    ..writeln('      E: application (line=20)')
    ..writeln('        A: $_ns:label(0x01010001)="pak"')
    ..writeln('        A: $_ns:allowBackup(0x01010280)=$allowBackup');
  if (dataExtraction) {
    b.writeln('        A: $_ns:dataExtractionRules(0x0101063b)=@0x7f100000');
  }
  if (fullBackup) {
    b.writeln('        A: $_ns:fullBackupContent(0x010104eb)=@0x7f100001');
  }
  return b.toString();
}

String _listing(List<String> paths) {
  final b = StringBuffer()
    ..writeln('Archive:  app-prod-release.apk')
    ..writeln('  Length      Date    Time    Name')
    ..writeln('---------  ---------- -----   ----');
  for (final p in paths) {
    b.writeln('   123456  1981-01-01 01:01   $p');
  }
  b
    ..writeln('---------                     -------')
    ..writeln(
      '   ${paths.length * 123456}                     '
      '${paths.length} files',
    );
  return b.toString();
}

const _goodPaths = [
  'AndroidManifest.xml',
  'lib/arm64-v8a/libapp.so',
  'lib/arm64-v8a/libflutter.so',
  'lib/arm64-v8a/libsodium.so',
  'lib/armeabi-v7a/libapp.so',
  'lib/armeabi-v7a/libsodium.so',
  'lib/x86_64/libapp.so',
  'lib/x86_64/libsodium.so',
  'assets/flutter_assets/assets/blocklist.bloom',
];

String _readelf(List<String> aligns) {
  final b = StringBuffer()
    ..writeln()
    ..writeln('Elf file type is DYN (Shared object file)')
    ..writeln('Entry point 0x0')
    ..writeln('There are 10 program headers, starting at offset 64')
    ..writeln()
    ..writeln('Program Headers:')
    ..writeln(
      '  Type           Offset   VirtAddr           PhysAddr           '
      'FileSiz  MemSiz   Flg Align',
    )
    ..writeln(
      '  PHDR           0x000040 0x0000000000000040 0x0000000000000040 '
      '0x000230 0x000230 R   0x8',
    );
  for (final a in aligns) {
    b.writeln(
      '  LOAD           0x000000 0x0000000000000000 0x0000000000000000 '
      '0x0a1b2c 0x0a1b2c R E $a',
    );
  }
  b
    ..writeln(
      '  GNU_STACK      0x000000 0x0000000000000000 0x0000000000000000 '
      '0x000000 0x000000 RW  0x0',
    )
    ..writeln()
    ..writeln(' Section to Segment mapping:');
  return b.toString();
}

Map<String, String> _goodElf() => {
  for (final p in _goodPaths)
    if (p.startsWith('lib/'))
      p.substring(4): p.contains('armeabi-v7a')
          ? _readelf(['0x1000'])
          : _readelf(['0x4000', '0x10000']),
};

const _prodId = 'io.github.truongthanhnam.pakmanager';
const _devId = 'io.github.truongthanhnam.pakmanager.dev';

String _badging(String id) =>
    "package: name='$id' versionCode='1' versionName='0.1.0' "
    "platformBuildVersionName='16' compileSdkVersion='36'\n"
    "sdkVersion:'26'\n"
    "targetSdkVersion:'36'\n"
    "application-label:'pak'\n";

void main() {
  group('manifest', () {
    test('ad12_good_manifest_passes', () {
      expect(checkManifest(_manifest()), isEmpty);
    });

    test('ad12_internet_permission_rejected', () {
      final v = checkManifest(_manifest(internet: true));
      expect(v, hasLength(1));
      expect(v.single, contains('INTERNET'));
    });

    test('nfr8_allow_backup_true_rejected', () {
      final v = checkManifest(_manifest(allowBackup: 'true'));
      expect(v, hasLength(1));
      expect(v.single, contains('allowBackup'));
    });

    test('nfr8_allow_backup_typed_zero_accepted', () {
      expect(checkManifest(_manifest(allowBackup: '(type 0x12)0x0')), isEmpty);
      expect(
        checkManifest(_manifest(allowBackup: '(type 0x12)0xffffffff')),
        hasLength(1),
      );
    });

    test('nfr8_missing_allow_backup_rejected', () {
      final m = _manifest()
          .split('\n')
          .where((l) => !l.contains('allowBackup'))
          .join('\n');
      expect(checkManifest(m).single, contains('allowBackup'));
    });

    test('nfr8_missing_data_extraction_rules_rejected', () {
      final v = checkManifest(_manifest(dataExtraction: false));
      expect(v.single, contains('dataExtractionRules'));
    });

    test('nfr8_missing_full_backup_content_rejected', () {
      final v = checkManifest(_manifest(fullBackup: false));
      expect(v.single, contains('fullBackupContent'));
    });
  });

  group('listing', () {
    test('ad19_good_listing_passes', () {
      expect(parseListing(_listing(_goodPaths)), _goodPaths);
      expect(checkListing(_listing(_goodPaths)), isEmpty);
    });

    test('ad19_missing_libsodium_rejected', () {
      final paths = _goodPaths
          .where((p) => p != 'lib/x86_64/libsodium.so')
          .toList();
      final v = checkListing(_listing(paths));
      expect(v.single, contains('lib/x86_64/libsodium.so'));
    });

    test('ad19_missing_arm64_rejected', () {
      final paths = _goodPaths
          .where((p) => !p.startsWith('lib/arm64-v8a/'))
          .toList();
      expect(checkListing(_listing(paths)).single, contains('arm64-v8a'));
    });

    test('ad19_arm64_dir_without_so_rejected', () {
      final paths = [
        ..._goodPaths.where((p) => !p.startsWith('lib/arm64-v8a/')),
        'lib/arm64-v8a/README.txt',
      ];
      expect(checkListing(_listing(paths)).single, contains('arm64-v8a'));
    });

    test('ad19_no_native_libs_rejected', () {
      final v = checkListing(_listing(['AndroidManifest.xml', blocklistAsset]));
      expect(v, hasLength(2));
      expect(v.first, contains('lib/*/*.so'));
    });

    test('ad15_missing_blocklist_rejected', () {
      final paths = _goodPaths.where((p) => p != blocklistAsset).toList();
      expect(checkListing(_listing(paths)).single, contains('blocklist.bloom'));
    });
  });

  group('readelf', () {
    test('ad19_good_aligns_pass', () {
      expect(checkElfAligns(_goodElf()), isEmpty);
    });

    test('ad19_arm64_4k_align_rejected', () {
      final elf = _goodElf()
        ..['arm64-v8a/libapp.so'] = _readelf(['0x4000', '0x1000']);
      final v = checkElfAligns(elf);
      expect(v.single, contains('arm64-v8a/libapp.so'));
      expect(v.single, contains('0x1000'));
    });

    test('ad19_x86_64_4k_align_rejected', () {
      final elf = _goodElf()..['x86_64/libsodium.so'] = _readelf(['0x1000']);
      expect(checkElfAligns(elf).single, contains('x86_64/libsodium.so'));
    });

    test('ad19_32bit_4k_align_ignored', () {
      final elf = _goodElf()
        ..['armeabi-v7a/libapp.so'] = _readelf(['0x1000'])
        ..['x86/libapp.so'] = _readelf(['0x1000']);
      expect(checkElfAligns(elf), isEmpty);
    });

    test('ad19_no_load_segment_rejected', () {
      final elf = _goodElf()..['arm64-v8a/libflutter.so'] = _readelf([]);
      expect(checkElfAligns(elf).single, contains('không có segment LOAD'));
    });
  });

  group('badging', () {
    test('ad19_prod_and_dev_ids_pass', () {
      expect(checkBadging(_badging(_prodId), _prodId), isEmpty);
      expect(checkBadging(_badging(_devId), _devId), isEmpty);
    });

    test('ad19_prod_with_dev_suffix_rejected', () {
      expect(checkBadging(_badging(_devId), _prodId), hasLength(1));
    });

    test('ad19_dev_missing_suffix_rejected', () {
      expect(checkBadging(_badging(_prodId), _devId), hasLength(1));
    });

    test('ad19_missing_package_line_rejected', () {
      expect(checkBadging("sdkVersion:'26'\n", _prodId), hasLength(1));
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

    void writeWork({
      String? manifest,
      List<String> paths = _goodPaths,
      Map<String, String>? elf,
      String? badging,
    }) {
      File('${work.path}/manifest.txt')
          .writeAsStringSync(manifest ?? _manifest());
      File('${work.path}/listing.txt').writeAsStringSync(_listing(paths));
      (elf ?? _goodElf()).forEach((so, text) {
        File('${work.path}/readelf/$so.txt')
          ..createSync(recursive: true)
          ..writeAsStringSync(text);
      });
      if (badging != null) {
        File('${work.path}/badging.txt').writeAsStringSync(badging);
      }
    }

    test('ad19_run_good_work_dir_exit_0', () {
      writeWork(badging: _badging(_prodId));
      final out = StringBuffer();
      final err = StringBuffer();
      expect(run([work.path, _prodId], out: out, err: err), 0);
      expect(out.toString().trim(), 'OK');
      expect(err.toString(), isEmpty);
    });

    test('ad12_run_internet_exit_1', () {
      writeWork(manifest: _manifest(internet: true));
      final err = StringBuffer();
      expect(run([work.path], out: StringBuffer(), err: err), 1);
      expect(err.toString(), contains('INTERNET'));
    });

    test('ad19_run_bad_align_exit_1', () {
      writeWork(
        elf: _goodElf()..['arm64-v8a/libapp.so'] = _readelf(['0x1000']),
      );
      expect(run([work.path], out: StringBuffer(), err: StringBuffer()), 1);
    });

    test('ad19_run_missing_readelf_output_exit_1', () {
      writeWork(elf: _goodElf()..remove('arm64-v8a/libapp.so'));
      final err = StringBuffer();
      expect(run([work.path], out: StringBuffer(), err: err), 1);
      expect(err.toString(), contains('readelf'));
    });

    test('ad19_run_wrong_application_id_exit_1', () {
      writeWork(badging: _badging(_prodId));
      expect(
        run([work.path, _devId], out: StringBuffer(), err: StringBuffer()),
        1,
      );
    });

    test('ad19_run_missing_badging_exit_1', () {
      writeWork();
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
