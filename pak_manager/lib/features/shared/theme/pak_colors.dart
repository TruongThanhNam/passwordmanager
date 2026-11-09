import 'package:cupertino_ui/cupertino_ui.dart';

/// Color token của DESIGN.md (UX-DR1). Mỗi token có cặp light/dark và được
/// resolve theo `CupertinoTheme.brightnessOf` (qua
/// `CupertinoDynamicColor.resolve`).
///
/// Không có token đỏ/destructive hay màu trạng thái (UX-DR2): lỗi, độ mạnh,
/// cảnh báo chỉ là chữ [inkSecondary]/[inkPrimary]; hành động phá hủy dùng
/// [accent]. [pwDigit]/[pwSymbol] chỉ dùng cho ký tự mật khẩu, [sliderFill]
/// chỉ cho slider.
///
/// DESIGN.md ghi hex 8 chữ số là `#RRGGBBAA`; ở đây đã đổi sang `0xAARRGGBB`.
abstract final class PakColors {
  static const surfaceBase = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF000000),
  );
  static const surfaceGrouped = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2F2F7),
    darkColor: Color(0xFF000000),
  );
  static const surfaceRaised = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1C1C1E),
  );
  static const surfaceSheet = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1C1C1E),
  );
  static const surfaceSheetGrouped = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2F2F7),
    darkColor: Color(0xFF1C1C1E),
  );
  static const surfaceSheetCell = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF2C2C2E),
  );
  static const surfaceMuted = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF5F5F5),
    darkColor: Color(0xFF2C2C2E),
  );
  static const surfaceToolbar = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFAFAFA),
    darkColor: Color(0xFF161618),
  );
  static const fillSearch = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE3E3E8),
    darkColor: Color(0xFF1C1C1E),
  );
  static const inkPrimary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF000000),
    darkColor: Color(0xFFFFFFFF),
  );
  static const inkSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF8A8A8E),
    darkColor: Color(0xFF8D8D93),
  );
  static const inkValue = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF666666),
    darkColor: Color(0xFFA1A1A6),
  );
  static const inkSection = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF6D6D72),
    darkColor: Color(0xFF8D8D93),
  );
  static const inkDisabled = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC4C4C6),
    darkColor: Color(0xFF48484A),
  );
  static const inkTabInactive = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF999999),
    darkColor: Color(0xFF8D8D93),
  );
  static const accent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF198470),
    darkColor: Color(0xFF22A085),
  );
  static const accentDisabled = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFA3CEC6),
    darkColor: Color(0xFF0F2E28),
  );
  static const accentTint = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE5F8F2),
    darkColor: Color(0xFF1D3633),
  );
  static const onAccent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFFFFFFFF),
  );
  static const onAccentDisabled = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF7C8C88),
  );
  static const sliderFill = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF2DD1AC),
    darkColor: Color(0xFF2DD1AC),
  );
  static const thumb = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFFFFFFFF),
  );
  static const track = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFCCCCCC),
    darkColor: Color(0xFF39393D),
  );
  static const separator = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC6C6C8),
    darkColor: Color(0xFF38383A),
  );
  static const separatorStrong = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFACACAC),
    darkColor: Color(0xFF545458),
  );
  static const border = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFCCCCCC),
    darkColor: Color(0xFF48484A),
  );
  static const scrim = CupertinoDynamicColor.withBrightness(
    color: Color(0x66000000),
    darkColor: Color(0x99000000),
  );
  static const pwLetter = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF000000),
    darkColor: Color(0xFFFFFFFF),
  );
  static const pwDigit = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF007CC6),
    darkColor: Color(0xFF0A84FF),
  );
  static const pwSymbol = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE58B00),
    darkColor: Color(0xFFFF9F0A),
  );
  static const toastBg = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF2C2C2E),
    darkColor: Color(0xFFE5E5EA),
  );
  static const toastInk = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF000000),
  );

  /// Tên token trong DESIGN.md → màu.
  static const Map<String, CupertinoDynamicColor> all = {
    'surface-base': surfaceBase,
    'surface-grouped': surfaceGrouped,
    'surface-raised': surfaceRaised,
    'surface-sheet': surfaceSheet,
    'surface-sheet-grouped': surfaceSheetGrouped,
    'surface-sheet-cell': surfaceSheetCell,
    'surface-muted': surfaceMuted,
    'surface-toolbar': surfaceToolbar,
    'fill-search': fillSearch,
    'ink-primary': inkPrimary,
    'ink-secondary': inkSecondary,
    'ink-value': inkValue,
    'ink-section': inkSection,
    'ink-disabled': inkDisabled,
    'ink-tab-inactive': inkTabInactive,
    'accent': accent,
    'accent-disabled': accentDisabled,
    'accent-tint': accentTint,
    'on-accent': onAccent,
    'on-accent-disabled': onAccentDisabled,
    'slider-fill': sliderFill,
    'thumb': thumb,
    'track': track,
    'separator': separator,
    'separator-strong': separatorStrong,
    'border': border,
    'scrim': scrim,
    'pw-letter': pwLetter,
    'pw-digit': pwDigit,
    'pw-symbol': pwSymbol,
    'toast-bg': toastBg,
    'toast-ink': toastInk,
  };
}
