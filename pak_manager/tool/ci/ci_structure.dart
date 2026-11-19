// Kiểm cấu trúc `.github/workflows/ci.yml`: bước cổng bắt buộc còn đủ, không
// bị tắt bằng `if:`/`continue-on-error`, `uses:` ghim SHA, runner không
// `*-latest`, Gradle wrapper được xác thực trước mọi bước gọi Gradle
// (AD-12, AD-18, AD-19).
//
// Dart thuần, không dependency. Parser theo dòng nằm ở `ci_yaml.dart` (dùng
// chung với check_stack.dart) và được export lại từ đây. Bước cổng được nhận
// theo nội dung (`run`/`uses`/`with`/`env`), không theo `name`, để đổi tên
// bước không lọt; lệnh cổng phải khớp nguyên dòng.
//
// Chạy trong pak_manager/:
//   dart run tool/ci/ci_structure.dart [../.github/workflows/ci.yml]
// Exit 0 và in "OK" khi sạch; exit 1 khi có vi phạm (mỗi vi phạm một dòng
// stderr).

import 'dart:io';

import 'ci_yaml.dart';

export 'ci_yaml.dart';

/// Đường dẫn mặc định tới workflow, tính từ pak_manager/.
const defaultCiPath = '../.github/workflows/ci.yml';

/// Job chứa các bước cổng của ứng dụng Android.
const androidJob = 'android';

/// Job build iOS (không codesign).
const iosJob = 'ios';

/// Job integration test Android (gọi Gradle qua emulator runner).
const integrationAndroidJob = 'integration-android';

/// Job bắt buộc phải có: xóa hay đổi tên một job sẽ làm mất các bước cổng
/// của nó (clone Flutter, xcode-select, wrapper-validation).
const requiredJobs = [
  androidJob,
  iosJob,
  integrationAndroidJob,
  integrationIosJob,
];

const _prodId = 'io.github.truongthanhnam.pakmanager';
const _devId = 'io.github.truongthanhnam.pakmanager.dev';
const _prodName = 'PAK Manager';
const _devName = 'PAK Manager Dev';

/// Job integration test iOS (simulator).
const integrationIosJob = 'integration-ios';

/// Bước cổng: [label] dùng trong thông báo, [matches] nhận bước theo nội
/// dung, [inJob] (nếu có) đòi thêm điều kiện theo vị trí bước trong job,
/// [allowedIf] là giá trị `if:` duy nhất được phép (null = cấm `if:`),
/// [allowWith] = false khi `with:` có thể nới lỏng cổng (vd `allow-checksums`
/// của wrapper-validation).
class _Gate {
  const _Gate(
    this.label,
    this.matches, {
    this.inJob,
    this.allowedIf,
    this.allowWith = true,
  });
  final String label;
  final bool Function(CiStep) matches;
  final bool Function(List<CiStep> steps, int index)? inJob;
  final String? allowedIf;
  final bool allowWith;

  /// Các bước của [steps] khớp cổng.
  List<CiStep> matchedIn(List<CiStep> steps) => [
    for (var i = 0; i < steps.length; i++)
      if (matches(steps[i]) && (inJob == null || inJob!(steps, i))) steps[i],
  ];
}

bool _usesAction(CiStep s, String action) =>
    (s.uses ?? '').startsWith('$action@');

bool _hasExpectId(String line, String id) =>
    RegExp('--expect-id\\s+${RegExp.escape(id)}(\\s|\$)').hasMatch(line);

/// Cả dòng là một lệnh gọi script kiểm APK (không có `|| true`, `; …`).
final _apkLineRe = RegExp(
  r'^bash tool/ci/check_android_apk\.sh\s+\S+\.apk'
  r'(\s+--(expect-id|save-raw)\s+[A-Za-z0-9_./-]+)+\s*$',
);

bool _isApkCheck(CiStep s, String id) => s.commandLines.any(
  (l) =>
      _apkLineRe.hasMatch(l) &&
      _hasExpectId(l, id) &&
      RegExp(r'--save-raw\s+\S').hasMatch(l),
);

/// `flutter test` toàn bộ: đúng `flutter test`, không tham số (cờ như
/// `--name`, `--tags`, `--total-shards` hay đường dẫn đều thu hẹp lần chạy).
bool _isFullFlutterTest(String line) => line == 'flutter test';

