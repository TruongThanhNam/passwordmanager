import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/model/settings.dart';
import 'package:pak_manager/features/shared/theme/pak_colors.dart';
import 'package:pak_manager/features/shared/theme/pak_elevation.dart';
import 'package:pak_manager/features/shared/theme/pak_radius.dart';
import 'package:pak_manager/features/shared/theme/pak_spacing.dart';
import 'package:pak_manager/features/shared/theme/pak_text_styles.dart';
import 'package:pak_manager/features/shared/theme/pak_theme.dart';

/// DESIGN.md là hợp đồng thị giác; test đọc thẳng YAML front matter của nó.
const _designPath =
    '../_bmad-output/planning-artifacts/ux-designs/'
    'ux-passwordmanager-2026-10-26/DESIGN.md';

/// Dòng `  key: value` (thụt 2) của khối [block] ở cấp 0 trong front matter.
Map<String, String> _yamlBlock(String block) {
  final lines = File(_designPath).readAsLinesSync();
  final start = lines.indexOf('$block:');
  if (start < 0) {
    throw StateError('DESIGN.md thiếu khối $block:');
  }
  final entries = <String, String>{};
  for (final line in lines.skip(start + 1)) {
    if (line.isNotEmpty && !line.startsWith(' ')) {
      break;
    }
    final match = RegExp(r"^  '?([\w-]+)'?:\s*(\S.*)$").firstMatch(line);
    if (match != null) {
      entries[match[1]!] = match[2]!.trim().replaceAll("'", '');
    }
  }
  return entries;
}

/// Khối con của typography: token → {fontSize, fontWeight, lineHeight}.
Map<String, Map<String, double>> _typography() {
  final lines = File(_designPath).readAsLinesSync();
  final start = lines.indexOf('typography:');
  final tokens = <String, Map<String, double>>{};
  String? current;
  for (final line in lines.skip(start + 1)) {
    if (line.isNotEmpty && !line.startsWith(' ')) {
      break;
    }
    final token = RegExp(r'^  ([\w-]+):\s*$').firstMatch(line);
    if (token != null) {
      current = token[1];
      tokens[current!] = {};
      continue;
    }
    final prop = RegExp(
      r"^    (fontSize|fontWeight|lineHeight):\s*'?(\d+)(?:px)?'?\s*$",
    ).firstMatch(line);
    if (prop != null && current != null) {
      tokens[current]![prop[1]!] = double.parse(prop[2]!);
    }
  }
  return tokens;
}

/// `#RRGGBB` / `#RRGGBBAA` của DESIGN → `0xAARRGGBB`.
int _argb(String hex) {
  final digits = hex.substring(1);
  if (digits.length == 6) {
    return 0xFF000000 | int.parse(digits, radix: 16);
  }
  if (digits.length != 8) {
    throw FormatException('hex màu không hợp lệ', hex);
  }
  final rgb = int.parse(digits.substring(0, 6), radix: 16);
  final alpha = int.parse(digits.substring(6), radix: 16);
  return (alpha << 24) | rgb;
}

double _px(String value) => double.parse(value.replaceAll('px', ''));

