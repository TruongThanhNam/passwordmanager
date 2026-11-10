import 'package:cupertino_ui/cupertino_ui.dart';

import '../../l10n/app_localizations.dart';
import '../settings/settings_screen.dart';
import 'content_column.dart';
import 'icons/tab_icons.dart';
import 'theme/pak_colors.dart';
import 'theme/pak_spacing.dart';

/// Chiều cao tab bar, không tính home indicator (UX-DR29).
const double pakTabBarHeight = PakSpacing.toolbarHeight;

/// Cây UI sau đăng nhập (AD-23, FR-45): navigator gốc của phiên (nơi
/// `ModalPresenter` mở sheet/dialog ở epic sau) chứa `CupertinoTabScaffold`
/// 3 tab, mỗi tab một `CupertinoTabView` (navigator riêng). Tab mặc định là
/// Quản lý mật khẩu.
///
/// `SessionGate` bọc cây này trong `KeyedSubtree` theo epoch: khóa = thay cả
/// cây, mọi state của phiên bị gỡ.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.navigatorKey});

  /// Key của navigator gốc, để `SessionGate` chuyển nút Back hệ thống.
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _tabs = CupertinoTabController();

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: widget.navigatorKey,
      onGenerateRoute: (settings) => PageRouteBuilder<void>(
        settings: settings,
        pageBuilder: (context, _, _) => _TabShell(controller: _tabs),
      ),
    );
  }
}

class _TabShell extends StatelessWidget {
  const _TabShell({required this.controller});

  final CupertinoTabController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CupertinoTabScaffold(
      controller: controller,
      backgroundColor: PakColors.surfaceBase,
      tabBar: CupertinoTabBar(
        height: pakTabBarHeight,
        iconSize: pakTabIconSize,
        backgroundColor: PakColors.surfaceToolbar,
        activeColor: PakColors.accent,
        inactiveColor: PakColors.inkTabInactive,
        border: const Border(
          top: BorderSide(color: PakColors.separator, width: 0),
        ),
        items: [
          BottomNavigationBarItem(
            icon: const PakTabIcon(PakTabGlyph.key),
            label: l10n.tabCards,
          ),
          BottomNavigationBarItem(
            icon: const PakTabIcon(PakTabGlyph.wand),
            label: l10n.tabGenerator,
          ),
          BottomNavigationBarItem(
            icon: const PakTabIcon(PakTabGlyph.dial),
            label: l10n.tabSettings,
          ),
        ],
      ),
      tabBuilder: (context, index) => CupertinoTabView(
        builder: (context) => switch (index) {
          0 => _TabPage(title: l10n.tabCards),
          1 => _TabPage(title: l10n.generatorTitle),
          _ => const SettingsScreen(),
        },
      ),
    );
  }
}

/// Trang gốc tạm của một tab: chỉ nav-bar (UX-DR29), thân trống. Nội dung
/// thật thêm ở các epic sau (danh sách card ở 3.1, generator ở Epic 4, các
/// tab Cài đặt là `SettingsScreen`).
class _TabPage extends StatelessWidget {
  const _TabPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PakColors.surfaceBase,
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        backgroundColor: PakColors.surfaceBase,
        border: null,
        automaticallyImplyLeading: false,
        automaticBackgroundVisibility: false,
      ),
      child: const ContentColumn(child: SizedBox.shrink()),
    );
  }
}