final _secretGate = _Gate(
  'kiểm secret trên ci.yml (check_workflow_secrets.dart ../.github/workflows/ci.yml)',
  (s) => s.commandLines.any(
    (l) => RegExp(
      r'^dart run tool/ci/check_workflow_secret(s|\[s\])\.dart\s+'
      r'\.\./\.github/workflows/ci\.yml\s*$',
    ).hasMatch(l),
  ),
);

final _stackGate = _Gate(
  'kiểm Stack (dart run tool/ci/check_stack.dart)',
  (s) => s.commandLines.any(
    (l) => RegExp(r'^dart run tool/ci/check_stack\.dart\s*$').hasMatch(l),
  ),
);

final _structureGate = _Gate(
  'kiểm cấu trúc ci.yml (dart run tool/ci/ci_structure.dart)',
  (s) => s.commandLines.any(
    (l) => RegExp(r'^dart run tool/ci/ci_structure\.dart\s*$').hasMatch(l),
  ),
);

final _testGate = _Gate(
  "flutter test với PAK_REQUIRE_SHELL_TESTS: '1'",
  (s) =>
      s.commandLines.any(_isFullFlutterTest) &&
      s.envMap['PAK_REQUIRE_SHELL_TESTS'] == '1',
);

final _apkProdGate = _Gate(
  'kiểm APK prod (check_android_apk.sh --expect-id $_prodId --save-raw)',
  (s) => _isApkCheck(s, _prodId),
);

final _apkDevGate = _Gate(
  'kiểm APK dev (check_android_apk.sh --expect-id $_devId --save-raw)',
  (s) => _isApkCheck(s, _devId),
);

final _uploadGate = _Gate(
  'upload artifact apk-raw-output',
  (s) =>
      _usesAction(s, 'actions/upload-artifact') &&
      s.withMap['name'] == 'apk-raw-output' &&
      s.withMap['path'] == 'pak_manager/build/apk-raw',
  allowedIf: r'${{ !cancelled() }}',
);

final _wrapperGate = _Gate(
  'xác thực Gradle wrapper (gradle/actions/wrapper-validation)',
  (s) => _usesAction(s, 'gradle/actions/wrapper-validation'),
  allowWith: false,
);

final _flutterCloneGate = _Gate(
  'clone Flutter rồi chạy check_flutter_revision.sh',
  (s) => _cloneThenRevision(s.commandLines.toList()),
);

final _xcodeGate = _Gate(
  'chọn Xcode bằng xcode-select -s …/Xcode_<phiên bản>.app',
  (s) => s.commandLines.any(
    (l) => RegExp(
      r'^(sudo\s+)?xcode-select\s+-s\s+\S*/Xcode_[0-9][0-9.]*\.app\s*$',
    ).hasMatch(l),
  ),
);

/// Bước có một dòng lệnh đúng nguyên văn [command] (sau trim). Thêm hậu tố
/// như `|| true` hay `; true` thì không còn khớp.
bool _hasLine(CiStep s, String command) => s.commandLines.contains(command);

final _pubGetGate = _Gate(
  'pub get theo lockfile (flutter pub get --enforce-lockfile)',
  (s) => _hasLine(s, 'flutter pub get --enforce-lockfile'),
);

final _importsGate = _Gate(
  'luật import (dart run tool/check_imports.dart)',
  (s) => _hasLine(s, 'dart run tool/check_imports.dart'),
);

final _analyzeGate = _Gate(
  'phân tích tĩnh (flutter analyze --fatal-infos --fatal-warnings)',
  (s) => _hasLine(s, 'flutter analyze --fatal-infos --fatal-warnings'),
);

/// Từ dòng [from], tìm lần lượt [assign] rồi [cond] (một `if … then`), và
/// một dòng `exit 1` trước dòng `fi` kế tiếp; trả chỉ số dòng sau `exit 1`,
/// hoặc -1 khi thiếu.
int _guardedExit(List<String> lines, int from, String assign, String cond) {
  if (from < 0) {
    return -1;
  }
  final a = lines.indexOf(assign, from);
  if (a < 0) {
    return -1;
  }
  final c = lines.indexOf(cond, a + 1);
  if (c < 0) {
    return -1;
  }
  for (var i = c + 1; i < lines.length && lines[i] != 'fi'; i++) {
    if (lines[i] == 'exit 1') {
      return i + 1;
    }
  }
  return -1;
}

