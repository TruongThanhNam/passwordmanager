import 'dart:async';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/format/settings_codec.dart';
import 'package:pak_manager/core/io/atomic_file_writer.dart';
import 'package:pak_manager/core/model/settings.dart';
import 'package:pak_manager/core/ports/file_sync_port.dart';
import 'package:pak_manager/features/shared/content_column.dart';
import 'package:pak_manager/features/shared/pak_app.dart';
import 'package:pak_manager/features/shared/session_gate.dart';
import 'package:pak_manager/features/shared/theme/pak_colors.dart';
import 'package:pak_manager/l10n/app_localizations.dart';
import 'package:pak_manager/services/settings_store.dart';

class _NoopFileSync implements FileSyncPort {
  @override
  Future<void> fsyncDirectory(String path) async {}
}

/// Timer giả không bao giờ tự chạy: chỉ `flush()` mới ghi.
class _IdleTimer implements Timer {
  bool _active = true;

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

BuildContext _inside(WidgetTester tester) =>
    tester.element(find.byType(ContentColumn));

Future<void> _pumpApp(
  WidgetTester tester, {
  Settings settings = Settings.defaults,
  List<Locale>? deviceLocales,
  Brightness? deviceBrightness,
  int androidSdkInt = 35,
}) async {
  if (deviceLocales != null) {
    tester.platformDispatcher.localesTestValue = deviceLocales;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }
  if (deviceBrightness != null) {
    tester.platformDispatcher.platformBrightnessTestValue = deviceBrightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }
  final store = SettingsStore.inMemory(settings);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: PakApp(settings: store, androidSdkInt: androidSdkInt),
    ),
  );
}

SystemUiOverlayStyle _overlay(WidgetTester tester) => tester
    .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    )
    .value;

