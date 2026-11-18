import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/ci/check_stack.dart';

const _spine = '''
# Spine

## Stack

| Name | Version |
| --- | --- |
| Flutter SDK (Dart 3.13) | 3.47.8 stable |
| Gradle (wrapper) | 9.3.1 |
| Xcode (CI) | 26.3 |
| sodium (libsodium 1.0.22) | 4.1.2 |
| pigeon (dev) | 29.0.11 |
| flutter_localizations / gen-l10n, flutter_test | theo Flutter SDK 3.47.8 |

## Structural Seed
''';

String _pubspec({String deps = '', String devDeps = ''}) =>
    '''
name: demo
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  sodium: 4.1.2
$deps
dev_dependencies:
  flutter_test:
    sdk: flutter
  pigeon: 29.0.11
$devDeps
''';

String _lock({String sodium = '4.1.2', String extra = ''}) =>
    '''
packages:
  collection:
    dependency: transitive
    description:
      name: collection
    source: hosted
    version: "1.19.1"
  flutter:
    dependency: "direct main"
    description: flutter
    source: sdk
    version: "0.0.0"
  pigeon:
    dependency: "direct dev"
    source: hosted
    version: "29.0.11"
  sodium:
    dependency: "direct main"
    source: hosted
    version: "$sodium"
$extra
sdks:
  dart: ">=3.13.0 <4.0.0"
''';

const _allowlist = '# chú thích\ncollection\n';

// File thật của repo (cwd là pak_manager/); ca toolchain sửa trên các bản này.
final _realSpine = File(defaultSpinePath).readAsStringSync();
final _realCi = File(ciRelPath).readAsStringSync();
final _realProps = File(gradlePropsRelPath).readAsStringSync();

List<String> _toolchain({String? spine, String? ci, String? props}) =>
    checkToolchain(
      parseStackTable(spine ?? _realSpine)!,
      ci ?? _realCi,
      props ?? _realProps,
    );

/// Bỏ dòng bảng Stack có tên bắt đầu bằng [name].
String _spineWithoutRow(String name) {
  final lines = _realSpine.split('\n');
  final kept = lines.where((l) => !l.startsWith('| $name')).toList();
  expect(kept.length, lines.length - 1, reason: 'không thấy dòng $name');
  return kept.join('\n');
}

