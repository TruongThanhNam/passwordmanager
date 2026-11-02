// Kiểm luật import và API cấm trong lib/ (AD-1, AD-2, AD-12, AD-16).
//
// Dart thuần, không dependency. Chạy trong pak_manager/:
//   dart run tool/check_imports.dart [root]
// Exit 0 khi sạch; exit 1 khi có vi phạm (in mỗi vi phạm một dòng
// `path:line: lý do` ra stderr) hoặc khi không tìm thấy `<root>/lib`.

import 'dart:io';

/// Một vi phạm, định vị theo đường dẫn tương đối (dấu `/`) và số dòng (từ 1).
class Violation {
  const Violation(this.path, this.line, this.reason);

  final String path;
  final int line;
  final String reason;

  @override
  String toString() => '$path:$line: $reason';
}

/// Kiểm một file. [relPath] là đường dẫn tính từ gốc package, ví dụ
/// `lib/features/auth/login.dart`. File ngoài `lib/` không bị kiểm.
List<Violation> checkSource(String relPath, String source) {
  final path = _normalize(relPath.replaceAll(r'\', '/'));
  if (!path.startsWith('lib/')) {
    return const <Violation>[];
  }
  final views = _lex(source);
  final lineStarts = _lineStarts(source);
  final violations = <Violation>[];
  final directiveSpans = <(int, int)>[];
  var importsDartIo = false;
  var importsDartMath = false;

  for (final directive in _directives(views)) {
    directiveSpans.add((directive.start, directive.end));
    final line = _lineOf(lineStarts, directive.start);
    for (final uri in directive.uris) {
      // Re-export sẽ cho file khác dùng HttpClient/Random mà không import
      // trực tiếp dart:io/dart:math, nên cấm ở mọi nơi trong lib/.
      if (directive.isExport && (uri == 'dart:io' || uri == 'dart:math')) {
        violations.add(Violation(path, line, 'cấm export $uri (AD-12, AD-16)'));
        continue;
      }
      if (uri == 'dart:io') {
        importsDartIo = true;
      } else if (uri == 'dart:math') {
        importsDartMath = true;
      }
      final reason = _checkUri(path, uri);
      if (reason != null) {
        violations.add(Violation(path, line, reason));
      }
    }
  }

  if (importsDartIo || importsDartMath) {
    for (final match in _apiToken.allMatches(views.codeOnly)) {
      final token = match.group(1)!;
      final inDirective = directiveSpans.any(
        (span) => match.start >= span.$1 && match.start < span.$2,
      );
      if (inDirective) {
        continue;
      }
      final String reason;
      if (token == 'Random') {
        if (!importsDartMath) {
          continue;
        }
        reason = 'cấm Random của dart:math, dùng RandomSource (AD-16)';
      } else {
        if (!importsDartIo) {
          continue;
        }
        reason = 'cấm $token của dart:io, app không có mạng (AD-12)';
      }
      violations.add(Violation(path, _lineOf(lineStarts, match.start), reason));
    }
  }

  violations.sort((a, b) => a.line.compareTo(b.line));
  return violations;
}

/// Kiểm mọi file `.dart` dưới `<root>/lib`, theo thứ tự đường dẫn.
List<Violation> checkTree(String root) {
  final base = _trimTrailingSlash(root.replaceAll(r'\', '/'));
  final libDir = Directory('$base/lib');
  final files =
      libDir
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map(
            (f) => (f, f.path.replaceAll(r'\', '/').substring(base.length + 1)),
          )
          .toList()
        ..sort((a, b) => a.$2.compareTo(b.$2));
  return [
    for (final (file, rel) in files)
      ...checkSource(rel, file.readAsStringSync()),
  ];
}

/// Điểm vào có thể test được: trả exit code thay vì gọi `exit`.
int run(List<String> args, {StringSink? out, StringSink? err}) {
  final o = out ?? stdout;
  final e = err ?? stderr;
  final root = args.isEmpty ? '.' : args.first;
  final base = _trimTrailingSlash(root.replaceAll(r'\', '/'));
  if (!Directory('$base/lib').existsSync()) {
    e.writeln('check_imports: không tìm thấy $base/lib');
    return 1;
  }
  final violations = checkTree(base);
  if (violations.isEmpty) {
    o.writeln('check_imports: OK');
    return 0;
  }
  violations.forEach(e.writeln);
  e.writeln('check_imports: ${violations.length} vi phạm');
  return 1;
}

void main(List<String> args) {
  exitCode = run(args);
}

// ---------------------------------------------------------------------------
// Luật

const _coreAllowedPackages = {'sodium', 'zxcvbnm'};
const _featureAllowedCore = [
  'lib/core/model/',
  'lib/core/policy/',
  'lib/core/search/',
];

final _apiToken = RegExp(
  r'(?<![\w$])('
  r'HttpClient|HttpServer|WebSocket|Socket|RawSocket|SecureSocket|'
  r'RawSecureSocket|ServerSocket|RawServerSocket|SecureServerSocket|'
  r'RawSecureServerSocket|RawDatagramSocket|InternetAddress|'
  r'NetworkInterface|HttpOverrides|Random'
  r')(?![\w$])',
);

String? _checkUri(String path, String uri) {
  final target = _Target.parse(path, uri);

  // Toàn lib/ (AD-1, AD-12).
  if (uri == 'package:flutter/material.dart') {
    return 'cấm package:flutter/material.dart, dùng package:cupertino_ui (AD-1)';
  }
  if (uri == 'package:flutter/cupertino.dart') {
    return 'cấm package:flutter/cupertino.dart, dùng package:cupertino_ui (AD-1)';
  }
  if (target.package == 'material_ui') {
    return 'cấm package:material_ui (AD-1)';
  }
  if (target.package == 'http') {
    return 'cấm package:http, app không có mạng (AD-12)';
  }
  if (target.unsupported) {
    return 'URI không hỗ trợ: $uri';
  }

  // features → chỉ core/model, core/policy, core/search (AD-2).
  if (path.startsWith('lib/features/')) {
    if (target.dartLibrary == 'io') {
      return 'lib/features không được import dart:io (AD-2)';
    }
    final internal = target.internal;
    if (internal != null) {
      if (internal.startsWith('lib/platform/')) {
        return 'lib/features không được import lib/platform/ (AD-2)';
      }
      if (internal.startsWith('lib/core/') &&
          !_featureAllowedCore.any(internal.startsWith)) {
        return 'lib/features chỉ được import core/model, core/policy, '
            'core/search; không được import $internal (AD-2)';
      }
    }
  }

  // core là Dart thuần (AD-2).
  if (path.startsWith('lib/core/')) {
    final dartLibrary = target.dartLibrary;
    if (dartLibrary != null && dartLibrary.startsWith('ui')) {
      return 'lib/core là Dart thuần, không được import dart:$dartLibrary (AD-2)';
    }
    if (dartLibrary == 'io' && !path.startsWith('lib/core/io/')) {
      return 'chỉ lib/core/io/ được import dart:io (AD-2)';
    }
    final package = target.package;
    if (package != null &&
        package != 'pak_manager' &&
        !_coreAllowedPackages.contains(package)) {
      return 'lib/core là Dart thuần, không được import package:$package '
          '(chỉ sodium, zxcvbnm) (AD-2)';
    }
    final internal = target.internal;
    if (internal != null && !internal.startsWith('lib/core/')) {
      return 'lib/core không được import $internal ngoài lib/core/ (AD-2)';
    }
  }
  return null;
}

/// Đích của một URI import/export, đã chuẩn hóa.
class _Target {
  const _Target({
    this.dartLibrary,
    this.package,
    this.internal,
    this.unsupported = false,
  });

  factory _Target.parse(String fromPath, String uri) {
    if (uri.startsWith('dart:')) {
      return _Target(dartLibrary: uri.substring(5));
    }
    if (uri.startsWith('package:')) {
      final rest = uri.substring(8);
      final slash = rest.indexOf('/');
      final package = slash < 0 ? rest : rest.substring(0, slash);
      final inner = slash < 0 ? '' : rest.substring(slash + 1);
      return _Target(
        package: package,
        internal: package == 'pak_manager' ? _normalize('lib/$inner') : null,
      );
    }
    if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(uri) ||
        uri.startsWith('/')) {
      return const _Target(unsupported: true);
    }
    return _Target(internal: _normalize('${_dirname(fromPath)}/$uri'));
  }

  /// `io` cho `dart:io`.
  final String? dartLibrary;

  /// Tên package cho `package:x/...`.
  final String? package;

  /// Đường dẫn trong package (`lib/...`) cho `package:pak_manager/...` hoặc
  /// URI tương đối.
  final String? internal;

  final bool unsupported;
}

// ---------------------------------------------------------------------------
// Phân tích nguồn

class _Directive {
  _Directive(this.start, this.end, this.uris, {required this.isExport});

  final int start;
  final int end;
  final List<String> uris;
  final bool isExport;
}

/// Hai bản sao cùng độ dài với nguồn: [noComments] đã xóa comment;
/// [codeOnly] xóa thêm nội dung chuỗi (giữ code trong `${...}`). Ký tự bị xóa
/// thay bằng khoảng trắng, giữ xuống dòng, nên offset và số dòng không đổi.
class _Views {
  _Views(this.noComments, this.codeOnly);

  final String noComments;
  final String codeOnly;
}

abstract class _Context {}

class _StringContext extends _Context {
  _StringContext(this.quote, {required this.raw});

  final String quote;
  final bool raw;
}

class _InterpolationContext extends _Context {
  int depth = 0;
}

_Views _lex(String src) {
  final noComments = StringBuffer();
  final codeOnly = StringBuffer();
  final stack = <_Context>[];
  final n = src.length;
  var i = 0;

  void emit(String ch, {required bool comment, required bool string}) {
    final blank = ch == '\n' || ch == '\r' ? ch : ' ';
    noComments.write(comment ? blank : ch);
    codeOnly.write(comment || string ? blank : ch);
  }

  void emitRun(int count, {required bool comment, required bool string}) {
    for (var k = 0; k < count && i < n; k++, i++) {
      emit(src[i], comment: comment, string: string);
    }
  }

  while (i < n) {
    final top = stack.isEmpty ? null : stack.last;
    final c = src[i];

    if (top is _StringContext) {
      if (!top.raw && c == r'\') {
        emitRun(2, comment: false, string: true);
      } else if (src.startsWith(top.quote, i)) {
        emitRun(top.quote.length, comment: false, string: false);
        stack.removeLast();
      } else if (!top.raw && c == r'$' && i + 1 < n && src[i + 1] == '{') {
        emitRun(2, comment: false, string: false);
        stack.add(_InterpolationContext());
      } else if (top.quote.length == 1 && c == '\n') {
        // Chuỗi một dòng chưa đóng: thoát để không nuốt phần còn lại.
        stack.removeLast();
        emitRun(1, comment: false, string: false);
      } else {
        emitRun(1, comment: false, string: true);
      }
      continue;
    }

    if (src.startsWith('//', i)) {
      while (i < n && src[i] != '\n') {
        emitRun(1, comment: true, string: false);
      }
      continue;
    }
    if (src.startsWith('/*', i)) {
      var depth = 0;
      do {
        if (src.startsWith('/*', i)) {
          depth++;
          emitRun(2, comment: true, string: false);
        } else if (src.startsWith('*/', i)) {
          depth--;
          emitRun(2, comment: true, string: false);
        } else {
          emitRun(1, comment: true, string: false);
        }
      } while (depth > 0 && i < n);
      continue;
    }
    if (c == "'" || c == '"') {
      final raw =
          i > 0 &&
          (src[i - 1] == 'r' || src[i - 1] == 'R') &&
          (i < 2 || !_isIdentifierChar(src[i - 2]));
      final triple = src.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      emitRun(quote.length, comment: false, string: false);
      stack.add(_StringContext(quote, raw: raw));
      continue;
    }
    if (top is _InterpolationContext) {
      if (c == '{') {
        top.depth++;
      } else if (c == '}') {
        if (top.depth == 0) {
          stack.removeLast();
        } else {
          top.depth--;
        }
      }
    }
    emitRun(1, comment: false, string: false);
  }
  return _Views(noComments.toString(), codeOnly.toString());
}

final _directiveKeyword = RegExp(r'''(?<![\w$.])(import|export)\s*(?=['"])''');

Iterable<_Directive> _directives(_Views views) sync* {
  final text = views.noComments;
  for (final match in _directiveKeyword.allMatches(views.codeOnly)) {
    final uris = <String>[];
    var i = match.end;
    while (i < text.length && text[i] != ';') {
      final c = text[i];
      if (c == "'" || c == '"') {
        final close = text.indexOf(c, i + 1);
        if (close < 0) {
          break;
        }
        uris.add(text.substring(i + 1, close));
        i = close + 1;
      } else {
        i++;
      }
    }
    yield _Directive(
      match.start,
      i,
      uris,
      isExport: match.group(1) == 'export',
    );
  }
}

bool _isIdentifierChar(String ch) => RegExp(r'[\w$]').hasMatch(ch);

List<int> _lineStarts(String src) {
  final starts = <int>[0];
  for (var i = 0; i < src.length; i++) {
    if (src.codeUnitAt(i) == 0x0A) {
      starts.add(i + 1);
    }
  }
  return starts;
}

int _lineOf(List<int> lineStarts, int offset) {
  var lo = 0;
  var hi = lineStarts.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (lineStarts[mid] <= offset) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo + 1;
}

String _normalize(String path) {
  final out = <String>[];
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..' && out.isNotEmpty && out.last != '..') {
      out.removeLast();
    } else {
      out.add(segment);
    }
  }
  return out.join('/');
}

String _dirname(String path) {
  final slash = path.lastIndexOf('/');
  return slash < 0 ? '' : path.substring(0, slash);
}

String _trimTrailingSlash(String path) => path.length > 1 && path.endsWith('/')
    ? path.substring(0, path.length - 1)
    : path;
