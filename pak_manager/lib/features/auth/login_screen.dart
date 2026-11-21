import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/policy/password_policy.dart';
import '../../l10n/app_localizations.dart';
import '../../services/account_service.dart';
import '../../services/vault_session.dart';
import '../shared/content_column.dart';
import '../shared/inline_message.dart';
import '../shared/pak_buttons.dart';
import '../shared/providers.dart';
import '../shared/secret_field.dart';
import '../shared/theme/pak_colors.dart';
import '../shared/theme/pak_spacing.dart';
import '../shared/theme/pak_text_styles.dart';

/// Khoảng từ đáy status bar tới đỉnh tên app (UX-DR31).
const double loginTitleTop = 120;

/// Khoảng từ tên app tới ô mật khẩu (S3) / nút "Tạo tài khoản" (S1).
const double loginTitleToField = 48;

/// Khoảng từ ô mật khẩu (hoặc dòng thông báo) tới nút "Đăng nhập" (S3).
const double loginFieldToSubmit = 24;

/// Thông báo inline dưới ô S3 sau một lần [AccountService.unlock].
enum _UnlockMessage { wrong, corrupt, unavailable }

/// Chu kỳ hỏi lại [AccountService.lockoutRemaining] khi đang chờ.
const Duration lockoutTick = Duration(seconds: 1);

/// `{mm:ss}` của `login.lockout`: làm tròn lên theo giây, mỗi phần 2 chữ số
/// (vừa bắt đầu chờ là `30:00`, giây cuối là `00:01`).
String lockoutClock(Duration remaining) {
  final ms = remaining.inMilliseconds;
  final seconds = ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(seconds ~/ 60)}:${two(seconds % 60)}';
}

