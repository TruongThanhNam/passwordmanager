import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/format/settings_codec.dart';
import 'package:pak_manager/core/model/settings.dart';

const _fixtures = 'test/fixtures/settings/v1';

List<int> _golden(String name) => File('$_fixtures/$name').readAsBytesSync();

/// Bản v1 hợp lệ, khác mặc định ở mọi trường, để thấy rõ trường nào bị thay.
Map<String, Object?> _custom() =>
    jsonDecode(utf8.decode(_golden('custom.json'))) as Map<String, Object?>;

const _customSettings = Settings(
  language: AppLanguage.vi,
  appearance: Appearance.dark,
  autolockMin: 1,
  sessionMin: 5,
  clipboardMin: 10,
  gen: GenSettings(
    length: 99,
    upper: false,
    lower: true,
    digits: false,
    special: true,
  ),
  lastExportAt: 1762300800000,
);

Settings _decodeJson(Object? json) =>
    SettingsCodec.decode(utf8.encode(jsonEncode(json)));

/// Giải mã [_custom] sau khi đặt `[key] = value` (hoặc `gen[key]`).
Settings _withField(String key, Object? value, {bool inGen = false}) {
  final json = _custom();
  if (inGen) {
    (json['gen']! as Map<String, Object?>)[key] = value;
  } else {
    json[key] = value;
  }
  return _decodeJson(json);
}

Settings _withoutField(String key, {bool inGen = false}) {
  final json = _custom();
  if (inGen) {
    (json['gen']! as Map<String, Object?>).remove(key);
  } else {
    json.remove(key);
  }
  return _decodeJson(json);
}

