// Kiểm âm cho tool/ci/check_flutter_revision.sh bằng `git` giả (story 1.15)
// và kiểm ci.yml chỉ còn một nguồn so revision Flutter.
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'shell_harness.dart';

const _script = 'tool/ci/check_flutter_revision.sh';
const _revision = '737ba8f885dc774b53b442759999a312c9461e4e';
const _otherRevision = '0123456789abcdef0123456789abcdef01234567';

String _metadata({String? revision = _revision}) =>
    '''
# This file tracks properties of this Flutter project.

version:
${revision == null ? '' : '  revision: "$revision"\n'}  channel: "stable"

project_type: app

migration:
  platforms:
    - platform: root
      create_revision: $_otherRevision
      base_revision: $_otherRevision
''';

void main() {
  final shell = detectShell();

  test('nfr7_shell_tests_run_when_required', () {
    expect(shell.failReason, isNull, reason: shell.failReason);
  });

  group('check_flutter_revision.sh', skip: shell.skipReason, () {
    late FakeTools tools;
    late String flutterDir;

    setUp(() {
      tools = FakeTools.create();
      flutterDir = '${tools.root.path}/flutter';
      Directory(flutterDir).createSync();
    });

    tearDown(() {
      tools.dispose();
    });

    ProcessResult runScript(
      String metadata, {
      required String gitRevision,
      String gitExit = '0',
    }) {
      final file = File('${tools.root.path}/.metadata')
        ..writeAsStringSync(metadata);
      return tools.run(
        shell.bash!,
        _script,
        [flutterDir, file.path],
        fakeGit: true,
        environment: {
          'PAK_FAKE_GIT_REVISION': gitRevision,
          'PAK_FAKE_GIT_EXIT': gitExit,
        },
      );
    }

    String output(ProcessResult r) => '${r.stdout}\n${r.stderr}';

    test('ad12_matching_revision_exit_0', () {
      final r = runScript(_metadata(), gitRevision: _revision);
      expect(r.exitCode, 0, reason: output(r));
      expect(r.stdout, contains(_revision));
      expect(tools.logLines('git_args.txt'), [
        '-C',
        flutterDir,
        'rev-parse',
        'HEAD',
      ]);
    });

    test('ad12_mismatched_revision_exit_nonzero', () {
      final r = runScript(_metadata(), gitRevision: _otherRevision);
      expect(r.exitCode, isNot(0), reason: output(r));
      // Thông báo nêu cả hai revision.
      expect(r.stderr, contains(_otherRevision));
      expect(r.stderr, contains(_revision));
    });

    test('ad12_missing_revision_line_exit_nonzero', () {
      // create_revision trùng revision của clone cũng không được tính.
      final r = runScript(
        _metadata(revision: null),
        gitRevision: _otherRevision,
      );
      expect(r.exitCode, isNot(0), reason: output(r));
      expect(r.stderr, contains("khác revision ''"));
    });

    test('ad12_git_failure_exit_nonzero', () {
      final r = runScript(_metadata(), gitRevision: _revision, gitExit: '128');
      expect(r.exitCode, isNot(0), reason: output(r));
      expect(r.stdout, isNot(contains('OK')));
      expect(r.stderr, contains('Không đọc được revision'));
    });

    test('ad12_missing_metadata_file_exit_nonzero', () {
      final r = tools.run(
        shell.bash!,
        _script,
        [flutterDir, '${tools.root.path}/khong_ton_tai'],
        fakeGit: true,
        environment: {'PAK_FAKE_GIT_REVISION': _revision},
      );
      expect(r.exitCode, isNot(0), reason: output(r));
      expect(tools.readLog('git_args.txt'), isNull);
    });

    test('ad12_real_metadata_has_revision_line', () {
      // .metadata thật của repo phải khớp chính revision nó ghi.
      final real = File('.metadata').readAsStringSync();
      final revision = RegExp(
        r'^  revision: "([0-9a-f]{40})"',
        multiLine: true,
      ).firstMatch(real)!.group(1)!;
      final r = tools.run(
        shell.bash!,
        _script,
        [flutterDir],
        fakeGit: true,
        environment: {'PAK_FAKE_GIT_REVISION': revision},
      );
      expect(r.exitCode, 0, reason: output(r));
    });
  });

  group('ci.yml', () {
    final ci = File('../.github/workflows/ci.yml').readAsStringSync();

    test('ad12_ci_has_no_inline_revision_check', () {
      expect(ci, isNot(contains('rev-parse HEAD')));
    });

    test('ad12_ci_checks_revision_after_every_flutter_clone', () {
      final clones = RegExp(
        r'git clone .*flutter/flutter\.git "\$RUNNER_TEMP/flutter"',
      ).allMatches(ci).length;
      final checks =
          'bash tool/ci/check_flutter_revision.sh "\$RUNNER_TEMP/flutter"'
              .allMatches(ci)
              .length;
      expect(clones, greaterThan(0));
      expect(checks, clones);
    });
  });
}
