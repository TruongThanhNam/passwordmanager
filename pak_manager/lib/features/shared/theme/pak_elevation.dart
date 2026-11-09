import 'package:cupertino_ui/cupertino_ui.dart';

/// Quy ước elevation (UX-DR5, DESIGN.md › Elevation & Depth): **phẳng**.
///
/// Phân tầng theo thứ tự ưu tiên:
/// 1. nền khác tông (`surface-raised` trên `surface-grouped`);
/// 2. hairline `separator`;
/// 3. viền 1px `border` (card và nút tròn trong sheet, popup-menu).
///
/// **Không** đổ bóng cho card, nút và popup-menu (popup-menu cũng không có
/// scrim).
///
/// Ngoại lệ có bóng, và chỉ những chỗ này:
/// - núm slider và núm công tắc (bóng mặc định của `cupertino_ui`);
/// - sheet, wheel-picker và alert-dialog nổi trên `scrim` (mặc định của
///   `cupertino_ui`);
/// - FAB: [fabShadow].
///
/// Dark mode phân tầng bằng tông nền (`#000000` → `#1C1C1E` → `#2C2C2E`),
/// không thêm bóng.
abstract final class PakElevation {
  /// Bóng nhẹ của FAB: x 0, y 2, blur 8, đen 20%.
  static const fabShadow = <BoxShadow>[
    BoxShadow(color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 8),
  ];
}