/// Resolve [colors] trong một cây có `CupertinoTheme` ở [brightness].
Future<Map<String, int>> _resolveAll(
  WidgetTester tester,
  Brightness brightness,
) async {
  final resolved = <String, int>{};
  await tester.pumpWidget(
    CupertinoTheme(
      data: CupertinoThemeData(brightness: brightness),
      child: Builder(
        builder: (context) {
          expect(CupertinoTheme.brightnessOf(context), brightness);
          PakColors.all.forEach((name, color) {
            resolved[name] = CupertinoDynamicColor.resolve(
              color,
              context,
            ).toARGB32();
          });
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return resolved;
}

void main() {
  group('màu', () {
    final yaml = _yamlBlock('colors');
    final light = {
      for (final e in yaml.entries)
        if (!e.key.endsWith('-dark')) e.key: _argb(e.value),
    };
    final dark = {
      for (final e in yaml.entries)
        if (e.key.endsWith('-dark'))
          e.key.substring(0, e.key.length - 5): _argb(e.value),
    };

    test('ux_dr1_design_has_32_tokens_each_with_dark_pair', () {
      expect(light, hasLength(32));
      expect(dark.keys.toSet(), light.keys.toSet());
      expect(PakColors.all.keys.toSet(), light.keys.toSet());
    });

    testWidgets('ux_dr1_tokens_resolve_to_design_light_values', (tester) async {
      expect(await _resolveAll(tester, Brightness.light), light);
    });

    testWidgets('ux_dr1_tokens_resolve_to_design_dark_values', (tester) async {
      expect(await _resolveAll(tester, Brightness.dark), dark);
    });

    test('ux_dr1_scrim_converts_rrggbbaa_to_aarrggbb', () {
      expect(PakColors.scrim.color.toARGB32(), 0x66000000);
      expect(PakColors.scrim.darkColor.toARGB32(), 0x99000000);
    });

    test('ux_dr2_no_red_destructive_or_status_token', () {
      final banned = RegExp(
        'red|destructive|error|success|warning|danger',
        caseSensitive: false,
      );
      for (final name in PakColors.all.keys) {
        expect(name, isNot(matches(banned)));
      }
    });
  });

  group('chữ', () {
    final design = _typography();

    test('ux_dr3_eleven_text_styles_match_design', () {
      expect(design, hasLength(11));
      expect(PakTextStyles.all.keys.toSet(), design.keys.toSet());
      design.forEach((name, spec) {
        final style = PakTextStyles.all[name]!;
        final size = spec['fontSize']!;
        expect(style.fontSize, size, reason: name);
        expect(style.fontWeight?.value, spec['fontWeight'], reason: name);
        expect(
          style.height! * size,
          moreOrLessEquals(spec['lineHeight']!),
          reason: name,
        );
      });
    });

    test('ux_dr3_system_font_family_without_letter_spacing_or_color', () {
      PakTextStyles.all.forEach((name, style) {
        expect(
          style.fontFamily,
          style.fontSize! < 20
              ? 'CupertinoSystemText'
              : 'CupertinoSystemDisplay',
          reason: name,
        );
        expect(style.letterSpacing, isNull, reason: name);
        expect(style.color, isNull, reason: name);
      });
    });
  });

  group('spacing, radius, elevation', () {
    test('ux_dr4_spacing_matches_every_design_key', () {
      final yaml = _yamlBlock('spacing');
      expect(yaml, isNotEmpty);
      expect(PakSpacing.all, {
        for (final e in yaml.entries) e.key: _px(e.value),
      });
    });

    test('ux_dr4_radius_matches_design', () {
      final yaml = _yamlBlock('rounded');
      expect(PakRadius.all, {
        for (final e in yaml.entries) e.key: _px(e.value),
      });
    });

    test('ux_dr5_only_fab_shadow_defined', () {
      expect(PakElevation.fabShadow, const [
        BoxShadow(
          color: Color(0x33000000),
          offset: Offset(0, 2),
          blurRadius: 8,
        ),
      ]);
    });
  });

  group('theme', () {
    test('nfr13_theme_follows_appearance', () {
      expect(pakTheme(Appearance.system).brightness, isNull);
      expect(pakTheme(Appearance.light).brightness, Brightness.light);
      expect(pakTheme(Appearance.dark).brightness, Brightness.dark);
    });

    test('nfr13_theme_uses_accent_surface_and_body_ink', () {
      final theme = pakTheme(Appearance.system);
      expect(theme.primaryColor, PakColors.accent);
      expect(theme.scaffoldBackgroundColor, PakColors.surfaceBase);
      final text = theme.textTheme.textStyle;
      expect(text.color, PakColors.inkPrimary);
      expect(text.fontSize, PakTextStyles.body.fontSize);
      expect(text.fontFamily, PakTextStyles.body.fontFamily);
      expect(text.height, PakTextStyles.body.height);
    });
  });
}
