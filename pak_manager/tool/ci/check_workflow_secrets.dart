// Kiểm workflow PR không tham chiếu GitHub Secrets và không dùng trigger
// pull_request_target (AD-18, NFR-7).
//
// Dart thuần, không dependency. Chạy trong pak_manager/:
//   dart run tool/ci/check_workflow_secrets.dart ../.github/workflows/ci.yml
// Quét mọi dòng, kể cả comment YAML (fail-closed). Exit 0 và in "OK" khi
// sạch; exit 1 khi có vi phạm (mỗi vi phạm một dòng stderr).

import 'dart:io';

// `secrets` (không phân biệt hoa thường như context GitHub) theo sau ký tự
// không phải từ hoặc cuối dòng: bắt `secrets.X`,
// `secrets['X']`, `secrets["X"]`, `toJSON( secrets )`.
final _secrets = RegExp(r'secrets([^A-Za-z0-9_]|$)', caseSensitive: false);
final _prTarget = RegExp('pull_request_target');

/// Trả vi phạm dạng `dòng N: …` (rỗng khi sạch).
List<String> checkWorkflowSecrets(String text) {
  final violations = <String>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].replaceAll('\r', '');
    if (_secrets.hasMatch(line)) {
      violations.add(
        'dòng ${i + 1}: tham chiếu secret (AD-18): ${line.trim()}',
      );
    }
    if (_prTarget.hasMatch(line)) {
      violations.add(
        'dòng ${i + 1}: cấm trigger pull_request_target (AD-18): '
        '${line.trim()}',
      );
    }
  }
  return violations;
}

/// [args] = `[workflowPath]`; trả exit code.
int run(List<String> args, {StringSink? out, StringSink? err}) {
  final output = out ?? stdout;
  final errors = err ?? stderr;
  if (args.isEmpty) {
    errors.writeln('Dùng: check_workflow_secrets.dart <workflow.yml>');
    return 1;
  }
  final file = File(args[0]);
  if (!file.existsSync()) {
    errors.writeln('không đọc được ${args[0]}');
    return 1;
  }
  final violations = checkWorkflowSecrets(file.readAsStringSync());
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
  exit(run(args));
}
