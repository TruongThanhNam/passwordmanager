/// Token bo góc của DESIGN.md (`rounded:`, UX-DR4), đơn vị pt.
abstract final class PakRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double alert = 14;
  static const double lg = 20;

  /// Bo tròn hoàn toàn (viên thuốc, vòng tròn).
  static const double full = 9999;

  /// Key `rounded:` trong DESIGN.md → giá trị.
  static const Map<String, double> all = {
    'sm': sm,
    'md': md,
    'alert': alert,
    'lg': lg,
    'full': full,
  };
}
