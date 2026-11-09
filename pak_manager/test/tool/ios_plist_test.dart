import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// AD-1, UX-DR49: iPhone chỉ dọc, iPad mọi hướng. NFR-14: bundle khai báo
// en và vi để iOS hiện đúng ngôn ngữ app.
final _plist = File('ios/Runner/Info.plist')
    .readAsStringSync()
    .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

/// Các `<string>` trong `<array>` ngay sau `<key>[key]</key>`; `null` nếu
/// thiếu key.
List<String>? _stringArray(String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(_plist);
  if (match == null) {
    return null;
  }
  return [
    for (final s in RegExp(r'<string>([^<]*)</string>').allMatches(match[1]!))
      s[1]!,
  ];
}

void main() {
  test('ad01_iphone_supports_portrait_only', () {
    expect(_stringArray('UISupportedInterfaceOrientations'), [
      'UIInterfaceOrientationPortrait',
    ]);
  });

  test('ad01_ipad_supports_every_orientation', () {
    expect(_stringArray('UISupportedInterfaceOrientations~ipad')?.toSet(), {
      'UIInterfaceOrientationPortrait',
      'UIInterfaceOrientationPortraitUpsideDown',
      'UIInterfaceOrientationLandscapeLeft',
      'UIInterfaceOrientationLandscapeRight',
    });
  });

  test('nfr14_bundle_declares_en_and_vi', () {
    expect(_stringArray('CFBundleLocalizations'), ['en', 'vi']);
  });
}
