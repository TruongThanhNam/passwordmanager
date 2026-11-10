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
enum _UnlockMessage { wrong, corrupt }

/// Màn Login (UX-DR31): nền `surface-base`, không nav-bar, "PAK Manager"
/// large-title căn giữa.
///
/// - S1 ([hasAccount] `false`): chỉ nút "Tạo tài khoản" đúng chỗ ô mật khẩu
///   của S3. Không có "Quên mật khẩu", gợi ý hay câu hỏi bảo mật (FR-10).
///   [unavailable]: nút vô hiệu và `create.unavailable` bên dưới (fail
///   closed).
/// - S3 ([hasAccount] `true`, UX-DR42 phần Epic 1): ô `SecretField` không
///   placeholder → inline-message → nút "Đăng nhập". Nút vô hiệu khi < 15 ký
///   tự hoặc có ký tự không ASCII (hiện `pw.nonAscii`); chuỗi đó không bao
///   giờ tới `unlock`. Khi đang kiểm tra: spinner, khóa ô và nút.
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

  @override
  void dispose() {
    // `SecretField` (con) đã `clear()` controller khi bị gỡ.
    _password.dispose();
    super.dispose();
  }

  bool _canSubmit() =>
      ref.read(accountServiceProvider) != null &&
      PasswordPolicy.meetsLoginGate(_password.text);

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
    switch (result) {
      case UnlockSuccess(:final session):
        final onUnlocked = widget.onUnlocked;
        if (onUnlocked == null) {
          session.lock();
          setState(() => _busy = false);
        } else {
          onUnlocked(session);
        }
      case UnlockWrongPassword():
        setState(() {
          _busy = false;
          _message = _UnlockMessage.wrong;
        });
      case UnlockCorrupt():
        setState(() {
          _busy = false;
          _message = _UnlockMessage.corrupt;
        });
    }
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
    final String? message = switch (_message) {
      _UnlockMessage.wrong => l10n.loginWrong,
      _UnlockMessage.corrupt => l10n.loginCorrupt,
      null => nonAscii ? l10n.pwNonAscii : null,
    };
    return [
      _row(
        const ValueKey('row.password'),
        SecretField(
          key: const ValueKey('login.field'),
          controller: _password,
          revealLabel: l10n.pwReveal,
          hideLabel: l10n.pwHide,
          enabled: !_busy,
          onChanged: _onChanged,
          onSubmitted: (_) => unawaited(_submit()),
        ),
      ),
      if (message != null) InlineMessage(message),
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