void main() {
  group('golden', () {
    test('fr47_defaults_golden_round_trips_byte_for_byte', () {
      final golden = _golden('defaults.json');

      expect(SettingsCodec.decode(golden), Settings.defaults);
      expect(SettingsCodec.encode(Settings.defaults), golden);
      expect(SettingsCodec.encode(SettingsCodec.decode(golden)), golden);
    });

    test('fr47_custom_golden_reads_every_field_and_round_trips', () {
      final golden = _golden('custom.json');

      expect(SettingsCodec.decode(golden), _customSettings);
      expect(SettingsCodec.encode(_customSettings), golden);
      expect(SettingsCodec.encode(SettingsCodec.decode(golden)), golden);
    });

    test('fr47_encode_uses_ad20_key_order_without_whitespace', () {
      final text = utf8.decode(SettingsCodec.encode(Settings.defaults));

      expect(text, isNot(contains(' ')));
      expect(text, isNot(contains('\n')));
      final keys = RegExp(r'"(\w+)":').allMatches(text).map((m) => m[1]);
      expect(keys, [
        'v',
        'language',
        'appearance',
        'autolockMin',
        'sessionMin',
        'clipboardMin',
        'gen',
        'length',
        'upper',
        'lower',
        'digits',
        'special',
        'lastExportAt',
      ]);
    });

    test('fr47_defaults_match_epic_1_3', () {
      const d = Settings.defaults;

      expect(d.language, isNull);
      expect(d.appearance, Appearance.system);
      expect((d.autolockMin, d.sessionMin, d.clipboardMin), (3, 10, 3));
      expect(d.gen, GenSettings.defaults);
      expect(GenSettings.defaults.length, 16);
      expect(
        [
          d.gen.upper,
          d.gen.lower,
          d.gen.digits,
          d.gen.special,
        ].every((on) => on),
        isTrue,
      );
      expect(d.lastExportAt, isNull);
      expect(d.isValid, isTrue);
    });
  });

  group('trường sai chỉ thay trường đó', () {
    final cases = <String, (Settings, Settings)>{
      'autolockMin 7': (
        _withField('autolockMin', 7),
        _customSettings.copyWith(autolockMin: 3),
      ),
      'autolockMin 3.0': (
        _withField('autolockMin', 3.0),
        _customSettings.copyWith(autolockMin: 3),
      ),
      'sessionMin "5"': (
        _withField('sessionMin', '5'),
        _customSettings.copyWith(sessionMin: 10),
      ),
      'clipboardMin 0': (
        _withField('clipboardMin', 0),
        _customSettings.copyWith(clipboardMin: 3),
      ),
      'appearance 1': (
        _withField('appearance', 1),
        _customSettings.copyWith(appearance: Appearance.system),
      ),
      'appearance "Dark"': (
        _withField('appearance', 'Dark'),
        _customSettings.copyWith(appearance: Appearance.system),
      ),
      'language "fr"': (
        _withField('language', 'fr'),
        _customSettings.copyWith(clearLanguage: true),
      ),
      'language null': (
        _withField('language', null),
        _customSettings.copyWith(clearLanguage: true),
      ),
      'gen.length 100': (
        _withField('length', 100, inGen: true),
        _customSettings.copyWith(gen: _customSettings.gen.copyWith(length: 16)),
      ),
      'gen.upper "x"': (
        _withField('upper', 'x', inGen: true),
        _customSettings.copyWith(
          gen: _customSettings.gen.copyWith(upper: true),
        ),
      ),
      'gen.digits null': (
        _withField('digits', null, inGen: true),
        _customSettings.copyWith(
          gen: _customSettings.gen.copyWith(digits: true),
        ),
      ),
      'lastExportAt -1': (
        _withField('lastExportAt', -1),
        _customSettings.copyWith(clearLastExportAt: true),
      ),
      'lastExportAt 1.5': (
        _withField('lastExportAt', 1.5),
        _customSettings.copyWith(clearLastExportAt: true),
      ),
      'lastExportAt 0': (
        _withField('lastExportAt', 0),
        _customSettings.copyWith(lastExportAt: 0),
      ),
      'thiếu autolockMin': (
        _withoutField('autolockMin'),
        _customSettings.copyWith(autolockMin: 3),
      ),
      'thiếu gen.special': (
        _withoutField('special', inGen: true),
        _customSettings,
      ),
      'thiếu gen.upper': (
        _withoutField('upper', inGen: true),
        _customSettings.copyWith(
          gen: _customSettings.gen.copyWith(upper: true),
        ),
      ),
      'thiếu lastExportAt': (
        _withoutField('lastExportAt'),
        _customSettings.copyWith(clearLastExportAt: true),
      ),
      'key lạ': (_withField('extra', [1, 2]), _customSettings),
    };
    cases.forEach((name, pair) {
      test('fr47_invalid_field_falls_back_alone: $name', () {
        expect(pair.$1, pair.$2);
      });
    });

    test('fr46_minutes_accept_only_1_3_5_10', () {
      for (final minutes in [-1, 0, 2, 4, 6, 9, 11, 15, 60]) {
        expect(
          _withField('sessionMin', minutes).sessionMin,
          10,
          reason: '$minutes',
        );
      }
      for (final minutes in [1, 3, 5, 10]) {
        expect(_withField('sessionMin', minutes).sessionMin, minutes);
      }
    });

    test('fr29_gen_length_bounds_0_2_4_99_and_3_0', () {
      int length(Object? value) =>
          _withField('length', value, inGen: true).gen.length;

      expect(length(0), 16);
      expect(length(2), 16);
      expect(length(3), 16);
      expect(length(4), 4);
      expect(length(99), 99);
      expect(length(100), 16);
      expect(length(16.0), 16);
      expect(length(3.0), 16);
      expect(length(4.0), 16);
    });

    test('fr47_gen_not_an_object_uses_gen_defaults', () {
      for (final gen in [5, 'x', null, true, <Object?>[]]) {
        final decoded = _withField('gen', gen);
        expect(decoded.gen, GenSettings.defaults, reason: '$gen');
        expect(decoded.copyWith(gen: _customSettings.gen), _customSettings);
      }
      expect(_withoutField('gen').gen, GenSettings.defaults);
    });
  });

  group('file hỏng dùng toàn bộ mặc định', () {
    final cases = <String, List<int>>{
      'rỗng': <int>[],
      'không phải UTF-8': [0xFF, 0xFE, 0x7B, 0x7D],
      'không phải JSON': utf8.encode('{"v":1,'),
      'mảng': utf8.encode('[1]'),
      'null': utf8.encode('null'),
      'chuỗi': utf8.encode('"settings"'),
      'thiếu v': utf8.encode('{"autolockMin":1}'),
      'v = 2': utf8.encode('{"v":2,"autolockMin":1}'),
      'v = 1.0': utf8.encode('{"v":1.0,"autolockMin":1}'),
      'v = "1"': utf8.encode('{"v":"1","autolockMin":1}'),
    };
    cases.forEach((name, bytes) {
      test('fr47_corrupt_file_uses_all_defaults: $name', () {
        expect(SettingsCodec.decode(bytes), Settings.defaults);
      });
    });
  });

  group('model', () {
    test('fr47_copy_with_clears_nullable_fields', () {
      expect(_customSettings.copyWith(clearLanguage: true).language, isNull);
      expect(
        _customSettings.copyWith(clearLastExportAt: true).lastExportAt,
        isNull,
      );
      expect(
        Settings.defaults.copyWith(language: AppLanguage.en).language,
        AppLanguage.en,
      );
      expect(_customSettings.copyWith(), _customSettings);
      expect(_customSettings.copyWith().hashCode, _customSettings.hashCode);
    });

    test('fr46_is_valid_follows_codec_domain', () {
      expect(_customSettings.isValid, isTrue);
      expect(Settings.defaults.copyWith(autolockMin: 7).isValid, isFalse);
      expect(Settings.defaults.copyWith(sessionMin: 0).isValid, isFalse);
      expect(Settings.defaults.copyWith(clipboardMin: 2).isValid, isFalse);
      expect(Settings.defaults.copyWith(lastExportAt: -1).isValid, isFalse);
      expect(Settings.defaults.copyWith(lastExportAt: 0).isValid, isTrue);
      for (final (length, valid) in [
        (3, false),
        (4, true),
        (99, true),
        (100, false),
      ]) {
        final settings = Settings.defaults.copyWith(
          gen: GenSettings.defaults.copyWith(length: length),
        );
        expect(settings.isValid, valid, reason: '$length');
      }
    });
  });
}
