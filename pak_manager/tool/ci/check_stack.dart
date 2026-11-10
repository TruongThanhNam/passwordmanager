// Kiểm dependency khớp bảng Stack của ARCHITECTURE-SPINE (AD-12, AD-18).
//
// Dart thuần, không dependency. Chạy trong pak_manager/:
//   dart run tool/ci/check_stack.dart [pubspecDir] [spinePath]
// Exit 0 và in "OK" khi sạch; exit 1 khi có vi phạm (in mỗi vi phạm một dòng
// ra stderr).

import 'dart:io';

/// Đường dẫn mặc định tới spine, tính từ pak_manager/.
const defaultSpinePath =
    '../_bmad-output/planning-artifacts/architecture/'
    'architecture-passwordmanager-2026-10-27/ARCHITECTURE-SPINE.md';

/// Đường dẫn allowlist gói kéo theo, tính từ thư mục pubspec.
const allowlistRelPath = 'tool/ci/transitive_allowlist.txt';

/// Đọc bảng `## Stack` thành map tên -> phiên bản (token đầu cột Version).
/// Trả `null` khi không có mục `## Stack` hoặc bảng rỗng.
Map<String, String>? parseStackTable(String spine) {
  final lines = spine.split('\n');
  final start = lines.indexWhere((l) => l.trim() == '## Stack');
  if (start < 0) {
    return null;
  }
  final result = <String, String>{};
  for (var i = start + 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.startsWith('#')) {
      break;
    }
    if (!line.startsWith('|')) {
      continue;
    }
    final cells = line.split('|').map((c) => c.trim()).toList();
    // `| a | b |` -> ['', 'a', 'b', ''].
    if (cells.length < 4) {
      continue;
    }
    final nameCell = cells[1];
    final versionCell = cells[2];
    if (nameCell == 'Name' || RegExp(r'^-+$').hasMatch(nameCell)) {
      continue;
    }
    final version = versionCell.split(RegExp(r'\s+')).first;
    final noParen = nameCell.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    for (final part in noParen.split(RegExp(r'[/,]'))) {
      final tokens = part.trim().split(RegExp(r'\s+'));
      if (tokens.first.isNotEmpty) {
        result[tokens.first] = version;
      }
    }
  }
  return result.isEmpty ? null : result;
}

/// Một dependency khai báo trong pubspec.yaml.
class _Dep {
  _Dep(this.name, this.section);
  final String name;
  final String section;
  String? inlineValue;
  final List<String> children = [];
}

int _indent(String line) => line.length - line.trimLeft().length;

String _stripComment(String line) {
  final i = line.indexOf(' #');
  final s = line.trimLeft().startsWith('#')
      ? ''
      : (i >= 0 ? line.substring(0, i) : line);
  return s.trimRight();
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

/// [nested] nhận các mục có dòng lồng; [topKeys] nhận mọi khóa cấp 0.
List<_Dep> _parsePubspecDeps(
  String pubspec,
  Set<String> nested,
  Set<String> topKeys,
) {
  final deps = <_Dep>[];
  String? section;
  _Dep? current;
  for (final raw in pubspec.split('\n')) {
    final line = _stripComment(raw.replaceAll('\r', ''));
    if (line.trim().isEmpty) {
      continue;
    }
    final indent = _indent(line);
    if (indent == 0) {
      final key = line.split(':').first.trim();
      topKeys.add(key);
      section = (key == 'dependencies' || key == 'dev_dependencies')
          ? key
          : null;
      current = null;
      continue;
    }
    if (section == null) {
      continue;
    }
    nested.add(section);
    if (indent == 2) {
      final colon = line.indexOf(':');
      if (colon < 0) {
        continue;
      }
      current = _Dep(line.substring(0, colon).trim(), section);
      final value = line.substring(colon + 1).trim();
      current.inlineValue = value.isEmpty ? null : _unquote(value);
      deps.add(current);
    } else if (current != null) {
      current.children.add(line.trim());
    }
  }
  return deps;
}

/// Gói trong pubspec.lock: tên -> (dependency, source, version).
Map<String, ({String dependency, String source, String version})> _parseLock(
  String lock,
) {
  final result =
      <String, ({String dependency, String source, String version})>{};
  var inPackages = false;
  String? name;
  var dependency = '';
  var source = '';
  var version = '';
  void flush() {
    if (name != null) {
      result[name] = (dependency: dependency, source: source, version: version);
    }
  }

  for (final raw in lock.split('\n')) {
    final line = raw.replaceAll('\r', '').trimRight();
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) {
      continue;
    }
    final indent = _indent(line);
    if (indent == 0) {
      flush();
      name = null;
      inPackages = line.startsWith('packages:');
      continue;
    }
    if (!inPackages) {
      continue;
    }
    final colon = line.indexOf(':');
    if (colon < 0) {
      continue;
    }
    final key = line.substring(0, colon).trim();
    final value = _unquote(line.substring(colon + 1));
    if (indent == 2) {
      flush();
      name = key;
      dependency = '';
      source = '';
      version = '';
    } else if (indent == 4) {
      switch (key) {
        case 'dependency':
          dependency = value;
        case 'source':
          source = value;
        case 'version':
          version = value;
      }
    }
  }
  flush();
  return result;
}

