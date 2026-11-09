import 'dart:async';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/format/settings_codec.dart';
import 'package:pak_manager/core/io/atomic_file_writer.dart';
import 'package:pak_manager/core/model/settings.dart';
import 'package:pak_manager/core/ports/file_sync_port.dart';
import 'package:pak_manager/features/shared/content_column.dart';
import 'package:pak_manager/features/shared/pak_app.dart';
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
  await tester.pumpWidget(PakApp(settings: store));
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

    testWidgets('fr47_store_change_rebuilds_theme_and_locale', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final store = SettingsStore.inMemory();
      addTearDown(store.dispose);
      await tester.pumpWidget(PakApp(settings: store));

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

  testWidgets('ad1_text_scale_is_clamped_to_1_3', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpApp(tester);

    final scaler = MediaQuery.textScalerOf(_inside(tester));
    expect(scaler.scale(10), lessThanOrEqualTo(13));
    expect(scaler.scale(10), closeTo(13, 1e-9));
  });

  testWidgets('ad1_home_sits_in_content_column', (tester) async {
    await _pumpApp(tester);

    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.byType(CupertinoPageScaffold), findsOneWidget);
    expect(find.byType(ContentColumn), findsOneWidget);
  });

  testWidgets('ad1_metrics_change_reapplies_orientation_policy', (
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
    await tester.pumpWidget(PakApp(settings: store));

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
