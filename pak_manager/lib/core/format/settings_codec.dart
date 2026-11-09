import 'dart:convert';

import '../model/settings.dart';

/// Codec duy nhất của file `settings` (AD-20). Dạng v1:
///
/// ```json
/// {"v":1,"language":"vi"|"en"|null,"appearance":"system"|"light"|"dark",
///  "autolockMin":1|3|5|10,"sessionMin":1|3|5|10,"clipboardMin":1|3|5|10,
///  "gen":{"length":4–99,"upper":bool,"lower":bool,"digits":bool,
///         "special":bool},
///  "lastExportAt":int≥0|null}
/// ```
///
/// Khác các file vault, `settings` không bao giờ là `corrupt`: trường thiếu
/// hoặc ngoài miền lấy mặc định của riêng trường đó; file không đọc được
/// (không phải UTF-8/JSON, không phải object, `v` ≠ 1) lấy toàn bộ mặc định.
/// Key lạ bị bỏ qua.
abstract final class SettingsCodec {
  static const int version = 1;

  /// Không bao giờ ném.
  static Settings decode(List<int> bytes) {
    final Object? root;
    try {
      root = jsonDecode(utf8.decode(bytes));
    } on Object {
      return Settings.defaults;
    }
    if (root is! Map<String, Object?> || !_isInt(root['v'], version)) {
      return Settings.defaults;
    }
    const d = Settings.defaults;
    return Settings(
      language: switch (root['language']) {
        'vi' => AppLanguage.vi,
        'en' => AppLanguage.en,
        _ => d.language,
      },
      appearance: switch (root['appearance']) {
        'system' => Appearance.system,
        'light' => Appearance.light,
        'dark' => Appearance.dark,
        _ => d.appearance,
      },
      autolockMin: _minutes(root['autolockMin'], d.autolockMin),
      sessionMin: _minutes(root['sessionMin'], d.sessionMin),
      clipboardMin: _minutes(root['clipboardMin'], d.clipboardMin),
      gen: _gen(root['gen']),
      lastExportAt: switch (root['lastExportAt']) {
        final int at when at >= 0 => at,
        _ => d.lastExportAt,
      },
    );
  }

  /// JSON UTF-8, không khoảng trắng, thứ tự key như AD-20.
  static List<int> encode(Settings settings) {
    final gen = settings.gen;
    return utf8.encode(
      jsonEncode(<String, Object?>{
        'v': version,
        'language': settings.language?.name,
        'appearance': settings.appearance.name,
        'autolockMin': settings.autolockMin,
        'sessionMin': settings.sessionMin,
        'clipboardMin': settings.clipboardMin,
        'gen': <String, Object?>{
          'length': gen.length,
          'upper': gen.upper,
          'lower': gen.lower,
          'digits': gen.digits,
          'special': gen.special,
        },
        'lastExportAt': settings.lastExportAt,
      }),
    );
  }

  static GenSettings _gen(Object? value) {
    const d = GenSettings.defaults;
    if (value is! Map<String, Object?>) {
      return d;
    }
    return GenSettings(
      length: switch (value['length']) {
        final int n when n >= genLengthMin && n <= genLengthMax => n,
        _ => d.length,
      },
      upper: _bool(value['upper'], d.upper),
      lower: _bool(value['lower'], d.lower),
      digits: _bool(value['digits'], d.digits),
      special: _bool(value['special'], d.special),
    );
  }

  static int _minutes(Object? value, int fallback) =>
      value is int && settingsMinuteChoices.contains(value) ? value : fallback;

  static bool _bool(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  static bool _isInt(Object? value, int expected) =>
      value is int && value == expected;
}