Set<String> _parseAllowlist(String allowlist) => {
  for (final raw in allowlist.split('\n'))
    if (raw.trim().isNotEmpty && !raw.trim().startsWith('#')) raw.trim(),
};

final _exactVersion = RegExp(r'^\d+\.\d+\.\d+$');

/// Kiểm và trả danh sách vi phạm (rỗng khi sạch). [spine] `null` nghĩa là
/// không đọc được file spine.
List<String> checkStack(
  String pubspec,
  String lock,
  String? spine,
  String allowlist,
) {
  final violations = <String>[];
  final stack = spine == null ? null : parseStackTable(spine);
  if (stack == null) {
    violations.add(
      'không đọc được bảng Stack (thiếu file spine hoặc mục "## Stack") (AD-12)',
    );
    return violations;
  }

  final lockPackages = _parseLock(lock);
  final nested = <String>{};
  final topKeys = <String>{};
  final deps = _parsePubspecDeps(pubspec, nested, topKeys);

  if (topKeys.contains('dependency_overrides')) {
    violations.add('pubspec.yaml: cấm dependency_overrides (AD-12)');
  }
  for (final section in nested) {
    if (!deps.any((d) => d.section == section)) {
      violations.add(
        'pubspec.yaml: mục $section có dòng lồng nhưng không đọc được gói nào '
        '(phải thụt 2 dấu cách) (AD-12)',
      );
    }
  }
  final declared = {for (final d in deps) d.name};
  final lockNames = lockPackages.keys.toList()..sort();
  for (final name in lockNames) {
    final pkg = lockPackages[name]!;
    if (pkg.source != 'hosted' && pkg.source != 'sdk') {
      violations.add(
        '$name: pubspec.lock có source "${pkg.source}", chỉ cho phép hosted '
        'hoặc sdk (AD-12)',
      );
    }
    final directOk =
        (pkg.dependency == 'direct main' || pkg.dependency == 'direct dev') &&
        declared.contains(name);
    if (pkg.dependency != 'transitive' && !directOk) {
      violations.add(
        '$name: pubspec.lock có dependency "${pkg.dependency}" không khớp '
        'pubspec.yaml (AD-12)',
      );
    }
  }

  for (final dep in deps) {
    final name = dep.name;
    final isSdk = dep.children.any((c) => c.startsWith('sdk:'));
    if (isSdk) {
      if (name != 'flutter' && !stack.containsKey(name)) {
        violations.add(
          '$name (${dep.section}): không có trong bảng Stack (AD-12)',
        );
      }
      continue;
    }
    if (!stack.containsKey(name)) {
      violations.add(
        '$name (${dep.section}): không có trong bảng Stack (AD-12)',
      );
      continue;
    }
    final expected = stack[name]!;
    final constraint = dep.inlineValue;
    if (constraint == null || !_exactVersion.hasMatch(constraint)) {
      violations.add(
        '$name: ràng buộc "${constraint ?? dep.children.join(' ')}" không ghim '
        'chính xác X.Y.Z (AD-12)',
      );
      continue;
    }
    if (constraint != expected) {
      violations.add(
        '$name: phiên bản $constraint khác bảng Stack $expected (AD-12)',
      );
    }
    final locked = lockPackages[name];
    if (locked == null) {
      violations.add('$name: không có trong pubspec.lock (AD-12)');
    } else if (locked.version != expected) {
      violations.add(
        '$name: pubspec.lock có ${locked.version} khác bảng Stack $expected (AD-12)',
      );
    }
  }

  final allowed = _parseAllowlist(allowlist);
  final transitive =
      lockPackages.entries
          .where((e) => e.value.dependency == 'transitive')
          .map((e) => e.key)
          .toList()
        ..sort();
  for (final name in transitive) {
    if (!allowed.contains(name)) {
      violations.add(
        '$name: gói kéo theo không có trong $allowlistRelPath (AD-12)',
      );
    }
  }
  return violations;
}

String? _readOrNull(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}

/// Chạy kiểm trong [args] = `[pubspecDir, spinePath]`; trả exit code.
int run(List<String> args, {StringSink? out, StringSink? err}) {
  final output = out ?? stdout;
  final errors = err ?? stderr;
  final dir = args.isNotEmpty ? args[0] : '.';
  final spinePath = args.length > 1 ? args[1] : '$dir/$defaultSpinePath';
  final violations = <String>[];
  final pubspec = _readOrNull('$dir/pubspec.yaml');
  final lock = _readOrNull('$dir/pubspec.lock');
  final allowlist = _readOrNull('$dir/$allowlistRelPath');
  if (pubspec == null) {
    violations.add('không đọc được $dir/pubspec.yaml');
  }
  if (lock == null) {
    violations.add('không đọc được $dir/pubspec.lock');
  }
  if (allowlist == null) {
    violations.add('không đọc được $dir/$allowlistRelPath');
  }
  if (violations.isEmpty) {
    violations.addAll(
      checkStack(pubspec!, lock!, _readOrNull(spinePath), allowlist!),
    );
  }
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
