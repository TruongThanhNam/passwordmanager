import 'package:cupertino_ui/cupertino_ui.dart';

import '../../../core/model/settings.dart';
import 'pak_colors.dart';
import 'pak_text_styles.dart';

/// Theme gốc của app theo cài đặt giao diện (FR-47, NFR-13).
///
/// [Appearance.system] để `brightness` null: `cupertino_ui` lấy độ sáng của
/// máy, nên app đổi theo khi người dùng đổi chế độ sáng/tối của hệ thống.
CupertinoThemeData pakTheme(Appearance appearance) => CupertinoThemeData(
  brightness: switch (appearance) {
    Appearance.system => null,
    Appearance.light => Brightness.light,
    Appearance.dark => Brightness.dark,
  },
  primaryColor: PakColors.accent,
  scaffoldBackgroundColor: PakColors.surfaceBase,
  textTheme: CupertinoTextThemeData(
    textStyle: PakTextStyles.body.copyWith(color: PakColors.inkPrimary),
    navTitleTextStyle: PakTextStyles.navTitle.copyWith(
      color: PakColors.inkPrimary,
    ),
    // Màu chọn/chưa chọn do `CupertinoTabBar` đặt (UX-DR29).
    tabLabelTextStyle: PakTextStyles.tabLabel.copyWith(
      color: PakColors.inkTabInactive,
    ),
  ),
);
