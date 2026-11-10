import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/account_service.dart';
import '../../services/session_controller.dart';
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
///   `SecretField`) bị gỡ. Khóa ([SessionController.lock]) cũng là thay cây,
///   luôn về S3, không push S3 lên UI cũ.
///
/// `CupertinoApp` không có navigator riêng (không `home`), nên gate nhận nút
/// Back hệ thống (Android) và chuyển cho navigator đang hiện.
class SessionGate extends ConsumerStatefulWidget {
  const SessionGate({super.key});

  @override
  ConsumerState<SessionGate> createState() => SessionGateState();
}

/// State công khai để test đọc [epoch]/[session]/[controller].
class SessionGateState extends ConsumerState<SessionGate>
    with WidgetsBindingObserver {
  /// Chủ của phiên và epoch (AD-9); gate dựng lại mỗi khi controller báo.
  final SessionController _controller = SessionController();

  /// Kết quả bootstrap giữ cục bộ: [bootstrapResultProvider] chỉ tính một
  /// lần trước `runApp`, nên sau khi vào phiên (kể cả qua S2) gate đặt
  /// [BootstrapHasAccount] để khóa luôn về S3.
  late BootstrapResult _bootstrap;

  /// Navigator gốc của cây đang hiện; tạo mới ở mỗi epoch để không cây nào
  /// giữ lại state của cây trước.
  GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  /// Loại cây đã dựng lần trước (`true` = cây phiên).
  bool _lastInSession = false;

  /// Tăng mỗi lần đổi cây (vào phiên qua tạo/đăng nhập, khóa).
  int get epoch => _controller.epoch;

  /// Phiên hiện tại; `null` khi chưa mở khóa hoặc đã khóa.
  VaultSession? get session => _controller.session;

  /// Bộ điều khiển phiên của gate.
  SessionController get controller => _controller;

  /// Đường vào phiên chung cho tạo tài khoản (S2) và đăng nhập (S3): trao
  /// [session] cho controller (epoch++), cây sau đăng nhập thay cả cây cũ.
  /// Gate đã bị gỡ thì phiên chưa từng được trao, khóa ngay.
  void _enterSession(VaultSession session) {
    if (!mounted) {
      session.lock();
      return;
    }
    _bootstrap = const BootstrapHasAccount();
    _controller.enter(session);
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    setState(() => _navigator = GlobalKey<NavigatorState>());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap = ref.read(bootstrapResultProvider);
    _controller.addListener(_onControllerChanged);
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _controller.session;
    final inSession = session != null && !session.isLocked;
    // Đổi giữa cây phiên và cây đăng nhập (kể cả trước khi controller báo,
    // vd. lúc khóa đang chờ hook clipboard) thì luôn dùng navigator key mới,
    // để NavigatorState của cây phiên không bị chuyển sang cây đăng nhập.
    if (inSession != _lastInSession) {
      _lastInSession = inSession;
      _navigator = GlobalKey<NavigatorState>();
    }
    if (inSession) {
      // Khóa = gỡ cả scope này: mọi provider/State của phiên bị hủy.
      return KeyedSubtree(
        key: ValueKey<int>(epoch),
        child: ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWithValue(_controller),
            vaultSessionProvider.overrideWithValue(session),
          ],
          child: HomeShell(navigatorKey: _navigator),
        ),
      );
    }
    return KeyedSubtree(
      key: ValueKey<int>(epoch),
      child: Navigator(
        key: _navigator,
        onGenerateRoute: (settings) => CupertinoPageRoute<void>(
          settings: settings,
          builder: (context) => _loginFor(context, _bootstrap),
        ),
      ),
    );
  }

  Widget _loginFor(BuildContext context, BootstrapResult result) =>
      switch (result) {
        BootstrapHasAccount() => LoginScreen(
          hasAccount: true,
          onUnlocked: _enterSession,
        ),
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
          builder: (context) => CreateAccountScreen(onCreated: _enterSession),
        ),
      ),
    );
  }
}