/// Cổng "sinh lại rồi so": [generate], rồi `git status --porcelain` trên
/// [paths], rồi `exit 1` khi có thay đổi.
_Gate _regenGate(String label, String generate, String paths) =>
    _Gate('$label ($generate rồi git status --porcelain -- $paths)', (s) {
      final lines = s.commandLines.toList();
      final gen = lines.indexOf(generate);
      return _guardedExit(
            lines,
            gen < 0 ? -1 : gen + 1,
            'changes="\$(git status --porcelain -- $paths)"',
            r'if [[ -n "$changes" ]]; then',
          ) >=
          0;
    });

final _l10nGate = _regenGate(
  'code gen-l10n đã cập nhật',
  'flutter gen-l10n',
  'lib/l10n',
);

final _pigeonGate = _regenGate(
  'code Pigeon đã cập nhật',
  'dart run pigeon --input pigeons/platform_api.dart',
  'lib android ios',
);

final _fixtureGate = _regenGate(
  'fixture vault khớp script',
  'dart run tool/fixtures/gen_vault_v1.dart',
  'test/fixtures/vault',
);

final _integrationAndroidGate = _Gate(
  'integration test Android (emulator runner với script: '
  'flutter test integration_test --flavor dev)',
  (s) =>
      _usesAction(s, 'reactivecircus/android-emulator-runner') &&
      s.withMap['script'] == 'flutter test integration_test --flavor dev' &&
      s.withMap['working-directory'] == 'pak_manager',
);

final _integrationIosGate = _Gate(
  r'integration test iOS (flutter test integration_test -d "$SIM_UDID")',
  (s) => _hasLine(s, r'flutter test integration_test -d "$SIM_UDID"'),
);

/// Dòng `flutter build ios` bất kỳ (kể cả bị thêm cờ hay hậu tố).
final _iosBuildRe = RegExp(r'(^|[\s;&|(])flutter\s+build\s+ios(\s|$)');

/// Dòng build iOS cuối cùng của bước, hoặc null.
String? _lastIosBuild(CiStep s) =>
    s.commandLines.where(_iosBuildRe.hasMatch).lastOrNull;

/// Lệnh build iOS chuẩn, không cờ khi [flavor] null.
String _iosBuildLine(String? flavor) =>
    'flutter build ios --release --no-codesign'
    '${flavor == null ? '' : ' --flavor $flavor'}'
    r' --build-number "$GITHUB_RUN_NUMBER"';

_Gate _iosBuildGate(String? flavor) => _Gate(
  'build iOS ${flavor ?? 'không cờ'} (${_iosBuildLine(flavor)})',
  (s) => _lastIosBuild(s) == _iosBuildLine(flavor),
);

const _plist = 'build/ios/iphoneos/Runner.app/Info.plist';

/// Bước kiểm plist của build iOS [flavor]: đọc `CFBundleIdentifier` và
/// `CFBundleDisplayName` bằng PlistBuddy, so đúng [id] và [name], `exit 1`
/// khi sai. Bước build iOS gần nhất đứng trước nó phải là build [flavor]: nếu
/// không, bước kiểm đọc plist của một build khác.
_Gate _iosCheckGate(String? flavor, String id, String name) => _Gate(
  'kiểm bundle id iOS ${flavor ?? 'không cờ'} '
  '(PlistBuddy CFBundleIdentifier = $id, CFBundleDisplayName = $name, '
  'sau build iOS ${flavor ?? 'không cờ'})',
  (s) {
    if (_lastIosBuild(s) != null) {
      return false;
    }
    final lines = s.commandLines.toList();
    final afterId = _guardedExit(
      lines,
      0,
      'actual="\$(/usr/libexec/PlistBuddy -c \'Print :CFBundleIdentifier\' '
          '$_plist)"',
      'if [[ "\$actual" != "$id" ]]; then',
    );
    return _guardedExit(
          lines,
          afterId,
          'name="\$(/usr/libexec/PlistBuddy -c \'Print :CFBundleDisplayName\' '
              '$_plist)"',
          'if [[ "\$name" != "$name" ]]; then',
        ) >=
        0;
  },
  inJob: (steps, i) {
    for (var j = i - 1; j >= 0; j--) {
      final build = _lastIosBuild(steps[j]);
      if (build != null) {
        return build == _iosBuildLine(flavor);
      }
    }
    return false;
  },
);

final _iosBuildPlainGate = _iosBuildGate(null);
final _iosBuildProdGate = _iosBuildGate('prod');
final _iosBuildDevGate = _iosBuildGate('dev');
final _iosCheckPlainGate = _iosCheckGate(null, _prodId, _prodName);
final _iosCheckProdGate = _iosCheckGate('prod', _prodId, _prodName);
final _iosCheckDevGate = _iosCheckGate('dev', _devId, _devName);

