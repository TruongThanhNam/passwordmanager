// Kiểm cấu trúc `.github/workflows/ci.yml`: bước cổng bắt buộc còn đủ, không
// bị tắt bằng `if:`/`continue-on-error`, `uses:` ghim SHA, runner không
// `*-latest`, Gradle wrapper được xác thực trước mọi bước gọi Gradle
// (AD-12, AD-18, AD-19).
//
// Dart thuần, không dependency (không dùng gói `yaml`): parser theo dòng chỉ
// nhận đúng hình dạng `ci.yml` của repo (job thụt 2, khóa job thụt 4, `- `
// bước thụt 6, khóa bước thụt 8). Bước cổng được nhận theo nội dung
// (`run`/`uses`/`with`/`env`), không theo `name`, để đổi tên bước không lọt.
//
// Chạy trong pak_manager/:
//   dart run tool/ci/ci_structure.dart [../.github/workflows/ci.yml]
// Exit 0 và in "OK" khi sạch; exit 1 khi có vi phạm (mỗi vi phạm một dòng
// stderr).

import 'dart:io';

/// Đường dẫn mặc định tới workflow, tính từ pak_manager/.
const defaultCiPath = '../.github/workflows/ci.yml';

/// Job chứa các bước cổng của ứng dụng Android.
const androidJob = 'android';

/// Job integration test Android (gọi Gradle qua emulator runner).
const integrationAndroidJob = 'integration-android';

/// Job bắt buộc phải có: xóa hay đổi tên một job sẽ làm mất các bước cổng
/// của nó (clone Flutter, xcode-select, wrapper-validation).
const requiredJobs = [
  androidJob,
  'ios',
  integrationAndroidJob,
  'integration-ios',
];

const _prodId = 'io.github.truongthanhnam.pakmanager';
const _devId = 'io.github.truongthanhnam.pakmanager.dev';

/// Một bước trong job, giữ dòng bắt đầu (đếm từ 1).
class CiStep {
  CiStep(this.line);

  /// Dòng của `- ` mở bước.
  final int line;

  /// Khóa cấp bước -> giá trị (đã bỏ comment cuối dòng và dấu nháy).
  final Map<String, String> keys = {};

  /// Giá trị thô của `uses:` (giữ comment cuối dòng để kiểm tag).
  String? usesRaw;

  /// Nội dung `run` (inline hoặc khối `|`), mỗi phần tử một dòng.
  final List<String> runLines = [];

  /// Con của `with:` và `env:` cấp bước.
  final Map<String, String> withMap = {};
  final Map<String, String> envMap = {};

  String? get uses => keys['uses'];

  /// Dòng `run` không phải comment shell.
  Iterable<String> get commandLines => runLines
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'));

  /// Toàn bộ văn bản lệnh của bước (`run` và các giá trị `with`).
  String get commandText => [...commandLines, ...withMap.values].join('\n');

  String get label => keys['name'] ?? uses ?? 'bước';
}

/// Một job, giữ dòng bắt đầu và các khóa cấp job.
class CiJob {
  CiJob(this.id, this.line);

  final String id;
  final int line;
  final Map<String, String> keys = {};
  final List<CiStep> steps = [];

  /// Giá trị thô của `uses:` cấp job (giữ comment cuối dòng để kiểm tag).
  String? usesRaw;

  /// Dòng của khóa cấp job (để báo vi phạm).
  final Map<String, int> keyLines = {};
}

/// Kết quả parse: trigger và job theo thứ tự xuất hiện.
class CiWorkflow {
  /// Trigger -> các dòng con (đã trim) của nó.
  final Map<String, List<String>> triggers = {};
  final List<CiJob> jobs = [];

  CiJob? job(String id) {
    for (final j in jobs) {
      if (j.id == id) {
        return j;
      }
    }
    return null;
  }
}

int _indent(String line) => line.length - line.trimLeft().length;

/// Bỏ comment YAML cuối dòng (chỉ khi giá trị không mở bằng dấu nháy).
String _stripComment(String value) {
  final t = value.trim();
  if (t.startsWith('"') || t.startsWith("'")) {
    return t;
  }
  final i = t.indexOf(' #');
  return (i >= 0 ? t.substring(0, i) : t).trim();
}

String _unquote(String v) {
  final t = v.trim();
  if (t.length >= 2 &&
      ((t.startsWith('"') && t.endsWith('"')) ||
          (t.startsWith("'") && t.endsWith("'")))) {
    return t.substring(1, t.length - 1);
  }
  return t;
}

bool _isBlockScalar(String value) => RegExp(r'^[|>][-+]?$').hasMatch(value);

/// Tách `key: value`; trả null nếu dòng không phải cặp khóa.
({String key, String value})? _pair(String text) {
  final m = RegExp(r'''^(["']?[A-Za-z0-9_.-]+["']?)\s*:(?:\s+(.*))?$''')
      .firstMatch(text.trim());
  if (m == null) {
    return null;
  }
  return (key: _unquote(m.group(1)!), value: (m.group(2) ?? '').trim());
}

