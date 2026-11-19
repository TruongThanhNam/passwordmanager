// Parser YAML dùng chung cho các cổng trong tool/ci/ (retro Epic 1, C1): mô
// hình `ci.yml` (`CiWorkflow`, `CiJob`, `CiStep`) và hai hàm dòng
// `stripComment`/`unquote`.
//
// Dart thuần, không dependency (không dùng gói `yaml`): parser theo dòng chỉ
// nhận đúng hình dạng `ci.yml` của repo (job thụt 2, khóa job thụt 4, `- `
// bước thụt 6, khóa bước thụt 8).

/// Ký tự đứng trước một dấu nháy mở chuỗi.
final _quoteBoundary = RegExp(r'[\s:\[{,]');
final _whitespace = RegExp(r'\s');

/// Bỏ comment YAML khỏi [line]: phần từ `#` đứng đầu dòng (sau thụt) hoặc
/// đứng sau khoảng trắng, nằm ngoài nháy đơn/kép. Giữ thụt đầu dòng, bỏ
/// khoảng trắng cuối.
///
/// Dấu nháy chỉ mở chuỗi khi đứng đầu dòng hoặc sau khoảng trắng, `:`, `[`,
/// `{`, `,` (vd `don't # x` vẫn bỏ comment). Trong nháy kép, `\` thoát ký tự
/// kế tiếp; trong nháy đơn, `''` là một dấu nháy.
String stripComment(String line) {
  String? quote;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (quote != null) {
      if (quote == '"' && c == r'\') {
        i++;
      } else if (quote == "'" &&
          c == "'" &&
          i + 1 < line.length &&
          line[i + 1] == "'") {
        i++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    final prev = i == 0 ? ' ' : line[i - 1];
    final atBoundary = _quoteBoundary.hasMatch(prev);
    if ((c == '"' || c == "'") && atBoundary) {
      quote = c;
    } else if (c == '#' && _whitespace.hasMatch(prev)) {
      return line.substring(0, i).trimRight();
    }
  }
  return line.trimRight();
}

/// Bỏ một cặp nháy đơn hoặc kép bao quanh [v] (sau khi trim).
String unquote(String v) {
  final t = v.trim();
  if (t.length >= 2 &&
      ((t.startsWith('"') && t.endsWith('"')) ||
          (t.startsWith("'") && t.endsWith("'")))) {
    return t.substring(1, t.length - 1);
  }
  return t;
}

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

/// Giá trị inline: bỏ comment cuối dòng rồi bỏ nháy.
String _value(String v) => unquote(stripComment(v.trim()));

bool _isBlockScalar(String value) => RegExp(r'^[|>][-+]?$').hasMatch(value);

/// Tách `key: value`; trả null nếu dòng không phải cặp khóa.
({String key, String value})? _pair(String text) {
  final m = RegExp(r'''^(["']?[A-Za-z0-9_.-]+["']?)\s*:(?:\s+(.*))?$''')
      .firstMatch(text.trim());
  if (m == null) {
    return null;
  }
  return (key: unquote(m.group(1)!), value: (m.group(2) ?? '').trim());
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
            childMap[p.key] = _isBlockScalar(p.value) ? '' : _value(p.value);
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
        final v = stripComment(p.value).replaceAll(RegExp(r'[\[\]]'), '');
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
          wf.triggers[trigger]!.add(stripComment(p.value));
        }
      } else if (trigger != null) {
        wf.triggers[trigger]!.add(stripComment(trimmed));
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
        job.keys[p.key] = _value(p.value);
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
          step.runLines.add(_value(p.value));
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
          step.keys[p.key] = _value(p.value);
        }
    }
  }
  return wf;
}
