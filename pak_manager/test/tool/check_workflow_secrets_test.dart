import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/ci/check_workflow_secrets.dart';

const _clean = '''
name: CI
on:
  pull_request:
jobs:
  android:
    runs-on: ubuntu-24.04
    steps:
      - run: echo "\${{ github.ref }}"
''';

String _withLine(String line) => '$_clean      - run: $line\n';

void main() {
  test('ad18_clean_workflow_passes', () {
    expect(checkWorkflowSecrets(_clean), isEmpty);
  });

  test('ad18_secret_dot_rejected', () {
    final v = checkWorkflowSecrets(_withLine(r'echo ${{ secrets.TOKEN }}'));
    expect(v.single, startsWith('dòng 9:'));
  });

  test('ad18_secret_bracket_rejected', () {
    expect(
      checkWorkflowSecrets(_withLine(r"echo ${{ secrets['TOKEN'] }}")),
      hasLength(1),
    );
    expect(
      checkWorkflowSecrets(_withLine(r'echo ${{ secrets["TOKEN"] }}')),
      hasLength(1),
    );
  });

  test('ad18_secret_to_json_rejected', () {
    expect(
      checkWorkflowSecrets(_withLine(r'echo ${{ toJSON(secrets) }}')),
      hasLength(1),
    );
    expect(
      checkWorkflowSecrets(_withLine(r'echo ${{ toJSON( secrets ) }}')),
      hasLength(1),
    );
  });

  test('ad18_secret_at_end_of_line_rejected', () {
    expect(checkWorkflowSecrets('env: secrets\n'), hasLength(1));
  });

  test('ad18_secret_in_comment_rejected', () {
    expect(
      checkWorkflowSecrets(_withLine('true # secrets.TOKEN')),
      hasLength(1),
    );
  });

  test('ad18_pull_request_target_rejected', () {
    final v = checkWorkflowSecrets('on:\n  pull_request_target:\n');
    expect(v.single, startsWith('dòng 2:'));
    expect(v.single, contains('pull_request_target'));
  });

  test('ad18_word_continuation_not_flagged', () {
    // Giữ ngữ nghĩa regex cũ: `secrets` nối ký tự từ không bị bắt.
    expect(checkWorkflowSecrets('x: secrets_manager\n'), isEmpty);
    expect(checkWorkflowSecrets('x: my_secrets_file\n'), isEmpty);
    expect(checkWorkflowSecrets('x: secretsX\n'), isEmpty);
  });

  test('ad18_secret_case_insensitive_rejected', () {
    // Context của biểu thức GitHub không phân biệt hoa thường.
    expect(
      checkWorkflowSecrets(_withLine(r'echo ${{ Secrets.TOKEN }}')),
      hasLength(1),
    );
    expect(
      checkWorkflowSecrets(_withLine(r"echo ${{ SECRETS['X'] }}")),
      hasLength(1),
    );
  });

  test('ad18_real_ci_yml_clean', () {
    final err = StringBuffer();
    final out = StringBuffer();
    expect(
      run(['../.github/workflows/ci.yml'], out: out, err: err),
      0,
      reason: err.toString(),
    );
    expect(out.toString().trim(), 'OK');
  });

  test('ad18_run_violation_exit_1', () {
    final dir = Directory.systemTemp.createTempSync('wf_secrets_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/ci.yml')
      ..writeAsStringSync(_withLine(r'echo ${{ secrets.TOKEN }}'));
    final err = StringBuffer();
    expect(run([file.path], out: StringBuffer(), err: err), 1);
    expect(err.toString(), contains('dòng 9:'));
  });

  test('ad18_run_missing_file_exit_1', () {
    expect(
      run(['khong_ton_tai.yml'], out: StringBuffer(), err: StringBuffer()),
      1,
    );
    expect(run([], out: StringBuffer(), err: StringBuffer()), 1);
  });
}
