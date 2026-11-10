import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../../core/model/settings.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_store.dart';
import 'orientation.dart';
import 'session_gate.dart';
import 'theme/pak_colors.dart';
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
      ? const Locale('vi')
      : const Locale('en');
}

/// API Android thấp nhất mà `SystemUiMode.edgeToEdge` có tác dụng: từ đây app
/// vẽ sau thanh điều hướng nên thanh trong suốt lộ nền app.
const pakEdgeToEdgeMinSdk = 29;

/// API Android thấp nhất tôn trọng `systemNavigationBarIconBrightness`.
const pakNavIconBrightnessMinSdk = 26;

/// Kiểu thanh hệ thống theo độ sáng của theme app và API Android của máy.
///
/// Thanh trạng thái luôn trong suốt, icon tương phản với nền. Thanh điều
/// hướng theo [androidSdkInt] (`0` = iOS hoặc không đọc được):
/// - ≥ [pakEdgeToEdgeMinSdk]: trong suốt, lộ nền app.
/// - ≥ [pakNavIconBrightnessMinSdk]: app không vẽ sau thanh, nên thanh trong
///   suốt sẽ lộ nền cửa sổ (`Theme.Light`) thay vì nền app. Vì vậy thanh đặc
///   màu `surface-base` của theme app.
/// - thấp hơn: icon luôn trắng nên thanh đặc màu đen. iOS bỏ qua các trường
///   thanh điều hướng.
SystemUiOverlayStyle pakSystemUiStyle(
  Brightness brightness, {
  required int androidSdkInt,
}) {
  final dark = brightness == Brightness.dark;
  final icons = dark ? Brightness.light : Brightness.dark;
  final (navColor, navIcons) = switch (androidSdkInt) {
    >= pakEdgeToEdgeMinSdk => (const Color(0x00000000), icons),
    >= pakNavIconBrightnessMinSdk => (
      dark ? PakColors.surfaceBase.darkColor : PakColors.surfaceBase.color,
      icons,
    ),
    _ => (const Color(0xFF000000), Brightness.light),
  };
  return SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
    systemNavigationBarColor: navColor,
    // iOS: độ sáng của nền thanh trạng thái; Android: độ sáng của icon.
    statusBarBrightness: brightness,
    statusBarIconBrightness: icons,
    systemNavigationBarIconBrightness: navIcons,
    // Android 10+: không phủ lớp mờ lên thanh điều hướng trong suốt.
    systemNavigationBarContrastEnforced: false,
  );
}

/// Gốc ứng dụng (AD-23): đọc locale và theme từ [settings] ở phía trên
/// `CupertinoApp`; `CupertinoApp.builder` chứa `SessionGate`. Cần một
/// `ProviderScope` phía trên (xem `main.dart`).
///
/// Đồng thời ghi ngay cài đặt chưa lưu khi app ẩn và áp lại chính sách hướng
/// màn hình mỗi khi metrics đổi (xoay, gập máy).
class PakApp extends StatefulWidget {
  const PakApp({
    super.key,
    required this.settings,
    required this.androidSdkInt,
  });

  final SettingsStore settings;

  /// API Android của máy (`0` = iOS hoặc không đọc được), xem
  /// [pakSystemUiStyle].
  final int androidSdkInt;

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
          builder: (context, _) => MediaQuery.withClampedTextScaling(
            maxScaleFactor: pakMaxTextScale,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: pakSystemUiStyle(
                CupertinoTheme.brightnessOf(context),
                androidSdkInt: widget.androidSdkInt,
              ),
              // Không có `home`: gate tự quản navigator của S1–S3 và của cây
              // sau đăng nhập (AD-23), nên `child` luôn `null` ở đây.
              child: const SessionGate(),
            ),
          ),
        );
      },
    );
  }
}