/// Parse [yaml] theo dòng thành trigger, job và bước.
CiWorkflow parseCiWorkflow(String yaml) {
  final wf = CiWorkflow();
  final lines = yaml.replaceAll('\r', '').split('\n');
  String? top;
  String? trigger;
  CiJob? job;
  var inSteps = false;
  var stepIndent = -1;
  CiStep? step;
  // Khối đang đọc trong bước: 'run' (khối `|`), 'with', 'env', hoặc khóa
  // khác bị bỏ qua.
  String? block;
  var blockIndent = -1;
  String? lastChildKey;
  Map<String, String>? childMap;

  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final trimmed = raw.trim();
    final indent = _indent(raw);

    // Nội dung khối con của bước (giữ cả dòng trống và comment shell).
    if (step != null && block != null) {
      if (trimmed.isEmpty) {
        if (block == 'run') {
          step.runLines.add('');
        }
        continue;
      }
      if (indent > blockIndent) {
        if (block == 'run') {
          step.runLines.add(raw);
        } else if (childMap != null) {
          final p = _pair(raw);
          final childIndent = blockIndent + 2;
          if (indent == childIndent && p != null && !trimmed.startsWith('#')) {
            lastChildKey = p.key;
            childMap[p.key] = _isBlockScalar(p.value)
                ? ''
                : _unquote(_stripComment(p.value));
          } else if (lastChildKey != null) {
            // Dòng tiếp của giá trị khối (vd `script: |`).
            childMap[lastChildKey] = '${childMap[lastChildKey]}\n$trimmed'
                .trim();
          }
        }
        continue;
      }
      block = null;
      childMap = null;
      lastChildKey = null;
    }

    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }

    if (indent == 0) {
      final p = _pair(raw);
      top = p?.key;
      trigger = null;
      job = null;
      step = null;
      inSteps = false;
      if (top == 'on' && p != null && p.value.isNotEmpty) {
        // Dạng inline: `on: [pull_request, push]` hoặc `on: push`.
        final v = _stripComment(p.value).replaceAll(RegExp(r'[\[\]]'), '');
        for (final t in v.split(',')) {
          if (t.trim().isNotEmpty) {
            wf.triggers[t.trim()] = [];
          }
        }
      }
      continue;
    }

    if (top == 'on') {
      if (indent == 2) {
        final p = _pair(raw);
        trigger = p?.key ?? trimmed.replaceFirst(RegExp(r'^-\s*'), '');
        wf.triggers[trigger] = [];
        if (p != null && p.value.isNotEmpty) {
          wf.triggers[trigger]!.add(_stripComment(p.value));
        }
      } else if (trigger != null) {
        wf.triggers[trigger]!.add(_stripComment(trimmed));
      }
      continue;
    }

    if (top != 'jobs') {
      continue;
    }

    if (indent == 2) {
      final p = _pair(raw);
      if (p != null) {
        job = CiJob(p.key, i + 1);
        wf.jobs.add(job);
      }
      step = null;
      inSteps = false;
      stepIndent = -1;
      continue;
    }
    if (job == null) {
      continue;
    }

    if (indent == 4) {
      final p = _pair(raw);
      step = null;
      inSteps = p?.key == 'steps';
      stepIndent = -1;
      if (p != null) {
        job.keys[p.key] = _unquote(_stripComment(p.value));
        job.keyLines[p.key] = i + 1;
        if (p.key == 'uses') {
          job.usesRaw = p.value;
        }
      }
      continue;
    }

    if (!inSteps) {
      continue;
    }

    var text = trimmed;
    var keyIndent = indent;
    if (trimmed.startsWith('- ') || trimmed == '-') {
      if (stepIndent < 0) {
        stepIndent = indent;
      }
      if (indent == stepIndent) {
        step = CiStep(i + 1);
        job.steps.add(step);
        text = trimmed.substring(1).trim();
        keyIndent = indent + 2;
        if (text.isEmpty) {
          continue;
        }
      }
    }
    if (step == null || keyIndent != stepIndent + 2) {
      continue;
    }
    final p = _pair(text);
    if (p == null) {
      continue;
    }
    switch (p.key) {
      case 'run':
        if (_isBlockScalar(p.value)) {
          block = 'run';
          blockIndent = keyIndent;
        } else {
          step.runLines.add(_unquote(_stripComment(p.value)));
        }
      case 'with':
      case 'env':
        // Ghi nhận khóa cả khi giá trị inline (vd `with: {a: b}`).
        step.keys[p.key] = p.value;
        if (p.value.isEmpty) {
          block = p.key;
          blockIndent = keyIndent;
          childMap = p.key == 'with' ? step.withMap : step.envMap;
          lastChildKey = null;
        }
      default:
        if (p.key == 'uses') {
          step.usesRaw = p.value;
        }
        if (_isBlockScalar(p.value)) {
          // Khóa khác có giá trị khối: bỏ qua nội dung nhưng vẫn ghi nhận
          // khóa (vd `if: >-` phải bị coi là có điều kiện).
          step.keys[p.key] = p.value;
          block = 'skip';
          blockIndent = keyIndent;
          childMap = null;
        } else {
          step.keys[p.key] = _unquote(_stripComment(p.value));
        }
    }
  }
  return wf;
}

/// Bước cổng: [label] dùng trong thông báo, [matches] nhận bước theo nội
/// dung, [allowedIf] là giá trị `if:` duy nhất được phép (null = cấm `if:`),
/// [allowWith] = false khi `with:` có thể nới lỏng cổng (vd `allow-checksums`
/// của wrapper-validation).
class _Gate {
  const _Gate(
    this.label,
    this.matches, {
    this.allowedIf,
    this.allowWith = true,
  });
  final String label;
  final bool Function(CiStep) matches;
  final String? allowedIf;
  final bool allowWith;
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
      ].map(_unquote).map((b) => b.trim());
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
      ]);
    }
    if (_mentionsFlutter(job)) {
      gates.add(_flutterCloneGate);
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
      final matched = job.steps.where(gate.matches).toList();
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