final _cloneRe = RegExp(
  r'git clone\b.*--branch\s+"\$FLUTTER_VERSION"\s.*flutter/flutter\.git',
);
final _revisionRe = RegExp(
  r'^bash tool/ci/check_flutter_revision\.sh\s+"\$RUNNER_TEMP/flutter"\s*$',
);

/// Bước có dòng clone Flutter và, sau nó, dòng gọi script so revision.
bool _cloneThenRevision(List<String> lines) {
  final clone = lines.indexWhere(_cloneRe.hasMatch);
  return clone >= 0 && lines.skip(clone + 1).any(_revisionRe.hasMatch);
}

/// Bước gọi Gradle: build APK/AAB, `gradlew`, hoặc emulator runner.
bool _callsGradle(CiStep s) =>
    _usesAction(s, 'reactivecircus/android-emulator-runner') ||
    s.commandLines.any(
      (l) =>
          RegExp(r'flutter build (apk|appbundle)(\s|$)').hasMatch(l) ||
          RegExp(r'(^|[\s/])gradlew(\.bat)?(\s|$)').hasMatch(l),
    );

/// Job nhắc tới flutter trong lệnh, `with:` hoặc `uses:` (vd
/// `subosito/flutter-action`).
bool _mentionsFlutter(CiJob job) => job.steps.any(
  (s) => RegExp(r'\bflutter\b').hasMatch('${s.commandText}\n${s.uses ?? ''}'),
);

final _pinnedUses = RegExp(r'^[^@\s]+@[0-9a-f]{40}\s+#\s*\S+');