void main() {
  group('ngôn ngữ', () {
    test('fr47_resolve_locale_uses_primary_device_locale', () {
      expect(resolveAppLocale(const [Locale('vi', 'VN')]), const Locale('vi'));
      expect(
        resolveAppLocale(const [Locale('vi'), Locale('en')]),
        const Locale('vi'),
      );
      expect(
        resolveAppLocale(const [Locale('fr'), Locale('vi')]),
        const Locale('en'),
      );
      expect(resolveAppLocale(const [Locale('en', 'US')]), const Locale('en'));
      expect(resolveAppLocale(const []), const Locale('en'));
      expect(resolveAppLocale(null), const Locale('en'));
    });

    final cases = <String, (List<Locale>, AppLanguage?, String)>{
      'máy vi_VN, language null': (const [Locale('vi', 'VN')], null, 'vi'),
      'máy [fr, vi], language null': (
        const [Locale('fr'), Locale('vi')],
        null,
        'en',
      ),
      'máy [], language null': (const [], null, 'en'),
      'máy ja, language null': (const [Locale('ja')], null, 'en'),
      'máy vi, language en': (const [Locale('vi')], AppLanguage.en, 'en'),
      'máy en, language vi': (const [Locale('en')], AppLanguage.vi, 'vi'),
    };
    cases.forEach((name, c) {
      testWidgets('fr47_nfr14_app_language: $name', (tester) async {
        await _pumpApp(
          tester,
          deviceLocales: c.$1,
          settings: Settings.defaults.copyWith(language: c.$2),
        );
        final context = _inside(tester);

        expect(Localizations.localeOf(context).languageCode, c.$3);
        expect(AppLocalizations.of(context).localeName, c.$3);
        expect(CupertinoLocalizations.of(context), isNotNull);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('fr47_null_language_follows_device_locale_changes', (
      tester,
    ) async {
      await _pumpApp(tester, deviceLocales: const [Locale('en')]);
      expect(Localizations.localeOf(_inside(tester)).languageCode, 'en');

      tester.platformDispatcher.localesTestValue = const [Locale('vi', 'VN')];
      await tester.pump();
      expect(Localizations.localeOf(_inside(tester)).languageCode, 'vi');
    });

    testWidgets('nfr14_app_title_comes_from_l10n', (tester) async {
      await _pumpApp(tester);

      final title = tester.widget<Title>(find.byType(Title));
      expect(title.title, AppLocalizations.of(_inside(tester)).appName);
      expect(title.title, 'PAK Manager');
    });
  });

  group('giao diện', () {
    testWidgets('nfr13_system_appearance_on_dark_device_uses_dark_tokens', (
      tester,
    ) async {
      await _pumpApp(tester, deviceBrightness: Brightness.dark);
      final context = _inside(tester);

      expect(CupertinoTheme.brightnessOf(context), Brightness.dark);
      expect(
        CupertinoDynamicColor.resolve(
          PakColors.surfaceBase,
          context,
        ).toARGB32(),
        PakColors.surfaceBase.darkColor.toARGB32(),
      );
      final overlay = _overlay(tester);
      expect(overlay.statusBarColor, const Color(0x00000000));
      expect(overlay.systemNavigationBarColor, const Color(0x00000000));
      expect(overlay.statusBarBrightness, Brightness.dark);
      expect(overlay.statusBarIconBrightness, Brightness.light);
      expect(overlay.systemNavigationBarIconBrightness, Brightness.light);
      expect(overlay.systemNavigationBarContrastEnforced, isFalse);
    });

    testWidgets('nfr13_system_appearance_on_light_device_uses_light_tokens', (
      tester,
    ) async {
      await _pumpApp(tester, deviceBrightness: Brightness.light);
      final context = _inside(tester);

      expect(
        CupertinoDynamicColor.resolve(PakColors.accent, context).toARGB32(),
        PakColors.accent.color.toARGB32(),
      );
      final overlay = _overlay(tester);
      expect(overlay.statusBarColor, const Color(0x00000000));
      expect(overlay.systemNavigationBarColor, const Color(0x00000000));
      expect(overlay.statusBarBrightness, Brightness.light);
      expect(overlay.statusBarIconBrightness, Brightness.dark);
      expect(overlay.systemNavigationBarIconBrightness, Brightness.dark);
      expect(overlay.systemNavigationBarContrastEnforced, isFalse);
    });

    testWidgets('fr47_explicit_appearance_ignores_device', (tester) async {
      await _pumpApp(
        tester,
        deviceBrightness: Brightness.dark,
        settings: Settings.defaults.copyWith(appearance: Appearance.light),
      );
      expect(CupertinoTheme.brightnessOf(_inside(tester)), Brightness.light);
      expect(_overlay(tester).statusBarIconBrightness, Brightness.dark);

      await _pumpApp(
        tester,
        deviceBrightness: Brightness.light,
        settings: Settings.defaults.copyWith(appearance: Appearance.dark),
      );
      expect(CupertinoTheme.brightnessOf(_inside(tester)), Brightness.dark);
      expect(_overlay(tester).statusBarIconBrightness, Brightness.light);
    });

    test('nfr13_nav_bar_is_transparent_from_api_29', () {
      for (final brightness in Brightness.values) {
        for (final sdk in [29, 35]) {
          final style = pakSystemUiStyle(brightness, androidSdkInt: sdk);
          expect(style.systemNavigationBarColor, const Color(0x00000000));
          expect(
            style.systemNavigationBarIconBrightness,
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          );
        }
      }
    });

    test('nfr13_nav_bar_uses_surface_base_on_api_26_to_28', () {
      // Edge-to-edge không có tác dụng: thanh trong suốt sẽ lộ nền cửa sổ
      // sáng, nên thanh đặc màu nền app, icon tương phản.
      for (final sdk in [26, 28]) {
        final light = pakSystemUiStyle(Brightness.light, androidSdkInt: sdk);
        expect(light.systemNavigationBarColor, PakColors.surfaceBase.color);
        expect(light.systemNavigationBarIconBrightness, Brightness.dark);

        final dark = pakSystemUiStyle(Brightness.dark, androidSdkInt: sdk);
        expect(dark.systemNavigationBarColor, PakColors.surfaceBase.darkColor);
        expect(dark.systemNavigationBarIconBrightness, Brightness.light);
      }
    });

    test('nfr13_nav_bar_is_black_below_api_26_or_unknown', () {
      // Icon thanh điều hướng luôn trắng dưới API 26; `0` = không rõ.
      for (final brightness in Brightness.values) {
        for (final sdk in [0, 24, 25]) {
          final style = pakSystemUiStyle(brightness, androidSdkInt: sdk);
          expect(style.systemNavigationBarColor, const Color(0xFF000000));
          expect(style.systemNavigationBarIconBrightness, Brightness.light);
          // Thanh trạng thái không đổi theo API.
          expect(style.statusBarColor, const Color(0x00000000));
          expect(
            style.statusBarIconBrightness,
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          );
        }
      }
    });

    testWidgets('nfr13_app_applies_nav_bar_style_for_device_api', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        deviceBrightness: Brightness.dark,
        androidSdkInt: 27,
      );
      final overlay = _overlay(tester);
      expect(overlay.systemNavigationBarColor, PakColors.surfaceBase.darkColor);
      expect(overlay.systemNavigationBarIconBrightness, Brightness.light);
    });

    testWidgets('fr47_store_change_rebuilds_theme_and_locale', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final store = SettingsStore.inMemory();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        ProviderScope(child: PakApp(settings: store, androidSdkInt: 35)),
      );

      store.update(
        (s) =>
            s.copyWith(appearance: Appearance.dark, language: AppLanguage.vi),
      );
      await tester.pump();

      final context = _inside(tester);
      expect(CupertinoTheme.brightnessOf(context), Brightness.dark);
      expect(Localizations.localeOf(context).languageCode, 'vi');
    });
  });

  testWidgets('ad01_text_scale_is_clamped_to_1_3', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpApp(tester);

    final scaler = MediaQuery.textScalerOf(_inside(tester));
    expect(scaler.scale(10), lessThanOrEqualTo(13));
    expect(scaler.scale(10), closeTo(13, 1e-9));
  });

  testWidgets('ad01_home_sits_in_content_column', (tester) async {
    await _pumpApp(tester);

    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.byType(CupertinoPageScaffold), findsOneWidget);
    expect(find.byType(ContentColumn), findsOneWidget);
  });

  testWidgets('ad23_builder_hosts_session_gate_without_app_navigator', (
    tester,
  ) async {
    await _pumpApp(tester);

    // `CupertinoApp` không có `home`: navigator duy nhất là của gate, nằm
    // dưới `SessionGate` (trong `builder`, sau kẹp chữ và AnnotatedRegion).
    expect(find.byType(SessionGate), findsOneWidget);
    expect(find.byType(Navigator), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SessionGate),
        matching: find.byType(Navigator),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byType(SessionGate),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
      findsOneWidget,
    );
  });

  testWidgets('ad01_metrics_change_reapplies_orientation_policy', (
    tester,
  ) async {
    final calls = <Object?>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        calls.add(call.arguments);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    tester.view.display
      ..devicePixelRatio = 3
      ..size = const Size(1170, 2532);
    addTearDown(tester.view.display.reset);

    await _pumpApp(tester);
    expect(calls.last, ['DeviceOrientation.portraitUp']);

    // Máy gập mở ra: màn hình thành tablet.
    tester.view.display.size = const Size(2208, 1768) * 1.5;
    await tester.pump();
    expect(calls.last, hasLength(4));
  });

  testWidgets('fr47_hidden_app_flushes_pending_settings', (tester) async {
    final sandbox = Directory.systemTemp.createTempSync('pak_app_');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final writes = <Settings>[];
    final store = await tester.runAsync(
      () => SettingsStore.load(
        '${sandbox.path}${Platform.pathSeparator}settings',
        AtomicFileWriter(_NoopFileSync()),
        createTimer: (_, _) => _IdleTimer(),
        write: (path, bytes) async {
          writes.add(SettingsCodec.decode(bytes));
          return const AtomicWriteSuccess();
        },
      ),
    );
    addTearDown(store!.dispose);
    await tester.pumpWidget(
      ProviderScope(child: PakApp(settings: store, androidSdkInt: 35)),
    );

    store.update((s) => s.copyWith(autolockMin: 10));
    await tester.pump();
    expect(writes, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    // Store được tạo trong runAsync nên hàng đợi ghi đi qua cả event loop
    // thật lẫn FakeAsync: chạy cả hai (test không tự gọi flush).
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();

    expect(writes, [store.current]);
    expect(store.dirty, isFalse);
    // Đưa app về tiền cảnh cho test sau.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
