// Kiểm luật cấu trúc ci.yml (story 1.16). Mọi ca âm dựng bằng cách sửa bản
// `.github/workflows/ci.yml` thật, không viết tay workflow mẫu.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/ci/ci_structure.dart';

final _ci = File('../.github/workflows/ci.yml')
    .readAsStringSync()
    .replaceAll('\r', '');

/// Khoảng dòng [start, end) của job [job] trong [lines].
(int, int) _jobRange(List<String> lines, String job) {
  final start = lines.indexOf('  $job:');
  expect(start, greaterThanOrEqualTo(0), reason: 'không thấy job $job');
  var end = start + 1;
  while (end < lines.length &&
      !RegExp(r'^  [A-Za-z0-9_-]+:\s*$').hasMatch(lines[end]) &&
      !RegExp(r'^\S').hasMatch(lines[end])) {
    end++;
  }
  // Comment ngay trước job kế tiếp thuộc về job đó.
  while (end > start && lines[end - 1].startsWith('  #')) {
    end--;
  }
  return (start, end);
}

/// Khoảng dòng [start, end) của bước chứa [marker] trong job [job].
(int, int) _stepRange(List<String> lines, String job, String marker) {
  final (jobStart, jobEnd) = _jobRange(lines, job);
  var at = -1;
  for (var i = jobStart; i < jobEnd; i++) {
    if (lines[i].contains(marker)) {
      at = i;
      break;
    }
  }
  expect(at, greaterThanOrEqualTo(0), reason: 'không thấy "$marker" ở $job');
  var start = at;
  while (!lines[start].startsWith('      - ')) {
    start--;
  }
  var end = start + 1;
  while (end < jobEnd) {
    final l = lines[end];
    if (l.trim().isNotEmpty && !l.startsWith('        ')) {
      break;
    }
    end++;
  }
  return (start, end);
}

String _removeStep(String job, String marker) {
  final lines = _ci.split('\n');
  final (s, e) = _stepRange(lines, job, marker);
  lines.removeRange(s, e);
  return lines.join('\n');
}

/// Thêm khóa [key] (`tên: giá trị`) vào bước; nếu bước đã có khóa cùng tên
/// thì thay dòng đó (GitHub Actions không nhận khóa trùng).
String _addStepKey(String job, String marker, String key) {
  final lines = _ci.split('\n');
  final (s, e) = _stepRange(lines, job, marker);
  final name = key.split(':').first;
  for (var i = s + 1; i < e; i++) {
    if (lines[i].startsWith('        $name:')) {
      lines[i] = '        $key';
      return lines.join('\n');
    }
  }
  lines.insert(s + 1, '        $key');
  return lines.join('\n');
}

String _addJobKey(String job, String key) {
  final lines = _ci.split('\n');
  final (s, _) = _jobRange(lines, job);
  lines.insert(s + 1, '    $key');
  return lines.join('\n');
}

/// Chuyển bước chứa [marker] xuống ngay sau bước chứa [after] (cùng job).
String _moveStepAfter(String job, String marker, String after) {
  final lines = _ci.split('\n');
  final (s, e) = _stepRange(lines, job, marker);
  final moved = lines.sublist(s, e);
  lines.removeRange(s, e);
  final (_, afterEnd) = _stepRange(lines, job, after);
  lines.insertAll(afterEnd, moved);
  return lines.join('\n');
}

