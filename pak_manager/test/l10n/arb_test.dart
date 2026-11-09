import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// NFR-14, UX-DR37, UX-DR38: hai file ARB cùng tập key; chuỗi không có dấu
// chấm than và emoji.
const _arbDir = 'lib/l10n';
const _locales = ['en', 'vi'];

Map<String, Object?> _arb(String locale) =>
    jsonDecode(File('$_arbDir/app_$locale.arb').readAsStringSync())
        as Map<String, Object?>;

/// Chỉ các message (key không bắt đầu bằng `@`).
Map<String, String> _messages(String locale) => {
  for (final e in _arb(locale).entries)
    if (!e.key.startsWith('@')) e.key: e.value! as String,
};

/// Các khối emoji/pictograph chính, cộng VS16 và ZWJ của chuỗi emoji.
final _emoji = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]',
  unicode: true,
);

void main() {
  test('nfr14_arb_files_have_the_same_keys', () {
    final en = _messages('en').keys.toSet();
    final vi = _messages('vi').keys.toSet();

    expect(en, isNotEmpty);
    expect(vi, en);
  });

  test('nfr14_arb_locale_matches_file_name', () {
    for (final locale in _locales) {
      expect(_arb(locale)['@@locale'], locale);
    }
  });

  test('ux_dr37_arb_keys_are_camel_case_microcopy_keys', () {
    for (final locale in _locales) {
      for (final key in _messages(locale).keys) {
        expect(key, matches(RegExp(r'^[a-z][a-zA-Z0-9]*$')), reason: key);
      }
    }
    // `app.name` → `appName` (EXPERIENCE.md).
    expect(_messages('en')['appName'], 'PAK Manager');
    expect(_messages('vi')['appName'], 'PAK Manager');
  });

  test('ux_dr38_messages_have_no_exclamation_or_emoji', () {
    for (final locale in _locales) {
      _messages(locale).forEach((key, message) {
        expect(message, isNot(contains('!')), reason: '$locale.$key');
        expect(message, isNot(contains('！')), reason: '$locale.$key');
        expect(_emoji.hasMatch(message), isFalse, reason: '$locale.$key');
      });
    }
  });

  test('ux_dr38_emoji_detector_catches_emoji', () {
    // Bảo đảm regex dò emoji thật sự hoạt động.
    expect(
      _emoji.hasMatch('Đã copy. Bạn có thể dán vào ứng dụng khác.'),
      isFalse,
    );
    expect(_emoji.hasMatch('Copy thành công ✓'), isTrue);
    expect(_emoji.hasMatch('Xong 🎉'), isTrue);
    expect(_emoji.hasMatch('Copy thành công ✅'), isTrue);
    expect(_emoji.hasMatch('Nhớ nhé ❤️'), isTrue);
  });
}
