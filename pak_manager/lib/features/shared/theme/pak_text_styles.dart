import 'package:cupertino_ui/cupertino_ui.dart';

/// 11 token chữ của DESIGN.md (UX-DR3), font hệ thống (SF Pro trên iOS,
/// Roboto trên Android) qua family của `cupertino_ui`:
/// `CupertinoSystemText` khi cỡ < 20, `CupertinoSystemDisplay` khi cỡ ≥ 20.
///
/// `height` = lineHeight / fontSize. Không đặt `letterSpacing` và `color`:
/// màu lấy từ `PakColors` tại chỗ dùng. Mật khẩu dùng sans thường, không
/// monospace.
abstract final class PakTextStyles {
  static const _text = 'CupertinoSystemText';
  static const _display = 'CupertinoSystemDisplay';

  /// 34/700, line 41. Chỉ tên app trên Login.
  static const largeTitle = TextStyle(
    fontFamily: _display,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 41 / 34,
  );

  /// 17/600, line 22. Tiêu đề nav và page-sheet.
  static const navTitle = TextStyle(
    fontFamily: _text,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 22 / 17,
  );

  /// 17/400, line 22.
  static const body = TextStyle(
    fontFamily: _text,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 22 / 17,
  );

  /// 17/600, line 22. Nút đầy, nhãn chip, tiêu đề card.
  static const bodyEmphasis = TextStyle(
    fontFamily: _text,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 22 / 17,
  );

  /// 16/400, line 21. Thời điểm trong Recent.
  static const callout = TextStyle(
    fontFamily: _text,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 21 / 16,
  );

  /// 15/400, line 20.
  static const subhead = TextStyle(
    fontFamily: _text,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 20 / 15,
  );

  /// 15/600, line 20. Chữ trong toast.
  static const subheadEmphasis = TextStyle(
    fontFamily: _text,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 20 / 15,
  );

  /// 13/400, line 18. Header nhóm, nhãn field, inline-message.
  static const footnote = TextStyle(
    fontFamily: _text,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
  );

  /// 10/500, line 12. Nhãn tab bar.
  static const tabLabel = TextStyle(
    fontFamily: _text,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 12 / 10,
  );

  /// 24/600, line 30. Mật khẩu lớn ở S14 và sheet S11.
  static const passwordDisplay = TextStyle(
    fontFamily: _display,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 30 / 24,
  );

  /// 17/400, line 22. Mật khẩu trong Recent và trên card.
  static const passwordInline = TextStyle(
    fontFamily: _text,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 22 / 17,
  );

  /// Tên token trong DESIGN.md → kiểu chữ.
  static const Map<String, TextStyle> all = {
    'large-title': largeTitle,
    'nav-title': navTitle,
    'body': body,
    'body-emphasis': bodyEmphasis,
    'callout': callout,
    'subhead': subhead,
    'subhead-emphasis': subheadEmphasis,
    'footnote': footnote,
    'tab-label': tabLabel,
    'password-display': passwordDisplay,
    'password-inline': passwordInline,
  };
}