/// Kiểm cấu trúc [yaml]; trả vi phạm (rỗng khi sạch).
List<String> checkCiStructure(String yaml) {
  final violations = <String>[];
  final wf = parseCiWorkflow(yaml);

  // Trigger: mọi PR và push lên main.
  if (!wf.triggers.containsKey('pull_request')) {
    violations.add('ci.yml: thiếu trigger pull_request (AD-19)');
  }
  final push = wf.triggers['push'];
  if (push == null) {
    violations.add('ci.yml: thiếu trigger push (AD-19)');
  } else {
    final branchLine = push.indexWhere((l) => l.startsWith('branches:'));
    if (branchLine >= 0) {
      final inline = push[branchLine].substring('branches:'.length);
      final items = [
        ...inline.replaceAll(RegExp(r'[\[\]]'), '').split(','),
        ...push
            .skip(branchLine + 1)
            .takeWhile((l) => l.startsWith('- '))
            .map((l) => l.substring(2)),
      ].map(unquote).map((b) => b.trim());
      if (!items.contains('main')) {
        violations.add('ci.yml: trigger push không gồm nhánh main (AD-19)');
      }
    }
  }
  for (final name in ['pull_request', 'push']) {
    for (final l in wf.triggers[name] ?? const <String>[]) {
      final key = l.split(':').first.trim();
      final narrows = {'paths', 'paths-ignore', 'branches-ignore'};
      if (narrows.contains(key) ||
          (name == 'pull_request' && key == 'branches')) {
        violations.add('ci.yml: trigger $name bị thu hẹp bằng "$key" (AD-19)');
      }
    }
  }

  if (wf.jobs.isEmpty) {
    violations.add('ci.yml: không đọc được job nào');
    return violations;
  }
  for (final id in requiredJobs) {
    if (wf.job(id) == null) {
      violations.add('ci.yml: thiếu job $id');
    }
  }

  for (final job in wf.jobs) {
    final where = 'job ${job.id}';
    final runsOn = job.keys['runs-on'] ?? '';
    if (runsOn.contains('-latest')) {
      violations.add(
        'dòng ${job.keyLines['runs-on']}: $where dùng runs-on "$runsOn", '
        'phải ghim phiên bản runner (AD-12)',
      );
    }
    final jobUses = job.usesRaw;
    if (jobUses != null && !_pinnedUses.hasMatch(jobUses)) {
      violations.add(
        'dòng ${job.keyLines['uses']}: $where uses "$jobUses" phải ghim SHA '
        '40 hex kèm comment tag (AD-12)',
      );
    }
    for (final s in job.steps) {
      final raw = s.usesRaw;
      if (raw != null && !_pinnedUses.hasMatch(raw)) {
        violations.add(
          'dòng ${s.line}: $where uses "$raw" phải ghim SHA 40 hex kèm '
          'comment tag (AD-12)',
        );
      }
    }

    // Cổng áp cho job này.
    final gates = <_Gate>[];
    if (job.id == androidJob) {
      gates.addAll([
        _secretGate,
        _stackGate,
        _structureGate,
        _testGate,
        _apkProdGate,
        _apkDevGate,
        _uploadGate,
        _wrapperGate,
        _importsGate,
        _analyzeGate,
        _l10nGate,
        _pigeonGate,
        _fixtureGate,
      ]);
    }
    if (job.id == iosJob) {
      gates.addAll([
        _iosBuildPlainGate,
        _iosCheckPlainGate,
        _iosBuildProdGate,
        _iosCheckProdGate,
        _iosBuildDevGate,
        _iosCheckDevGate,
      ]);
    }
    if (job.id == integrationAndroidJob) {
      gates.add(_integrationAndroidGate);
    }
    if (job.id == integrationIosJob) {
      gates.add(_integrationIosGate);
    }
    if (_mentionsFlutter(job)) {
      gates.addAll([_flutterCloneGate, _pubGetGate]);
    }
    if (runsOn.startsWith('macos')) {
      gates.add(_xcodeGate);
    }
    final gradleIdx = job.steps.indexWhere(_callsGradle);
    // Mọi job build Android (spec: `android`, `integration-android`) luôn
    // phải xác thực wrapper, kể cả khi không nhận ra bước gọi Gradle.
    if ((gradleIdx >= 0 || job.id == integrationAndroidJob) &&
        !gates.contains(_wrapperGate)) {
      gates.add(_wrapperGate);
    }

    for (final gate in gates) {
      final matched = gate.matchedIn(job.steps);
      if (matched.isEmpty) {
        violations.add('$where: thiếu bước cổng ${gate.label}');
        continue;
      }
      for (final s in matched) {
        final cond = s.keys['if'];
        if (cond != null && cond != gate.allowedIf) {
          violations.add(
            'dòng ${s.line}: $where bước cổng ${gate.label} có '
            '"if: $cond" làm nó có thể bị bỏ qua',
          );
        }
        final coe = s.keys['continue-on-error'];
        if (coe != null && coe != 'false') {
          violations.add(
            'dòng ${s.line}: $where bước cổng ${gate.label} có '
            '"continue-on-error: $coe"',
          );
        }
        for (final key in ['shell', 'working-directory']) {
          if (s.keys.containsKey(key)) {
            violations.add(
              'dòng ${s.line}: $where bước cổng ${gate.label} không được có '
              '"$key:" (đổi shell hay thư mục làm lệnh cổng chạy khác)',
            );
          }
        }
        if (!gate.allowWith && s.keys.containsKey('with')) {
          violations.add(
            'dòng ${s.line}: $where bước cổng ${gate.label} không được có '
            '"with:" (có thể nới lỏng kiểm tra)',
          );
        }
      }
    }

    if (gradleIdx >= 0) {
      final wrapperIdx = job.steps.indexWhere(_wrapperGate.matches);
      if (wrapperIdx > gradleIdx) {
        violations.add(
          'dòng ${job.steps[wrapperIdx].line}: $where xác thực Gradle wrapper '
          'phải đứng trước bước gọi Gradle đầu tiên '
          '(dòng ${job.steps[gradleIdx].line})',
        );
      }
    }

    if (gates.isNotEmpty) {
      final cond = job.keys['if'];
      if (cond != null) {
        violations.add(
          'dòng ${job.keyLines['if']}: $where chứa bước cổng nhưng có '
          '"if: $cond"',
        );
      }
      final coe = job.keys['continue-on-error'];
      if (coe != null && coe != 'false') {
        violations.add(
          'dòng ${job.keyLines['continue-on-error']}: $where chứa bước cổng '
          'nhưng có "continue-on-error: $coe"',
        );
      }
    }
  }
  return violations;
}

/// [args] = `[workflowPath]` (mặc định [defaultCiPath]); trả exit code.
int run(List<String> args, {StringSink? out, StringSink? err}) {
  final output = out ?? stdout;
  final errors = err ?? stderr;
  final path = args.isNotEmpty ? args[0] : defaultCiPath;
  final file = File(path);
  if (!file.existsSync()) {
    errors.writeln('không đọc được $path');
    return 1;
  }
  final violations = checkCiStructure(file.readAsStringSync());
  if (violations.isEmpty) {
    output.writeln('OK');
    return 0;
  }
  for (final v in violations) {
    errors.writeln(v);
  }
  return 1;
}

void main(List<String> args) {
  exitCode = run(args);
}
