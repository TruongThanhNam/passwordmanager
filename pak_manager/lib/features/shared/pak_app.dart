import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../../core/model/settings.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_store.dart';
import 'content_column.dart';
import 'orientation.dart';
import 'theme/pak_theme.dart';

/// Ngôn ngữ app hỗ trợ; English đứng đầu là ngôn ngữ dự phòng.
const pakSupportedLocales = [Locale('en'), Locale('vi')];

/// Hệ số chữ lớn nhất trong app (AD-1).
const double pakMaxTextScale = 1.3;

/// Chọn locale của app theo locale **chính** (phần tử đầu) của [preferred]
/// (FR-47): tiếng Việt → `vi`; mọi trường hợp khác, kể cả `null`/rỗng hay
/// `[fr, vi]` → `en`.
///
/// Khi `language` đã đặt, `CupertinoApp` truyền `[locale]` vào đây nên kết
/// quả là chính giá trị đó. Dùng trực tiếp làm `localeListResolutionCallback`
/// ([supported] bị bỏ qua).
Locale resolveAppLocale(
  List<Locale>? preferred, [
  Iterable<Locale> supported = pakSupportedLocales,
]) {
  final primary = preferred == null || preferred.isEmpty
      ? null
      : preferred.first;
  return primary?.languageCode == 'vi'
      ? pakSupportedLocales[1]
      : pakSupportedLocales[0];
}

/// Kiểu thanh hệ thống theo độ sáng của theme app: thanh trong suốt, icon
/// tương phản với nền.
SystemUiOverlayStyle pakSystemUiStyle(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final icons = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
    systemNavigationBarColor: const Color(0x00000000),
    // iOS: độ sáng của nền thanh trạng thái; Android: độ sáng của icon.
    statusBarBrightness: brightness,
    statusBarIconBrightness: icons,
    systemNavigationBarIconBrightness: icons,
  );
}

/// Gốc ứng dụng (AD-23): đọc locale và theme từ [settings] ở phía trên
/// `CupertinoApp`.
///
/// Đồng thời ghi ngay cài đặt chưa lưu khi app ẩn và áp lại chính sách hướng
/// màn hình mỗi khi metrics đổi (xoay, gập máy).
class PakApp extends StatefulWidget {
  const PakApp({super.key, required this.settings});

  final SettingsStore settings;

  @override
  State<PakApp> createState() => _PakAppState();
}

class _PakAppState extends State<PakApp> with WidgetsBindingObserver {
  late final AppLifecycleListener _lifecycle;
  FlutterView? _view;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = AppLifecycleListener(
      onHide: () => unawaited(widget.settings.flush()),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final view = View.of(context);
    if (!identical(view, _view)) {
      _view = view;
      applyOrientationPolicy(view);
    }
  }

  @override
  void didChangeMetrics() {
    final view = _view;
    if (view != null) {
      applyOrientationPolicy(view);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final settings = widget.settings.current;
        return CupertinoApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => AppLocalizations.of(context).appName,
          locale: switch (settings.language) {
            null => null,
            AppLanguage.vi => const Locale('vi'),
            AppLanguage.en => const Locale('en'),
          },
          localeListResolutionCallback: resolveAppLocale,
          supportedLocales: pakSupportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalCupertinoLocalizations.delegates,
          ],
          theme: pakTheme(settings.appearance),
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            maxScaleFactor: pakMaxTextScale,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: pakSystemUiStyle(CupertinoTheme.brightnessOf(context)),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          home: const CupertinoPageScaffold(
            child: ContentColumn(child: SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
