import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/account_service.dart';
import '../../services/vault_session.dart';
import '../auth/create_account_screen.dart';
import '../auth/login_screen.dart';
import 'home_shell.dart';
import 'providers.dart';

/// Cổng phiên (AD-23), đặt trong `CupertinoApp.builder`.
///
/// - Chưa mở khóa: một `Navigator` riêng cho S1/S3 theo kết quả
///   [bootstrapResultProvider]; S2 được push lên bằng `CupertinoPageRoute`.
/// - Có phiên: thay **cả** cây trên bằng [HomeShell] bọc
///   `KeyedSubtree(ValueKey(epoch))`. Mọi màn chưa đăng nhập (và mọi
///   `SecretField`) bị gỡ; khóa ở story 1.8 cũng là thay cây, không push S3
///   lên UI cũ.
///
/// `CupertinoApp` không có navigator riêng (không `home`), nên gate nhận nút
/// Back hệ thống (Android) và chuyển cho navigator đang hiện.
class SessionGate extends ConsumerStatefulWidget {
  const SessionGate({super.key});

  @override
  ConsumerState<SessionGate> createState() => SessionGateState();
}

/// State công khai để test đọc [epoch]/[session].
class SessionGateState extends ConsumerState<SessionGate>
    with WidgetsBindingObserver {
  VaultSession? _session;
  int _epoch = 0;

  /// Navigator gốc của cây đang hiện; tạo mới ở mỗi epoch để không cây nào
  /// giữ lại state của cây trước.
  GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  /// Tăng mỗi lần đổi cây (vào phiên; story 1.8: khóa).
  int get epoch => _epoch;

  /// Phiên hiện tại; `null` khi chưa mở khóa.
  VaultSession? get session => _session;

  void _onCreated(VaultSession session) {
    if (!mounted) {
      session.dispose();
      return;
    }
    setState(() {
      _session?.dispose();
      _session = session;
      _epoch++;
      _navigator = GlobalKey<NavigatorState>();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Back hệ thống đóng tầng trên cùng của navigator đang hiện (S2 → S1);
  /// ở gốc thì để OS xử lý (UX-DR50). Không kiểm `canPop()` trước:
  /// `maybePop` tôn trọng `PopScope` của màn và `NavigatorPopHandler` của
  /// `CupertinoTabView` (lùi trang trong tab), chỉ trả `false` khi không ai
  /// xử lý.
  @override
  Future<bool> didPopRoute() async {
    final navigator = _navigator.currentState;
    if (navigator == null) {
      return false;
    }
    return navigator.maybePop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session?.dispose();
    _session = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session != null && !session.isDisposed) {
      return KeyedSubtree(
        key: ValueKey<int>(_epoch),
        child: HomeShell(navigatorKey: _navigator),
      );
    }
    return KeyedSubtree(
      key: ValueKey<int>(_epoch),
      child: Navigator(
        key: _navigator,
        onGenerateRoute: (settings) => CupertinoPageRoute<void>(
          settings: settings,
          builder: (context) =>
              _loginFor(context, ref.read(bootstrapResultProvider)),
        ),
      ),
    );
  }

  Widget _loginFor(BuildContext context, BootstrapResult result) =>
      switch (result) {
        BootstrapHasAccount() => const LoginScreen(hasAccount: true),
        BootstrapNoAccount() => LoginScreen(
          hasAccount: false,
          onCreate: () => _pushCreate(context),
        ),
        BootstrapUnavailable() => const LoginScreen(
          hasAccount: false,
          unavailable: true,
        ),
      };

  /// Push S2 lên navigator chưa đăng nhập (chuyển cảnh mặc định iOS).
  void _pushCreate(BuildContext context) {
    unawaited(
      Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (context) => CreateAccountScreen(onCreated: _onCreated),
        ),
      ),
    );
  }
}
