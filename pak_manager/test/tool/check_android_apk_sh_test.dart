// Kiểm lớp shell của tool/ci/check_android_apk.sh bằng công cụ giả phát golden
// fixture (story 1.15): truyền `--expect-id` tới apk_rules.dart, hợp đồng thư
// mục `$work`, cổng zipalign và `--save-raw`.
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/ci/apk_rules.dart';
import 'shell_harness.dart';

const _script = 'tool/ci/check_android_apk.sh';
const _golden = 'test/fixtures/apk';
const _prodId = 'io.github.truongthanhnam.pakmanager';
const _internetPermission =
    '      E: uses-permission (line=99)\n'
    '        A: http://schemas.android.com/apk/res/android:name(0x01010003)='
    '"android.permission.INTERNET" (Raw: "android.permission.INTERNET")\n';

void main() {
  final shell = detectShell();

  test('nfr7_shell_tests_run_when_required', () {
    expect(shell.failReason, isNull, reason: shell.failReason);
  });

  group('detectShell', () {
    test('nfr7_windows_skips_with_reason', () {
      final s = detectShell(environment: {}, isWindows: true);
      expect(s.skipReason, contains('Windows'));
      expect(s.failReason, isNull);
    });

    test('nfr7_missing_bash_skips_with_reason', () {
      final s = detectShell(
        environment: {},
        isWindows: false,
        which: (_) => null,
      );
      expect(s.skipReason, contains('bash'));
      expect(s.failReason, isNull);
    });

    test('nfr7_missing_bash_fails_when_required', () {
      final s = detectShell(
        environment: {requireShellTestsVar: '1'},
        isWindows: false,
        which: (_) => null,
      );
      expect(s.failReason, contains(requireShellTestsVar));
    });

    test('nfr7_bash_found_runs', () {
      final s = detectShell(
        environment: {requireShellTestsVar: '1'},
        isWindows: false,
        which: (_) => '/bin/bash',
      );
      expect(s.bash, '/bin/bash');
      expect(s.skipReason, isNull);
      expect(s.failReason, isNull);
    });
  });

  group('check_android_apk.sh', skip: shell.skipReason, () {
    late FakeTools tools;
    late Directory fixture;
    late String realDart;

    setUp(() {
      realDart = findOnPath('dart')!;
      tools = FakeTools.create();
      // Bản sao golden prod để từng ca sửa mà không đụng fixture gốc.
      fixture = Directory('${tools.root.path}/fixture');
      copyTree(Directory('$_golden/prod'), fixture);
    });

    tearDown(() {
      tools.dispose();
    });

    ProcessResult runScript(
      List<String> args, {
      Map<String, String> environment = const {},
    }) => tools.run(
      shell.bash!,
      _script,
      [tools.apk, ...args],
      environment: {
        'PAK_FAKE_FIXTURE': fixture.path,
        'PAK_REAL_DART': realDart,
        ...environment,
      },
    );

    String output(ProcessResult r) => '${r.stdout}\n${r.stderr}';

    void replaceInFixture(String name, String from, String to) {
      final file = File('${fixture.path}/$name');
      final text = file.readAsStringSync();
      expect(text, contains(from), reason: 'golden $name không có "$from"');
      file.writeAsStringSync(text.replaceAll(from, to));
    }

    test('ad19_valid_apk_exit_0_and_work_dir_contract', () {
      final r = runScript(['--expect-id', _prodId]);
      expect(r.exitCode, 0, reason: output(r));
      expect(r.stdout, contains('check_android_apk: OK'));

      // apk_rules.dart nhận đúng `<work> <id>`.
      final args = tools.logLines('dart_args.txt');
      expect(args, hasLength(4));
      expect(args.sublist(0, 2), ['run', 'tool/ci/apk_rules.dart']);
      expect(args[3], _prodId);

      // Cây `$work` lúc gọi luật đúng hợp đồng của apk_rules.dart.
      final tree = tools.logLines('dart_work_tree.txt');
      final sos = soFilesInListing(
        File('${fixture.path}/listing.txt').readAsStringSync(),
      );
      expect(sos, isNotEmpty);
      expect(
        tree,
        containsAll([
          './manifest.txt',
          './listing.txt',
          './badging.txt',
          for (final so in sos) './readelf/$so.txt',
        ]),
      );

      // Dùng build-tools mới nhất (sort -V, không phải sort thường) và đúng
      // cờ zipalign 16 KB.
      final calls = tools.logLines('calls.txt');
      expect(calls, contains('zipalign -c -P 16 -v 4 ${tools.apk}'));
      expect(r.stdout, contains('build-tools/$fakeBuildToolsVersion'));

      // Lời gọi đầy đủ, không rơi mất tham số (vd --file, -lW).
      final work = args[2];
      expect(tools.toolCalls('aapt2'), [
        'aapt2 dump xmltree --file AndroidManifest.xml ${tools.apk}',
        'aapt2 dump badging ${tools.apk}',
      ]);
      expect(
        tools.toolCalls('readelf'),
        unorderedEquals([
          for (final so in sos) 'readelf -lW $work/apk/lib/$so',
        ]),
      );

      // Thư mục `$work` được dọn sau khi chạy.
      expect(Directory(args[2]).existsSync(), isFalse);
    });

    test('ad19_without_expect_id_skips_badging', () {
      final r = runScript([]);
      expect(r.exitCode, 0, reason: output(r));
      final args = tools.logLines('dart_args.txt');
      expect(args, hasLength(3));
      expect(
        tools.logLines('dart_work_tree.txt'),
        isNot(contains('./badging.txt')),
      );
    });

    test('ad19_wrong_application_id_exit_nonzero', () {
      replaceInFixture('badging.txt', "name='$_prodId'", "name='$_prodId.dev'");
      final r = runScript(['--expect-id', _prodId]);
      expect(r.exitCode, isNot(0), reason: output(r));
      expect(r.stderr, contains('applicationId'));
      expect(r.stdout, contains('FAIL: apk_rules'));
    });

    test('ad12_internet_permission_exit_nonzero', () {
      File('${fixture.path}/manifest.txt')
          .writeAsStringSync(_internetPermission, mode: FileMode.append);
      final r = runScript(['--expect-id', _prodId]);
      expect(r.exitCode, isNot(0), reason: output(r));
      expect(r.stderr, contains('INTERNET'));
      expect(r.stdout, contains('check_android_apk: FAIL'));
    });

    test('ad19_zipalign_failure_exit_nonzero', () {
      final r = runScript(
        ['--expect-id', _prodId],
        environment: {'PAK_FAKE_ZIPALIGN_EXIT': '1'},
      );
      expect(r.exitCode, isNot(0), reason: output(r));
      expect(r.stdout, contains('FAIL: zipalign'));
      // Phần còn lại hợp lệ: luật vẫn chạy và pass.
      expect(r.stdout, contains('OK: apk_rules'));
    });

    void expectRawSaved(Directory raw) {
      for (final file in fixture.listSync(recursive: true)) {
        if (file is! File) {
          continue;
        }
        final rel = file.path.substring(fixture.path.length + 1);
        if (rel == 'build-tools.txt') {
          continue;
        }
        final saved = File('${raw.path}/$rel');
        expect(saved.existsSync(), isTrue, reason: 'thiếu $rel');
        expect(
          saved.readAsBytesSync(),
          file.readAsBytesSync(),
          reason: '$rel khác output thô',
        );
      }
      expect(
        File('${raw.path}/build-tools.txt').readAsStringSync().trim(),
        fakeBuildToolsVersion,
      );
    }

    test('ad19_save_raw_copies_output', () {
      final raw = Directory('${tools.root.path}/raw/prod');
      final r = runScript(['--expect-id', _prodId, '--save-raw', raw.path]);
      expect(r.exitCode, 0, reason: output(r));
      expectRawSaved(raw);
    });

    test('ad19_save_raw_copies_output_when_script_fails', () {
      File('${fixture.path}/manifest.txt')
          .writeAsStringSync(_internetPermission, mode: FileMode.append);
      final raw = Directory('${tools.root.path}/raw/prod');
      final r = runScript(
        ['--expect-id', _prodId, '--save-raw', raw.path],
        environment: {'PAK_FAKE_ZIPALIGN_EXIT': '1'},
      );
      expect(r.exitCode, isNot(0), reason: output(r));
      expectRawSaved(raw);
    });

    test('ad19_save_raw_keeps_partial_output_when_readelf_fails', () {
      // readelf giả `cat` file fixture không tồn tại -> fail giữa chừng lúc
      // thu thập (set -e), trước khi kịp gọi apk_rules.dart. zipalign.txt,
      // manifest.txt, listing.txt phải vẫn được lưu: redirection `>` không
      // nên bị hiểu nhầm là "đã thu thập xong".
      final sos = soFilesInListing(
        File('${fixture.path}/listing.txt').readAsStringSync(),
      );
      File('${fixture.path}/readelf/${sos.first}.txt').deleteSync();
      final raw = Directory('${tools.root.path}/raw/prod');
      final r = runScript(['--expect-id', _prodId, '--save-raw', raw.path]);
      expect(r.exitCode, isNot(0), reason: output(r));
      expect(tools.readLog('dart_args.txt'), isNull);
      expect(File('${raw.path}/zipalign.txt').existsSync(), isTrue);
      expect(File('${raw.path}/manifest.txt').existsSync(), isTrue);
      expect(File('${raw.path}/listing.txt').existsSync(), isTrue);
      expect(File('${raw.path}/build-tools.txt').existsSync(), isTrue);
      // File readelf dở dang (do redirection tạo trước khi lệnh fail) không
      // được lưu như output thật.
      expect(
        File('${raw.path}/readelf/${sos.first}.txt').existsSync(),
        isFalse,
      );
    });

    test('ad19_save_raw_reused_dir_drops_stale_output_only', () {
      final raw = Directory('${tools.root.path}/raw/prod');
      var r = runScript(['--expect-id', _prodId, '--save-raw', raw.path]);
      expect(r.exitCode, 0, reason: output(r));
      expect(File('${raw.path}/badging.txt').existsSync(), isTrue);
      // File không do script ghi phải còn nguyên (không xóa cả thư mục).
      final keep = File('${raw.path}/khac.txt')..writeAsStringSync('giữ');
      r = runScript(['--save-raw', raw.path]);
      expect(r.exitCode, 0, reason: output(r));
      expect(File('${raw.path}/badging.txt').existsSync(), isFalse);
      expect(keep.readAsStringSync(), 'giữ');
    });

    test('ad19_save_raw_missing_directory_exit_nonzero', () {
      final r = runScript(['--expect-id', _prodId, '--save-raw']);
      expect(r.exitCode, isNot(0));
      expect(tools.readLog('dart_args.txt'), isNull);
    });

    test('ad19_unknown_argument_exit_nonzero', () {
      final r = runScript(['--khong-co']);
      expect(r.exitCode, isNot(0));
      expect(tools.readLog('dart_args.txt'), isNull);
    });
  });
}