void main() {
  test('ad12_stack_table_names_split_and_parens_dropped', () {
    final stack = parseStackTable(_spine)!;
    expect(stack['sodium'], '4.1.2');
    expect(stack['pigeon'], '29.0.11');
    expect(stack.keys, containsAll(['flutter_localizations', 'flutter_test']));
  });

  test('ad12_clean_inputs_have_no_violation', () {
    expect(checkStack(_pubspec(), _lock(), _spine, _allowlist), isEmpty);
  });

  test('ad12_dependency_outside_stack_rejected', () {
    final v = checkStack(
      _pubspec(deps: '  http: 1.2.0'),
      _lock(),
      _spine,
      _allowlist,
    );
    expect(v, hasLength(1));
    expect(v.single, contains('http'));
  });

  test('ad12_dev_dependency_outside_stack_rejected', () {
    final v = checkStack(
      _pubspec(devDeps: '  mocktail: 1.0.4'),
      _lock(),
      _spine,
      _allowlist,
    );
    expect(v, hasLength(1));
    expect(v.single, contains('mocktail'));
  });

  test('ad12_caret_constraint_rejected', () {
    final pubspec = _pubspec().replaceFirst('sodium: 4.1.2', 'sodium: ^4.1.2');
    final v = checkStack(pubspec, _lock(), _spine, _allowlist);
    expect(v, hasLength(1));
    expect(v.single, contains('không ghim chính xác'));
  });

  test('ad12_git_dependency_rejected', () {
    final pubspec = _pubspec().replaceFirst(
      'sodium: 4.1.2',
      'sodium:\n    git: https://example.com/sodium.git',
    );
    final v = checkStack(pubspec, _lock(), _spine, _allowlist);
    expect(v.single, contains('không ghim chính xác'));
  });

  test('ad12_version_mismatch_with_stack_rejected', () {
    final pubspec = _pubspec().replaceFirst('sodium: 4.1.2', 'sodium: 4.1.1');
    final v = checkStack(pubspec, _lock(), _spine, _allowlist);
    expect(v, isNotEmpty);
    expect(v.first, contains('khác bảng Stack 4.1.2'));
  });

  test('ad12_lock_version_mismatch_rejected', () {
    final v = checkStack(
      _pubspec(),
      _lock(sodium: '4.1.3'),
      _spine,
      _allowlist,
    );
    expect(v.single, contains('pubspec.lock có 4.1.3'));
  });

  test('ad12_new_transitive_package_rejected', () {
    const extra = '''
  foo:
    dependency: transitive
    source: hosted
    version: "1.0.0"''';
    final v = checkStack(_pubspec(), _lock(extra: extra), _spine, _allowlist);
    expect(v.single, contains('foo'));
  });

  test('ad12_missing_spine_or_stack_section_rejected', () {
    for (final spine in [null, '# Spine\n\n## Khác\n']) {
      final v = checkStack(_pubspec(), _lock(), spine, _allowlist);
      expect(v.single, contains('không đọc được bảng Stack'));
    }
  });

  test('ad12_real_repo_files_are_clean', () {
    final v = checkStack(
      File('pubspec.yaml').readAsStringSync(),
      File('pubspec.lock').readAsStringSync(),
      File(defaultSpinePath).readAsStringSync(),
      File(allowlistRelPath).readAsStringSync(),
    );
    expect(v, isEmpty);
  });

  test('ad12_dependency_overrides_rejected', () {
    final pubspec = '${_pubspec()}dependency_overrides:\n  sodium: 4.1.3\n';
    final v = checkStack(pubspec, _lock(), _spine, _allowlist);
    expect(v.single, contains('dependency_overrides'));
  });

  test('ad12_lock_direct_not_in_pubspec_or_overridden_rejected', () {
    const extra = '''
  bar:
    dependency: "direct main"
    source: hosted
    version: "1.0.0"
  baz:
    dependency: "direct overridden"
    source: hosted
    version: "1.0.0"''';
    final v = checkStack(_pubspec(), _lock(extra: extra), _spine, _allowlist);
    expect(v, hasLength(2));
    expect(v[0], contains('bar'));
    expect(v[1], contains('baz'));
  });

  test('ad12_lock_git_source_rejected', () {
    final lock = _lock().replaceFirst(
      'name: collection\n    source: hosted',
      'name: collection\n    source: git',
    );
    final v = checkStack(_pubspec(), lock, _spine, _allowlist);
    expect(v.single, contains('source "git"'));
  });

  test('ad12_misindented_dependencies_rejected', () {
    const pubspec = 'name: demo\ndependencies:\n    http: 1.2.0\n';
    final v = checkStack(pubspec, _lock(), _spine, _allowlist);
    expect(v.any((x) => x.contains('mục dependencies')), isTrue);
  });

  test('ad12_sdk_dependency_outside_stack_rejected', () {
    final v = checkStack(
      _pubspec(devDeps: '  integration_test:\n    sdk: flutter'),
      _lock(),
      _spine,
      _allowlist,
    );
    expect(v.single, contains('integration_test'));
  });

  group('toolchain', () {
    test('ad12_real_toolchain_matches_stack', () {
      final stack = parseStackTable(_realSpine)!;
      expect(stack['Flutter'], '3.47.8');
      expect(stack['Gradle'], '9.3.1');
      expect(stack['Xcode'], '26.3');
      expect(_toolchain(), isEmpty);
    });

    test('ad12_flutter_version_mismatch_rejected', () {
      final ci = _realCi.replaceFirst(
        "FLUTTER_VERSION: '3.47.8'",
        "FLUTTER_VERSION: '3.47.9'",
      );
      expect(ci, isNot(_realCi));
      final v = _toolchain(ci: ci);
      expect(v.single, allOf(contains('3.47.9'), contains('3.47.8')));
    });

    test('ad12_gradle_version_mismatch_rejected', () {
      final props = _realProps.replaceFirst(
        'gradle-9.3.1-all.zip',
        'gradle-9.3.0-all.zip',
      );
      expect(props, isNot(_realProps));
      final v = _toolchain(props: props);
      expect(v.single, allOf(contains('9.3.0'), contains('9.3.1')));
    });

    test('ad12_xcode_mismatch_in_one_job_rejected', () {
      // Đổi mọi Xcode_26.3.app của job integration-ios (job cuối) sang 26.2.
      final at = _realCi.indexOf('  integration-ios:');
      expect(at, greaterThan(0));
      final ci =
          _realCi.substring(0, at) +
          _realCi.substring(at).replaceAll('Xcode_26.3.app', 'Xcode_26.2.app');
      expect(ci, isNot(_realCi));
      final v = _toolchain(ci: ci);
      expect(v, isNotEmpty);
      for (final x in v) {
        expect(x, allOf(contains('Xcode'), contains('26.2'), contains('26.3')));
      }
    });

    test('ad12_stack_missing_toolchain_row_rejected', () {
      for (final (row, tool) in [
        ('Gradle (wrapper)', 'Gradle'),
        ('Xcode (CI)', 'Xcode'),
        ('Flutter SDK', 'Flutter'),
      ]) {
        final v = _toolchain(spine: _spineWithoutRow(row));
        expect(v.single, contains('bảng Stack thiếu dòng $tool'));
      }
    });

    test('ad12_ci_without_xcode_app_rejected', () {
      final ci = _realCi.replaceAll(RegExp(r'Xcode_[0-9.]+\.app'), 'Xcode.app');
      expect(ci, isNot(_realCi));
      expect(_toolchain(ci: ci).single, contains('Xcode_*.app'));
    });

    test('ad12_ci_without_flutter_version_rejected', () {
      final ci = _realCi.replaceFirst(
        "FLUTTER_VERSION: '3.47.8'",
        "# FLUTTER_VERSION: '3.47.8'",
      );
      expect(ci, isNot(_realCi));
      expect(_toolchain(ci: ci).single, contains('FLUTTER_VERSION'));
    });

    test('ad12_props_without_distribution_url_rejected', () {
      final props = _realProps.replaceFirst(
        'distributionUrl=',
        '#distributionUrl=',
      );
      expect(props, isNot(_realProps));
      expect(_toolchain(props: props).single, contains('distributionUrl'));
    });
  });

  group('run', () {
    late Directory dir;
    late String spinePath;
    late String ciPath;
    late String propsPath;

    List<String> args() => [dir.path, spinePath, ciPath, propsPath];

    setUp(() {
      dir = Directory.systemTemp.createTempSync('check_stack_');
      spinePath = '${dir.path}/spine.md';
      ciPath = '${dir.path}/ci.yml';
      propsPath = '${dir.path}/gradle-wrapper.properties';
      File(spinePath).writeAsStringSync(_spine);
      File(ciPath).writeAsStringSync(_realCi);
      File(propsPath).writeAsStringSync(_realProps);
      File('${dir.path}/pubspec.yaml').writeAsStringSync(_pubspec());
      File('${dir.path}/pubspec.lock').writeAsStringSync(_lock());
      File('${dir.path}/$allowlistRelPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(_allowlist);
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('ad12_run_clean_returns_0', () {
      final out = StringBuffer();
      final err = StringBuffer();
      expect(
        run(args(), out: out, err: err),
        0,
        reason: '$err',
      );
      expect(out.toString().trim(), 'OK');
    });

    test('ad12_run_real_repo_defaults_return_0', () {
      final out = StringBuffer();
      final err = StringBuffer();
      expect(
        run([], out: out, err: err),
        0,
        reason: '$err',
      );
      expect(out.toString().trim(), 'OK');
    });

    test('ad12_run_violation_returns_1', () {
      File('${dir.path}/pubspec.yaml')
          .writeAsStringSync(_pubspec(deps: '  http: 1.2.0'));
      final err = StringBuffer();
      expect(run(args(), out: StringBuffer(), err: err), 1);
      expect(err.toString(), contains('http'));
    });

    test('ad12_run_missing_pubspec_returns_1', () {
      File('${dir.path}/pubspec.yaml').deleteSync();
      final err = StringBuffer();
      expect(run(args(), out: StringBuffer(), err: err), 1);
      expect(err.toString(), contains('pubspec.yaml'));
    });

    test('ad12_run_toolchain_mismatch_returns_1', () {
      File(ciPath).writeAsStringSync(
        _realCi.replaceFirst(
          "FLUTTER_VERSION: '3.47.8'",
          "FLUTTER_VERSION: '3.47.9'",
        ),
      );
      final err = StringBuffer();
      expect(run(args(), out: StringBuffer(), err: err), 1);
      expect(err.toString(), allOf(contains('3.47.9'), contains('3.47.8')));
    });

    test('ad12_run_missing_ci_or_props_returns_1', () {
      for (final path in [ciPath, propsPath]) {
        final saved = File(path).readAsStringSync();
        File(path).deleteSync();
        final err = StringBuffer();
        expect(run(args(), out: StringBuffer(), err: err), 1);
        expect(err.toString(), contains('không đọc được $path'));
        File(path).writeAsStringSync(saved);
      }
    });
  });
}
