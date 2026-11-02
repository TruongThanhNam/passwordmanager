import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// NFR-8, AD-11: CI chỉ kiểm manifest có trỏ tới rules; test này kiểm nội dung.
const _xmlDir = 'android/app/src/main/res/xml';

const _allDomains = {
  'root',
  'file',
  'database',
  'sharedpref',
  'external',
  'device_root',
  'device_file',
  'device_database',
  'device_sharedpref',
};

String _readWithoutComments(String name) =>
    File('$_xmlDir/$name')
        .readAsStringSync()
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

/// Nội dung giữa `<tag>` và `</tag>`; `null` nếu không có.
String? _section(String xml, String tag) => RegExp(
  '<$tag(?:\\s[^>]*)?>(.*?)</$tag>',
  dotAll: true,
).firstMatch(xml)?.group(1);

String? _attr(String element, String name) =>
    RegExp('\\b$name\\s*=\\s*"([^"]*)"').firstMatch(element)?.group(1);

/// Domain được loại toàn bộ (`path="."`) trong [section].
Set<String> _excludedDomains(String section) => {
  for (final m in RegExp(r'<exclude\b[^>]*>').allMatches(section))
    if (_attr(m.group(0)!, 'path') == '.') _attr(m.group(0)!, 'domain') ?? '',
};

void main() {
  test('nfr8_data_extraction_rules_exclude_every_domain', () {
    final xml = _readWithoutComments('data_extraction_rules.xml');

    expect(xml, isNot(contains('<include')));
    for (final tag in ['cloud-backup', 'device-transfer']) {
      final section = _section(xml, tag);
      expect(section, isNotNull, reason: 'thiếu <$tag>');
      expect(_excludedDomains(section!), _allDomains, reason: '<$tag>');
    }
  });

  test('nfr8_full_backup_content_excludes_every_domain', () {
    final xml = _readWithoutComments('backup_rules.xml');

    expect(xml, isNot(contains('<include')));
    final section = _section(xml, 'full-backup-content');
    expect(section, isNotNull, reason: 'thiếu <full-backup-content>');
    expect(_excludedDomains(section!), _allDomains);
  });
}