/// Bước cổng: job, dấu nhận diện trong ci.yml thật, đoạn nhãn trong thông báo.
final _gates = [
  ('android', 'check_workflow_secret[s].dart', 'kiểm secret'),
  ('android', 'dart run tool/ci/check_stack.dart', 'kiểm Stack'),
  ('android', 'dart run tool/ci/ci_structure.dart', 'kiểm cấu trúc ci.yml'),
  ('android', 'PAK_REQUIRE_SHELL_TESTS', 'flutter test'),
  ('android', 'pakmanager --save-raw', 'kiểm APK prod'),
  ('android', 'pakmanager.dev --save-raw', 'kiểm APK dev'),
  ('android', 'name: apk-raw-output', 'apk-raw-output'),
  ('android', 'gradle/actions/wrapper-validation', 'Gradle wrapper'),
  ('android', 'check_flutter_revision.sh', 'clone Flutter'),
  ('ios', 'check_flutter_revision.sh', 'clone Flutter'),
  ('ios', 'xcode-select -s', 'xcode-select'),
  (
    'integration-android',
    'gradle/actions/wrapper-validation',
    'Gradle wrapper',
  ),
  ('integration-android', 'check_flutter_revision.sh', 'clone Flutter'),
  ('integration-ios', 'check_flutter_revision.sh', 'clone Flutter'),
  ('integration-ios', 'xcode-select -s', 'xcode-select'),
  // Retro Epic 1, A1: mọi bước cổng còn lại của ci.yml.
  for (final job in _jobs)
    (job, 'flutter pub get --enforce-lockfile', 'pub get theo lockfile'),
  ('android', 'dart run tool/check_imports.dart', 'luật import'),
  ('android', 'flutter analyze --fatal-infos', 'phân tích tĩnh'),
  ('android', 'flutter gen-l10n', 'code gen-l10n'),
  ('android', 'dart run pigeon --input', 'code Pigeon'),
  ('android', 'gen_vault_v1.dart', 'fixture vault'),
  (
    'integration-android',
    'flutter test integration_test --flavor dev',
    'integration test Android',
  ),
  (
    'integration-ios',
    'flutter test integration_test -d',
    'integration test iOS',
  ),
  ('ios', '--no-codesign --build-number', 'build iOS không cờ'),
  ('ios', 'Kiểm bundle id build không cờ', 'kiểm bundle id iOS không cờ'),
  ('ios', '--flavor prod --build-number', 'build iOS prod'),
  ('ios', 'Kiểm bundle id prod', 'kiểm bundle id iOS prod'),
  ('ios', '--flavor dev --build-number', 'build iOS dev'),
  ('ios', 'Kiểm bundle id dev', 'kiểm bundle id iOS dev'),
];

/// Thay [from] bằng [to] (lần đầu) trong bước chứa [marker] của job [job].
String _replaceInStep(String job, String marker, String from, String to) {
  final lines = _ci.split('\n');
  final (s, e) = _stepRange(lines, job, marker);
  final step = lines.sublist(s, e).join('\n');
  final changed = step.replaceFirst(from, to);
  expect(changed, isNot(step), reason: 'không thấy "$from" ở bước $marker');
  lines.replaceRange(s, e, changed.split('\n'));
  return lines.join('\n');
}

const _jobs = ['android', 'ios', 'integration-android', 'integration-ios'];

Matcher _violation(List<String> parts) =>
    anyElement(allOf([for (final p in parts) contains(p)]));

