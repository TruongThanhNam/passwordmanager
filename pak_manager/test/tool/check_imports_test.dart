import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_imports.dart';

const _fixtures = 'test/fixtures/check_imports';

List<String> _locations(List<Violation> violations) => [
  for (final v in violations) '${v.path}:${v.line}',
];

void main() {
  group('checkTree trên fixture', () {
    test('ad02_clean_tree_has_no_violation', () {
      expect(checkTree('$_fixtures/clean'), isEmpty);
    });

    test('ad01_forbidden_ui_and_http_imports_all_reported', () {
      final violations = checkTree('$_fixtures/forbidden_ui');
      expect(_locations(violations), [
        'lib/services/forbidden.dart:1',
        'lib/services/forbidden.dart:2',
        'lib/services/forbidden.dart:3',
        'lib/services/forbidden.dart:4',
      ]);
      expect(violations[0].reason, contains('package:flutter/material.dart'));
      expect(violations[1].reason, contains('package:flutter/cupertino.dart'));
      expect(violations[2].reason, contains('material_ui'));
      expect(violations[3].reason, contains('package:http'));
    });

    test('ad02_features_cannot_import_core_internals_platform_or_dart_io', () {
      final violations = checkTree('$_fixtures/features_core');
      const file = 'lib/features/cards/card_list.dart';
      expect(_locations(violations), [
        '$file:1',
        '$file:2',
        '$file:3',
        '$file:4',
        '$file:5',
        '$file:6',
        '$file:9',
      ]);
      expect(violations[0].reason, contains('lib/core/crypto/kdf.dart'));
      expect(
        violations[1].reason,
        contains('lib/core/format/vault_file_codec.dart'),
      );
      expect(
        violations[2].reason,
        contains('lib/core/io/atomic_file_writer.dart'),
      );
      expect(violations[3].reason, contains('lib/core/ports/clock_port.dart'));
      expect(violations[4].reason, contains('lib/platform/'));
      expect(violations[5].reason, contains('dart:io'));
      // Đường dẫn tương đối được chuẩn hóa trước khi so.
      expect(violations[6].reason, contains('lib/core/crypto/kdf.dart'));
    });

    test('ad02_core_must_be_pure_dart', () {
      final violations = checkTree('$_fixtures/core_impure');
      const file = 'lib/core/model/card.dart';
      expect(_locations(violations), [
        '$file:1',
        '$file:2',
        '$file:3',
        '$file:4',
        '$file:5',
      ]);
      expect(violations[0].reason, contains('package:flutter'));
      expect(violations[1].reason, contains('dart:ui'));
      expect(violations[2].reason, contains('package:path'));
      expect(
        violations[3].reason,
        contains('lib/services/account_service.dart'),
      );
      expect(violations[4].reason, contains('lib/features/auth/login.dart'));
    });

    test('ad02_only_core_io_may_import_dart_io', () {
      final violations = checkTree('$_fixtures/core_dart_io');
      expect(_locations(violations), ['lib/core/model/a.dart:1']);
      expect(violations.single.reason, contains('lib/core/io/'));
    });

    test('ad12_ad16_forbidden_apis_reported_comments_ignored', () {
      final violations = checkTree('$_fixtures/forbidden_api');
      expect(_locations(violations), [
        'lib/services/net.dart:5',
        'lib/services/net.dart:6',
        'lib/services/net_alias.dart:4',
        'lib/services/net_alias.dart:5',
        'lib/services/rng.dart:4',
      ]);
      expect(violations[0].reason, contains('HttpClient'));
      expect(violations[1].reason, contains('Socket'));
      expect(violations[2].reason, contains('ServerSocket'));
      expect(violations[3].reason, contains('RawSocket'));
      expect(violations[4].reason, contains('Random'));
    });

    test('ad02_project_lib_is_clean', () {
      expect(checkTree('.'), isEmpty);
    });
  });

  group('checkSource', () {
    test('files_outside_lib_are_not_checked', () {
      expect(
        checkSource('tool/x.dart', "import 'package:flutter/material.dart';"),
        isEmpty,
      );
    });

    test('windows_separators_are_normalized', () {
      final violations = checkSource(
        r'lib\features\auth\a.dart',
        "import '../../core/crypto/kdf.dart';",
      );
      expect(
        violations.single.toString(),
        startsWith('lib/features/auth/a.dart:1: '),
      );
    });

    test('commented_out_import_is_ignored', () {
      const source = '''
// import 'package:flutter/material.dart';
/* import 'package:http/http.dart'; */
''';
      expect(checkSource('lib/a.dart', source), isEmpty);
    });

    test('multiline_and_export_directives_are_checked', () {
      const source = '''
export 'package:flutter/material.dart'
    show Colors;
import
    'package:http/http.dart'
    as http;
''';
      expect(_locations(checkSource('lib/a.dart', source)), [
        'lib/a.dart:1',
        'lib/a.dart:3',
      ]);
    });

    test('conditional_import_checks_every_uri', () {
      const source =
          "import 'stub.dart' if (dart.library.io) 'package:http/http.dart';";
      expect(
        checkSource('lib/a.dart', source).single.reason,
        contains('package:http'),
      );
    });

    test('hide_combinator_is_not_api_use', () {
      expect(
        checkSource('lib/services/a.dart', "import 'dart:io' hide HttpClient;"),
        isEmpty,
      );
    });

    test('api_inside_string_interpolation_is_reported', () {
      const source = '''
import 'dart:io';
final s = 'x \${HttpClient()}';
''';
      expect(_locations(checkSource('lib/services/a.dart', source)), [
        'lib/services/a.dart:2',
      ]);
    });

    test('api_inside_plain_string_is_ignored', () {
      const source = '''
import 'dart:math';
const s = 'Random';
''';
      expect(checkSource('lib/services/a.dart', source), isEmpty);
    });

    test('violation_format_is_path_line_reason', () {
      final v = checkSource(
        'lib/a.dart',
        "import 'package:flutter/cupertino.dart';",
      ).single;
      expect(v.toString(), matches(RegExp(r'^lib/a\.dart:1: .+')));
    });
  });

  group('run', () {
    test('clean_tree_exits_0_without_violations', () {
      final out = StringBuffer();
      final err = StringBuffer();
      expect(run(['$_fixtures/clean'], out: out, err: err), 0);
      expect(err.toString(), isEmpty);
    });

    test('dirty_tree_exits_1_and_lists_every_violation', () {
      final out = StringBuffer();
      final err = StringBuffer();
      expect(run(['$_fixtures/forbidden_ui'], out: out, err: err), 1);
      final lines = err.toString().trim().split('\n');
      expect(
        lines.where((l) => l.startsWith('lib/services/forbidden.dart:')),
        hasLength(4),
      );
    });

    test('missing_lib_exits_1', () {
      final err = StringBuffer();
      expect(
        run(['$_fixtures/does_not_exist'], out: StringBuffer(), err: err),
        1,
      );
      expect(err.toString(), contains('lib'));
    });
  });
}