/// Màn Login (UX-DR31): nền `surface-base`, không nav-bar, "PAK Manager"
/// large-title căn giữa.
///
/// - S1 ([hasAccount] `false`): chỉ nút "Tạo tài khoản" đúng chỗ ô mật khẩu
///   của S3. Không có "Quên mật khẩu", gợi ý hay câu hỏi bảo mật (FR-10).
///   [unavailable]: nút vô hiệu và `create.unavailable` bên dưới (fail
///   closed).
/// - S3 ([hasAccount] `true`, UX-DR42): ô `SecretField` không placeholder →
///   inline-message → nút "Đăng nhập". Khối thông báo: `login.wrong`/
///   `login.corrupt`/`pw.nonAscii`/`create.unavailable` ở trên,
///   `login.attempts` luôn nằm cuối (UX-DR21, FR-4). Nút vô hiệu khi < 15 ký
///   tự, có ký tự không ASCII (hiện `pw.nonAscii`) hoặc hết lượt thử; chuỗi
///   đó không bao giờ tới `unlock`. Khi đang kiểm tra: spinner, khóa ô và
///   nút.
/// - Đang chờ sau lần sai 5–9 (UX-DR42, FR-4): hỏi
///   [AccountService.lockoutRemaining] khi mở màn và sau mỗi kết quả
///   `unlock` (trừ thành công và `UnlockBusy`). Còn lại > 0 thì ô và nút vô
///   hiệu (ô giữ nội dung), `login.lockout` đếm ngược thay chỗ thông báo
///   trên `login.attempts`; một [Timer] [lockoutTick] hỏi lại, về 0 thì về
///   idle.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    required this.hasAccount,
    this.unavailable = false,
    this.onCreate,
    this.onUnlocked,
  });

  final bool hasAccount;
  final bool unavailable;

  /// Bấm "Tạo tài khoản" (S1).
  final VoidCallback? onCreate;

  /// Mở khóa xong (S3): người nhận sở hữu [VaultSession] và thay cây UI.
  final ValueChanged<VaultSession>? onUnlocked;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  _UnlockMessage? _message;

  /// Thời gian chờ còn lại lần hỏi gần nhất; > 0 = đang chờ.
  Duration _lockout = Duration.zero;

  /// Đánh thức lần hỏi lại đếm ngược; chỉ chạy khi đang chờ.
  Timer? _ticker;

  bool get _lockedOut => _lockout > Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.hasAccount) {
      unawaited(_refreshLockout());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    // `SecretField` (con) đã `clear()` controller khi bị gỡ.
    _password.dispose();
    super.dispose();
  }

  bool _canSubmit() {
    final service = ref.read(accountServiceProvider);
    return service != null &&
        service.attemptsLeft > 0 &&
        !_lockedOut &&
        PasswordPolicy.meetsLoginGate(_password.text);
  }

  /// Hỏi lại thời gian chờ rồi áp lên màn.
  Future<void> _refreshLockout() async {
    final service = ref.read(accountServiceProvider);
    if (service == null) {
      return;
    }
    final remaining = await service.lockoutRemaining();
    if (!mounted) {
      return;
    }
    setState(() => _applyLockout(remaining));
  }

  /// Gọi trong `setState`: đang chờ thì bỏ thông báo trên (dòng
  /// `login.lockout` thay chỗ) và giữ timer chạy; hết chờ thì hủy timer.
  void _applyLockout(Duration remaining) {
    _lockout = remaining;
    if (_lockedOut) {
      _message = null;
      _ticker ??= Timer.periodic(
        lockoutTick,
        (_) => unawaited(_refreshLockout()),
      );
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _onChanged(String _) => setState(() => _message = null);

  Future<void> _submit() async {
    final service = ref.read(accountServiceProvider);
    if (_busy || service == null || !_canSubmit()) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await service.unlock(_password.text);
    if (!mounted) {
      if (result is UnlockSuccess) {
        result.session.lock();
      }
      return;
    }
    final _UnlockMessage? message;
    switch (result) {
      case UnlockSuccess(:final session):
        final onUnlocked = widget.onUnlocked;
        if (onUnlocked == null) {
          session.lock();
          setState(() => _busy = false);
        } else {
          onUnlocked(session);
        }
        return;
      // Lần kiểm tra khác đang chạy: bỏ qua, không thông báo.
      case UnlockBusy():
        setState(() => _busy = false);
        return;
      case UnlockWrongPassword():
        message = _UnlockMessage.wrong;
      case UnlockCorrupt():
        message = _UnlockMessage.corrupt;
      case UnlockUnavailable():
        message = _UnlockMessage.unavailable;
      // Đang chờ: dòng `login.lockout`; hết lượt: dòng `login.attempts`
      // (N = 0) và nút vô hiệu là đủ.
      case UnlockLockedOut():
        message = null;
    }
    // Hỏi thời gian chờ trước khi vẽ để không chớp `login.wrong` rồi mới
    // sang `login.lockout`.
    final remaining = await service.lockoutRemaining();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _message = message;
      _applyLockout(remaining);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      backgroundColor: PakColors.surfaceBase,
      child: ContentColumn(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: loginTitleTop),
              Text(
                l10n.appName,
                textAlign: TextAlign.center,
                style: PakTextStyles.largeTitle.copyWith(
                  color: PakColors.inkPrimary,
                ),
              ),
              const SizedBox(height: loginTitleToField),
              if (widget.hasAccount)
                ..._s3(l10n)
              else ...[
                _row(
                  const ValueKey('row.create'),
                  PakPrimaryButton(
                    label: l10n.loginCreate,
                    onPressed: widget.unavailable ? null : widget.onCreate,
                  ),
                ),
                if (widget.unavailable) InlineMessage(l10n.createUnavailable),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _s3(AppLocalizations l10n) {
    final text = _password.text;
    final nonAscii = !PasswordPolicy.isPrintableAscii(text);
    final locked = _lockedOut;
    final String? message = locked
        ? l10n.loginLockout(lockoutClock(_lockout))
        : switch (_message) {
            _UnlockMessage.wrong => l10n.loginWrong,
            _UnlockMessage.corrupt => l10n.loginCorrupt,
            _UnlockMessage.unavailable => l10n.createUnavailable,
            null => nonAscii ? l10n.pwNonAscii : null,
          };
    final attemptsLeft = ref.read(accountServiceProvider)?.attemptsLeft;
    return [
      _row(
        const ValueKey('row.password'),
        SecretField(
          key: const ValueKey('login.field'),
          controller: _password,
          revealLabel: l10n.pwReveal,
          hideLabel: l10n.pwHide,
          enabled: !_busy && !locked,
          onChanged: _onChanged,
          onSubmitted: (_) => unawaited(_submit()),
        ),
      ),
      if (message != null)
        InlineMessage(
          message,
          key: locked ? const ValueKey('login.lockout') : null,
        ),
      if (attemptsLeft != null)
        InlineMessage(
          l10n.loginAttempts(attemptsLeft),
          key: const ValueKey('login.attempts'),
          top: message == null ? inlineMessageGap : inlineMessageLineGap,
        ),
      const SizedBox(height: loginFieldToSubmit),
      _row(
        const ValueKey('row.submit'),
        PakPrimaryButton(
          label: l10n.loginSubmit,
          busy: _busy,
          onPressed: _canSubmit() ? () => unawaited(_submit()) : null,
        ),
      ),
    ];
  }

  /// Hàng có key cố định: dòng thông báo xuất hiện/biến mất không làm
  /// `Column` dựng lại ô (dựng lại `SecretField` sẽ `clear()` controller).
  static Widget _row(Key key, Widget child) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: PakSpacing.margin),
    child: child,
  );
}