void main() {
  test('ad19_real_ci_yml_has_no_structure_violation', () {
    expect(checkCiStructure(_ci), isEmpty);
    final out = StringBuffer();
    final err = StringBuffer();
    expect(
      run([defaultCiPath], out: out, err: err),
      0,
      reason: '$err',
    );
    expect(out.toString().trim(), 'OK');
  });

  test('ad19_parser_reads_jobs_and_steps_of_real_ci_yml', () {
    final wf = parseCiWorkflow(_ci);
    expect(wf.jobs.map((j) => j.id), _jobs);
    expect(wf.triggers.keys, containsAll(['pull_request', 'push']));
    final android = wf.job('android')!;
    final testStep = android.steps.singleWhere(
      (s) => s.envMap.containsKey('PAK_REQUIRE_SHELL_TESTS'),
    );
    expect(testStep.envMap['PAK_REQUIRE_SHELL_TESTS'], '1');
    expect(testStep.commandLines, ['flutter test']);
    // Dòng của bước khớp dòng thật trong ci.yml.
    expect(
      _ci.split('\n')[testStep.line - 1],
      contains('- name: Unit + widget'),
    );
    final emulator = wf
        .job('integration-android')!
        .steps
        .singleWhere(
          (s) => (s.uses ?? '').startsWith(
            'reactivecircus/android-emulator-runner@',
          ),
        );
    expect(
      emulator.withMap['script'],
      'flutter test integration_test --flavor dev',
    );
  });

  group('gỡ bước cổng', () {
    for (final (job, marker, label) in _gates) {
      test('ad19_removing_gate_step_rejected: $job / $label', () {
        final v = checkCiStructure(_removeStep(job, marker));
        expect(v, _violation(['job $job', 'thiếu bước cổng', label]));
      });
    }
  });

  group('tắt bước cổng', () {
    for (final (job, marker, label) in _gates) {
      for (final key in [
        'if: false',
        r'if: ${{ always() }}',
        'continue-on-error: true',
        r'continue-on-error: ${{ true }}',
      ]) {
        test('ad19_disabled_gate_step_rejected: $job / $label / $key', () {
          final v = checkCiStructure(_addStepKey(job, marker, key));
          expect(v, _violation(['job $job', label, key]));
        });
      }
    }

    test('ad19_upload_only_allows_not_cancelled_condition', () {
      final yaml = _ci.replaceFirst(
        r'if: ${{ !cancelled() }}',
        r'if: ${{ success() }}',
      );
      expect(yaml, isNot(_ci));
      expect(
        checkCiStructure(yaml),
        _violation(['apk-raw-output', r'if: ${{ success() }}']),
      );
    });

    test('ad19_continue_on_error_false_allowed', () {
      final yaml = _addStepKey(
        'android',
        'dart run tool/ci/check_stack.dart',
        'continue-on-error: false',
      );
      expect(checkCiStructure(yaml), isEmpty);
    });

    test('ad19_renaming_gate_step_still_clean', () {
      final yaml = _ci.replaceFirst('Kiểm Stack (AD-12)', 'Bước khác');
      expect(yaml, isNot(_ci));
      expect(checkCiStructure(yaml), isEmpty);
    });
  });

  group('tắt job chứa cổng', () {
    for (final job in _jobs) {
      for (final key in ['if: false', 'continue-on-error: true']) {
        test('ad19_disabled_gate_job_rejected: $job / $key', () {
          final v = checkCiStructure(_addJobKey(job, key));
          expect(v, _violation(['job $job', key]));
        });
      }
    }
  });

  group('nội dung bước cổng', () {
    test('ad19_flutter_test_without_require_shell_tests_rejected', () {
      final yaml = _ci.replaceFirst(
        "PAK_REQUIRE_SHELL_TESTS: '1'",
        "PAK_REQUIRE_SHELL_TESTS: '0'",
      );
      expect(yaml, isNot(_ci));
      expect(
        checkCiStructure(yaml),
        _violation(['thiếu bước cổng', 'flutter test']),
      );
    });

    test('ad19_flutter_test_on_subset_rejected', () {
      final lines = _ci.split('\n');
      final i = lines.indexOf('        run: flutter test');
      expect(i, greaterThanOrEqualTo(0));
      lines[i] = '        run: flutter test test/core';
      expect(
        checkCiStructure(lines.join('\n')),
        _violation(['thiếu bước cổng', 'flutter test']),
      );
    });

    for (final (flag, label) in [
      ('--save-raw build/apk-raw/prod', 'kiểm APK prod'),
      ('--save-raw build/apk-raw/dev', 'kiểm APK dev'),
      ('--expect-id io.github.truongthanhnam.pakmanager.dev ', 'kiểm APK dev'),
    ]) {
      test('ad19_apk_check_without_flag_rejected: $flag', () {
        final yaml = _ci.replaceFirst(flag, '');
        expect(yaml, isNot(_ci));
        expect(checkCiStructure(yaml), _violation(['thiếu bước cổng', label]));
      });
    }

    test('ad19_secret_check_on_other_file_rejected', () {
      final yaml = _ci.replaceFirst(
        'check_workflow_secret[s].dart ../.github/workflows/ci.yml',
        'check_workflow_secret[s].dart ../.github/workflows/other.yml',
      );
      expect(yaml, isNot(_ci));
      expect(checkCiStructure(yaml), _violation(['thiếu bước cổng', 'secret']));
    });

    test('ad19_commented_out_gate_command_rejected', () {
      final yaml = _ci.replaceFirst(
        'run: dart run tool/ci/check_stack.dart',
        'run: |\n          # dart run tool/ci/check_stack.dart\n          true',
      );
      expect(yaml, isNot(_ci));
      expect(
        checkCiStructure(yaml),
        _violation(['thiếu bước cổng', 'kiểm Stack']),
      );
    });

    test('ad19_revision_check_before_clone_rejected', () {
      final lines = _ci.split('\n');
      final (s, e) = _stepRange(lines, 'ios', 'check_flutter_revision.sh');
      final clone = lines.indexWhere((l) => l.contains('git clone'), s);
      final check = lines.indexWhere(
        (l) => l.contains('check_flutter_revision.sh'),
        s,
      );
      expect(clone < check && check < e, isTrue);
      final tmp = lines[clone];
      lines[clone] = lines[check];
      lines[check] = tmp;
      expect(
        checkCiStructure(lines.join('\n')),
        _violation(['job ios', 'thiếu bước cổng', 'clone Flutter']),
      );
    });

    test('ad19_upload_with_other_artifact_name_rejected', () {
      final yaml = _ci.replaceFirst('name: apk-raw-output', 'name: other');
      expect(checkCiStructure(yaml), _violation(['apk-raw-output']));
    });

    test('ad19_upload_with_other_path_rejected', () {
      final yaml = _ci.replaceFirst(
        'path: pak_manager/build/apk-raw',
        'path: pak_manager/build/apk-raw/prod',
      );
      expect(yaml, isNot(_ci));
      expect(checkCiStructure(yaml), _violation(['apk-raw-output']));
    });

    for (final (line, label) in [
      ('dart run tool/ci/check_stack.dart', 'kiểm Stack'),
      ('dart run tool/ci/ci_structure.dart', 'kiểm cấu trúc ci.yml'),
      (
        '--expect-id io.github.truongthanhnam.pakmanager --save-raw '
            'build/apk-raw/prod',
        'kiểm APK prod',
      ),
      (
        '--expect-id io.github.truongthanhnam.pakmanager.dev --save-raw '
            'build/apk-raw/dev',
        'kiểm APK dev',
      ),
      (r'check_flutter_revision.sh "$RUNNER_TEMP/flutter"', 'clone Flutter'),
      ('flutter pub get --enforce-lockfile', 'pub get theo lockfile'),
      ('dart run tool/check_imports.dart', 'luật import'),
      ('flutter analyze --fatal-infos --fatal-warnings', 'phân tích tĩnh'),
      ('flutter gen-l10n', 'code gen-l10n'),
      (r'changes="$(git status --porcelain -- lib/l10n)"', 'code gen-l10n'),
      ('dart run pigeon --input pigeons/platform_api.dart', 'code Pigeon'),
      ('dart run tool/fixtures/gen_vault_v1.dart', 'fixture vault'),
      (
        'flutter test integration_test --flavor dev',
        'integration test Android',
      ),
      (r'flutter test integration_test -d "$SIM_UDID"', 'integration test iOS'),
      (
        r'flutter build ios --release --no-codesign --build-number '
            r'"$GITHUB_RUN_NUMBER"',
        'build iOS không cờ',
      ),
      (
        r'flutter build ios --release --no-codesign --flavor prod '
            r'--build-number "$GITHUB_RUN_NUMBER"',
        'build iOS prod',
      ),
    ]) {
      for (final suffix in [' || true', '; true']) {
        test('ad19_gate_command_with_suffix_rejected: $label /$suffix', () {
          final yaml = _ci.replaceFirst(line, '$line$suffix');
          expect(yaml, isNot(_ci));
          expect(
            checkCiStructure(yaml),
            _violation(['thiếu bước cổng', label]),
          );
        });
      }
    }

    test('ad19_flutter_test_with_flag_rejected', () {
      final yaml = _ci.replaceFirst(
        'run: flutter test\n',
        'run: flutter test --tags fast\n',
      );
      expect(yaml, isNot(_ci));
      expect(
        checkCiStructure(yaml),
        _violation(['thiếu bước cổng', 'flutter test']),
      );
    });

    test('ad19_flutter_clone_with_hardcoded_branch_rejected', () {
      final yaml = _ci.replaceFirst(
        r'--branch "$FLUTTER_VERSION"',
        '--branch 3.48.0',
      );
      expect(yaml, isNot(_ci));
      expect(
        checkCiStructure(yaml),
        _violation(['job android', 'thiếu bước cổng', 'clone Flutter']),
      );
    });

    test('ad19_xcode_select_default_xcode_rejected', () {
      final lines = _ci.split('\n');
      final (s, e) = _stepRange(lines, 'integration-ios', 'xcode-select -s');
      for (var i = s; i < e; i++) {
        lines[i] = lines[i].replaceAll(
          '/Applications/Xcode_26.3.app',
          '/Applications/Xcode.app',
        );
      }
      final yaml = lines.join('\n');
      expect(yaml, isNot(_ci));
      expect(
        checkCiStructure(yaml),
        _violation(['job integration-ios', 'thiếu bước cổng', 'xcode-select']),
      );
    });

    test('ad19_block_scalar_condition_on_gate_rejected', () {
      for (final key in ['if: >-', 'continue-on-error: |']) {
        final lines = _ci.split('\n');
        final (s, _) = _stepRange(
          lines,
          'android',
          'dart run tool/ci/check_stack.dart',
        );
        lines.insertAll(s + 1, ['        $key', '          false']);
        final name = key.split(':').first;
        expect(
          checkCiStructure(lines.join('\n')),
          _violation(['job android', 'kiểm Stack', '$name:']),
        );
      }
    });

    test('ad19_flutter_via_action_requires_clone_and_revision', () {
      // Thay bước clone của job ios bằng action cài Flutter.
      final lines = _ci.split('\n');
      final (s, e) = _stepRange(lines, 'ios', 'check_flutter_revision.sh');
      lines.replaceRange(s, e, [
        '      - uses: subosito/flutter-action@${'0' * 40} # v2.0.0',
        '',
      ]);
      // Bỏ mọi lệnh `flutter` khác của job để chỉ còn `uses:` nhắc tới nó.
      final yaml = lines
          .map(
            (l) => l.contains('flutter') && !l.contains('flutter-action')
                ? l.replaceAll('flutter', 'tool')
                : l,
          )
          .join('\n');
      expect(
        checkCiStructure(yaml),
        _violation(['job ios', 'thiếu bước cổng', 'clone Flutter']),
      );
    });
  });

  group('cổng sinh lại rồi so', () {
    for (final (marker, path, label) in [
      ('flutter gen-l10n', 'lib/l10n', 'code gen-l10n'),
      ('dart run pigeon --input', 'lib android ios', 'code Pigeon'),
      ('gen_vault_v1.dart', 'test/fixtures/vault', 'fixture vault'),
    ]) {
      test('ad19_regen_gate_exit_0_rejected: $label', () {
        final yaml = _replaceInStep('android', marker, 'exit 1', 'exit 0');
        expect(
          checkCiStructure(yaml),
          _violation(['job android', 'thiếu bước cổng', label]),
        );
      });

      test('ad19_regen_gate_other_path_rejected: $label', () {
        final yaml = _replaceInStep(
          'android',
          marker,
          'git status --porcelain -- $path)',
          'git status --porcelain -- $path/x)',
        );
        expect(
          checkCiStructure(yaml),
          _violation(['job android', 'thiếu bước cổng', label]),
        );
      });

      test('ad19_regen_gate_without_change_check_rejected: $label', () {
        final yaml = _replaceInStep(
          'android',
          marker,
          r'if [[ -n "$changes" ]]; then',
          r'if [[ -z "$changes" ]]; then',
        );
        expect(
          checkCiStructure(yaml),
          _violation(['job android', 'thiếu bước cổng', label]),
        );
      });

      test('ad19_regen_gate_exit_after_fi_rejected: $label', () {
        // `exit 1` dời ra sau `fi`: không còn nằm trong nhánh có thay đổi.
        final lines = _ci.split('\n');
        final (s, e) = _stepRange(lines, 'android', marker);
        final exit = lines.indexWhere((l) => l.trim() == 'exit 1', s);
        final fi = lines.indexWhere((l) => l.trim() == 'fi', exit);
        expect(exit > s && fi < e, isTrue);
        final moved = lines.removeAt(exit);
        lines.insert(fi, moved.replaceFirst('  exit 1', 'exit 1'));
        expect(
          checkCiStructure(lines.join('\n')),
          _violation(['job android', 'thiếu bước cổng', label]),
        );
      });
    }

    test('ad19_generate_after_compare_rejected', () {
      // Lệnh sinh đứng sau phép so thì phép so chạy trên code cũ.
      final lines = _ci.split('\n');
      final (s, e) = _stepRange(lines, 'android', 'flutter gen-l10n');
      final gen = lines.indexWhere((l) => l.trim() == 'flutter gen-l10n', s);
      final moved = lines.removeAt(gen);
      lines.insert(e - 1, moved);
      expect(
        checkCiStructure(lines.join('\n')),
        _violation(['job android', 'thiếu bước cổng', 'code gen-l10n']),
      );
    });
  });

  group('thu hẹp lệnh cổng', () {
    test('ad19_analyze_without_fatal_flag_rejected', () {
      for (final to in [
        'flutter analyze --fatal-warnings',
        'flutter analyze --fatal-infos',
        'flutter analyze',
      ]) {
        final yaml = _ci.replaceFirst(
          'flutter analyze --fatal-infos --fatal-warnings',
          to,
        );
        expect(
          checkCiStructure(yaml),
          _violation(['job android', 'thiếu bước cổng', 'phân tích tĩnh']),
          reason: to,
        );
      }
    });

    test('ad19_check_imports_on_other_root_rejected', () {
      final yaml = _ci.replaceFirst(
        'dart run tool/check_imports.dart',
        'dart run tool/check_imports.dart test',
      );
      expect(
        checkCiStructure(yaml),
        _violation(['job android', 'thiếu bước cổng', 'luật import']),
      );
    });

    test('ad19_pub_get_without_enforce_lockfile_rejected', () {
      for (final job in _jobs) {
        final yaml = _replaceInStep(
          job,
          'flutter pub get --enforce-lockfile',
          'flutter pub get --enforce-lockfile',
          'flutter pub get',
        );
        expect(
          checkCiStructure(yaml),
          _violation(['job $job', 'thiếu bước cổng', 'pub get theo lockfile']),
          reason: job,
        );
      }
    });

    test('ad19_integration_android_with_name_rejected', () {
      final yaml = _ci.replaceFirst(
        'script: flutter test integration_test --flavor dev',
        'script: flutter test integration_test --flavor dev --name x',
      );
      expect(yaml, isNot(_ci));
      expect(
        checkCiStructure(yaml),
        _violation([
          'job integration-android',
          'thiếu bước cổng',
          'integration test Android',
        ]),
      );
    });

    test('ad19_integration_android_script_outside_emulator_rejected', () {
      // Gỡ emulator runner, chạy lệnh trong `run:` (không có emulator).
      final lines = _ci.split('\n');
      final (s, e) = _stepRange(
        lines,
        'integration-android',
        'reactivecircus/android-emulator-runner',
      );
      lines.replaceRange(s, e, [
        '      - name: Integration test',
        '        run: flutter test integration_test --flavor dev',
      ]);
      expect(
        checkCiStructure(lines.join('\n')),
        _violation([
          'job integration-android',
          'thiếu bước cổng',
          'integration test Android',
        ]),
      );
    });

    test('ad19_integration_ios_with_name_rejected', () {
      final yaml = _ci.replaceFirst(
        r'flutter test integration_test -d "$SIM_UDID"',
        r'flutter test integration_test -d "$SIM_UDID" --name x',
      );
      expect(yaml, isNot(_ci));
      expect(
        checkCiStructure(yaml),
        _violation([
          'job integration-ios',
          'thiếu bước cổng',
          'integration test iOS',
        ]),
      );
    });
  });

  group('cặp build→kiểm iOS', () {
    test('ad19_removing_ios_prod_build_rejects_prod_check', () {
      // Bước kiểm prod lúc này đọc plist của build không cờ (cùng id prod).
      final yaml = _removeStep('ios', '--flavor prod --build-number');
      expect(
        checkCiStructure(yaml),
        _violation(['job ios', 'thiếu bước cổng', 'kiểm bundle id iOS prod']),
      );
    });

    test('ad19_ios_check_after_next_build_rejected', () {
      final yaml = _moveStepAfter(
        'ios',
        'Kiểm bundle id prod',
        '--flavor dev --build-number',
      );
      expect(
        checkCiStructure(yaml),
        _violation(['job ios', 'thiếu bước cổng', 'kiểm bundle id iOS prod']),
      );
    });

    test('ad19_ios_check_before_its_build_rejected', () {
      final yaml = _moveStepAfter(
        'ios',
        '--flavor dev --build-number',
        'Kiểm bundle id dev',
      );
      expect(
        checkCiStructure(yaml),
        _violation(['job ios', 'thiếu bước cổng', 'kiểm bundle id iOS dev']),
      );
    });

    for (final (marker, from, to, label) in [
      (
        'Kiểm bundle id dev',
        '"io.github.truongthanhnam.pakmanager.dev"',
        '"io.github.truongthanhnam.pakmanager"',
        'kiểm bundle id iOS dev',
      ),
      (
        'Kiểm bundle id prod',
        '"PAK Manager"',
        '"PAK Manager Dev"',
        'kiểm bundle id iOS prod',
      ),
      (
        'Kiểm bundle id build không cờ',
        'exit 1',
        'exit 0',
        'kiểm bundle id iOS không cờ',
      ),
      (
        'Kiểm bundle id prod',
        'Print :CFBundleIdentifier',
        'Print :CFBundleName',
        'kiểm bundle id iOS prod',
      ),
      (
        'Kiểm bundle id dev',
        'build/ios/iphoneos/Runner.app/Info.plist',
        'build/ios/iphonesimulator/Runner.app/Info.plist',
        'kiểm bundle id iOS dev',
      ),
    ]) {
      test('ad19_ios_check_loosened_rejected: $label / $to', () {
        final yaml = _replaceInStep('ios', marker, from, to);
        expect(
          checkCiStructure(yaml),
          _violation(['job ios', 'thiếu bước cổng', label]),
        );
      });
    }

    test('ad19_ios_build_with_extra_flag_rejected', () {
      final yaml = _replaceInStep(
        'ios',
        '--flavor dev --build-number',
        '--flavor dev --build-number',
        '--flavor dev --debug --build-number',
      );
      final v = checkCiStructure(yaml);
      expect(v, _violation(['job ios', 'thiếu bước cổng', 'build iOS dev']));
      expect(v, _violation(['job ios', 'kiểm bundle id iOS dev']));
    });

    test('ad19_ios_check_step_with_own_build_rejected', () {
      // Bước kiểm tự build trước khi đọc plist: plist không còn là của build
      // cùng flavor đứng trước nó.
      final yaml = _replaceInStep(
        'ios',
        'Kiểm bundle id prod',
        'actual="',
        'flutter build ios --release --no-codesign --build-number '
            '"\$GITHUB_RUN_NUMBER"\n          actual="',
      );
      expect(
        checkCiStructure(yaml),
        _violation(['job ios', 'thiếu bước cổng', 'kiểm bundle id iOS prod']),
      );
    });

    test('ad19_ios_check_exit_after_fi_rejected', () {
      // `exit 1` đầu tiên dời ra sau `fi`: id sai không còn làm bước fail.
      final lines = _ci.split('\n');
      final (s, e) = _stepRange(lines, 'ios', 'Kiểm bundle id dev');
      final exit = lines.indexWhere((l) => l.trim() == 'exit 1', s);
      final fi = lines.indexWhere((l) => l.trim() == 'fi', exit);
      expect(exit > s && fi < e, isTrue);
      final moved = lines.removeAt(exit);
      lines.insert(fi, moved.replaceFirst('  exit 1', 'exit 1'));
      expect(
        checkCiStructure(lines.join('\n')),
        _violation(['job ios', 'thiếu bước cổng', 'kiểm bundle id iOS dev']),
      );
    });
  });

  group('shell và thư mục của bước cổng', () {
    for (final (job, marker, label) in [
      ('android', 'flutter gen-l10n', 'code gen-l10n'),
      ('ios', 'Kiểm bundle id prod', 'kiểm bundle id iOS prod'),
      (
        'integration-android',
        'reactivecircus/android-emulator-runner',
        'integration test Android',
      ),
    ]) {
      for (final key in ['shell: sh', 'working-directory: pak_manager/tool']) {
        test(
          'ad19_gate_step_shell_or_dir_override_rejected: $label / $key',
          () {
            final v = checkCiStructure(_addStepKey(job, marker, key));
            expect(v, _violation(['job $job', label, '${key.split(':')[0]}:']));
          },
        );
      }
    }

    test('ad19_emulator_runner_other_working_directory_rejected', () {
      final yaml = _replaceInStep(
        'integration-android',
        'reactivecircus/android-emulator-runner',
        'working-directory: pak_manager',
        'working-directory: pak_manager/tool',
      );
      expect(
        checkCiStructure(yaml),
        _violation([
          'job integration-android',
          'thiếu bước cổng',
          'integration test Android',
        ]),
      );
    });
  });

  group('thứ tự wrapper-validation', () {
    test('ad12_wrapper_validation_after_apk_build_rejected', () {
      final yaml = _moveStepAfter(
        'android',
        'gradle/actions/wrapper-validation',
        'flutter build apk --release --flavor prod',
      );
      expect(
        checkCiStructure(yaml),
        _violation(['job android', 'trước bước gọi Gradle']),
      );
    });

    test('ad12_integration_android_always_requires_wrapper_validation', () {
      // Gỡ cả emulator runner (bước gọi Gradle) lẫn wrapper-validation.
      final lines = _ci.split('\n');
      var (s, e) = _stepRange(
        lines,
        'integration-android',
        'reactivecircus/android-emulator-runner',
      );
      lines.removeRange(s, e);
      (s, e) = _stepRange(
        lines,
        'integration-android',
        'gradle/actions/wrapper-validation',
      );
      lines.removeRange(s, e);
      expect(
        checkCiStructure(lines.join('\n')),
        _violation(['job integration-android', 'thiếu bước cổng', 'wrapper']),
      );
    });

    test('ad12_wrapper_validation_with_options_rejected', () {
      // `allow-checksums`/`min-wrapper-count` nới lỏng xác thực JAR.
      for (final job in ['android', 'integration-android']) {
        for (final opt in [
          ['        with:', '          allow-checksums: deadbeef'],
          ['        with:', '          min-wrapper-count: 0'],
          ['        with: {min-wrapper-count: 0}'],
        ]) {
          final lines = _ci.split('\n');
          final (s, e) = _stepRange(
            lines,
            job,
            'gradle/actions/wrapper-validation',
          );
          lines.insertAll(e, opt);
          final yaml = lines.join('\n');
          expect(
            checkCiStructure(yaml),
            _violation(['job $job', 'wrapper', 'with:']),
            reason: '$job ${opt.join(' ')} (bước $s)',
          );
        }
      }
    });

    test('ad12_wrapper_validation_after_emulator_runner_rejected', () {
      final yaml = _moveStepAfter(
        'integration-android',
        'gradle/actions/wrapper-validation',
        'reactivecircus/android-emulator-runner',
      );
      expect(
        checkCiStructure(yaml),
        _violation(['job integration-android', 'trước bước gọi Gradle']),
      );
    });
  });

  group('ghim action và runner', () {
    const checkout =
        'actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0';

    test('ad12_uses_by_tag_rejected', () {
      final yaml = _ci.replaceFirst(checkout, 'actions/checkout@v4');
      expect(yaml, isNot(_ci));
      expect(
        checkCiStructure(yaml),
        _violation(['actions/checkout@v4', 'SHA']),
      );
    });

    test('ad12_uses_sha_without_tag_comment_rejected', () {
      final yaml = _ci.replaceFirst(
        checkout,
        'actions/checkout@11d5960a326750d5838078e36cf38b85af677262',
      );
      expect(checkCiStructure(yaml), _violation(['actions/checkout@', 'tag']));
    });

    test('ad12_uses_short_sha_rejected', () {
      final yaml = _ci.replaceFirst(
        checkout,
        'actions/checkout@11d5960 # v4.4.0',
      );
      expect(checkCiStructure(yaml), _violation(['actions/checkout@11d5960']));
    });

    test('ad12_job_level_uses_pinned_accepted_unpinned_rejected', () {
      const sha = '0123456789abcdef0123456789abcdef01234567';
      final pinned = _addJobKey(
        'ios',
        'uses: org/repo/.github/workflows/x.yml@$sha # v1.0.0',
      );
      expect(
        checkCiStructure(pinned).where((v) => v.contains('uses')),
        isEmpty,
      );
      for (final ref in ['@v1', '@$sha']) {
        final yaml = _addJobKey(
          'ios',
          'uses: org/repo/.github/workflows/x.yml$ref',
        );
        expect(
          checkCiStructure(yaml),
          _violation(['job ios', 'uses', 'SHA']),
          reason: ref,
        );
      }
    });

    test('ad12_runs_on_latest_rejected', () {
      for (final (from, to) in [
        ('runs-on: ubuntu-24.04', 'runs-on: ubuntu-latest'),
        ('runs-on: macos-15', 'runs-on: macos-latest'),
      ]) {
        final yaml = _ci.replaceFirst(from, to);
        expect(yaml, isNot(_ci));
        expect(checkCiStructure(yaml), _violation([to.split(' ').last]));
      }
    });
  });

  group('trigger', () {
    test('ad19_missing_pull_request_trigger_rejected', () {
      final yaml = _ci.replaceFirst('  pull_request:\n', '');
      expect(yaml, isNot(_ci));
      expect(checkCiStructure(yaml), _violation(['pull_request']));
    });

    test('ad19_missing_push_trigger_rejected', () {
      final yaml = _ci.replaceFirst('  push:\n    branches: [main]\n', '');
      expect(yaml, isNot(_ci));
      expect(checkCiStructure(yaml), _violation(['trigger push']));
    });

    test('ad19_push_not_on_main_rejected', () {
      final yaml = _ci.replaceFirst('branches: [main]', 'branches: [develop]');
      expect(yaml, isNot(_ci));
      expect(checkCiStructure(yaml), _violation(['main']));
    });

    test('ad19_pull_request_narrowed_by_paths_rejected', () {
      final yaml = _ci.replaceFirst(
        '  pull_request:\n',
        "  pull_request:\n    paths: ['docs/**']\n",
      );
      expect(yaml, isNot(_ci));
      expect(checkCiStructure(yaml), _violation(['pull_request', 'paths']));
    });
  });

  test('ad19_missing_job_rejected', () {
    for (final job in _jobs) {
      final lines = _ci.split('\n');
      final (s, e) = _jobRange(lines, job);
      lines.removeRange(s, e);
      expect(
        checkCiStructure(lines.join('\n')),
        _violation(['thiếu job $job']),
        reason: job,
      );
    }
  });

  test('ad19_run_violation_returns_1', () {
    final dir = Directory.systemTemp.createTempSync('ci_structure_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/ci.yml')
      ..writeAsStringSync(
        _removeStep('android', 'dart run tool/ci/check_stack.dart'),
      );
    final out = StringBuffer();
    final err = StringBuffer();
    expect(run([file.path], out: out, err: err), 1);
    expect(err.toString(), contains('thiếu bước cổng'));
    expect(err.toString(), contains('kiểm Stack'));
    expect(out.toString(), isNot(contains('OK')));
  });

  test('ad19_run_missing_file_returns_1', () {
    final err = StringBuffer();
    expect(run(['khong-co.yml'], out: StringBuffer(), err: err), 1);
    expect(err.toString(), contains('khong-co.yml'));
  });
}
