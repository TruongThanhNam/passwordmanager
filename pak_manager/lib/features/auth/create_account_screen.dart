import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/policy/password_policy.dart';
import '../../core/policy/strength_estimator.dart';
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

/// Thời gian chờ sau phím cuối trước khi tính độ mạnh: `zxcvbnm` tốn tới
/// ~99 ms với chuỗi 128 ký tự, nên không chạy ở mỗi phím (deferred 1.5).
const Duration strengthDebounce = Duration(milliseconds: 150);

/// Thông báo inline của ô mật khẩu theo thứ tự ưu tiên UX-DR21: không ASCII
/// → độ dài → phổ biến → lặp/tuần tự → không khớp.
sealed class CreateFieldMessage {
  const CreateFieldMessage();
}

/// Lỗi `PasswordPolicy` của ô đầu.
final class PolicyMessage extends CreateFieldMessage {
  const PolicyMessage(this.check);

  final PasswordCheck check;
}

/// `pw.mismatch` dưới ô nhập lại.
final class MismatchMessage extends CreateFieldMessage {
  const MismatchMessage();
}

/// Thông báo đang áp dụng cho cặp ô ([main], [confirm]); `null` khi không có
/// gì để báo. `pw.mismatch` chỉ khi ô đầu hợp lệ và ô nhập lại đã dài bằng ô
/// đầu (UX-DR21).
CreateFieldMessage? createFieldMessage(
  PasswordCheck check,
  String main,
  String confirm,
) {
  if (main.isEmpty) {
    return null;
  }
  if (check is! PasswordOk) {
    return PolicyMessage(check);
  }
  if (confirm.length >= main.length && confirm != main) {
    return const MismatchMessage();
  }
  return null;
}

/// S2 Tạo tài khoản (UX-DR32), màn push từ S1, chỉ có chevron back.
///
/// `create.warning` → ô `create.field.main` → độ mạnh / thông báo → ô
/// `create.field.confirm` → nút "Tạo tài khoản". Nút chỉ bật khi mật khẩu đạt
/// `PasswordPolicy` và hai ô khớp. Khi đang tạo: spinner trên nút, ô bị khóa,
/// chặn bấm lặp và chặn Back.
class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key, required this.onCreated});

  /// Tạo xong: người nhận sở hữu [VaultSession] và thay cây UI.
  final ValueChanged<VaultSession> onCreated;

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _main = TextEditingController();
  final _confirm = TextEditingController();
  final _confirmFocus = FocusNode();

  Timer? _strengthTimer;
  PasswordStrength? _strength;
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _strengthTimer?.cancel();
    // `SecretField` (con) đã `clear()` hai controller khi bị gỡ.
    _main.dispose();
    _confirm.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _onMainChanged(String value) {
    _strengthTimer?.cancel();
    if (value.isEmpty) {
      _strengthTimer = null;
      setState(() {
        _strength = null;
        _failed = false;
      });
      return;
    }
    _strengthTimer = Timer(strengthDebounce, () {
      if (!mounted) {
        return;
      }
      final estimator = ref.read(strengthEstimatorProvider);
      setState(() => _strength = estimator.estimate(_main.text));
    });
    setState(() => _failed = false);
  }

  void _onConfirmChanged(String _) => setState(() => _failed = false);

  bool _canSubmit(PasswordPolicy? policy) =>
      policy != null &&
      ref.read(accountServiceProvider) != null &&
      policy.check(_main.text) is PasswordOk &&
      _confirm.text == _main.text;

  Future<void> _submit() async {
    final policy = ref.read(passwordPolicyProvider);
    final service = ref.read(accountServiceProvider);
    if (_busy || service == null || !_canSubmit(policy)) {
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    final result = await service.create(_main.text);
    if (!mounted) {
      if (result is CreateSuccess) {
        result.session.dispose();
      }
      return;
    }
    switch (result) {
      case CreateSuccess(:final session):
        widget.onCreated(session);
      case CreateFailure():
        setState(() {
          _busy = false;
          _failed = true;
        });
    }
  }

  String _policyText(AppLocalizations l10n, PasswordCheck check) =>
      switch (check) {
        PasswordNonAscii() => l10n.pwNonAscii,
        PasswordTooShort(:final length) => l10n.pwTooShort(length),
        PasswordTooLong() => l10n.pwTooLong,
        PasswordCommon() => l10n.pwCommon,
        PasswordPattern() => l10n.pwPattern,
        // Không bao giờ thành thông báo (xem [createFieldMessage]).
        PasswordOk() => '',
      };

  String _strengthText(AppLocalizations l10n, PasswordStrength strength) =>
      l10n.pwStrength(switch (strength) {
        PasswordStrength.low => l10n.pwStrengthLow,
        PasswordStrength.medium => l10n.pwStrengthMedium,
        PasswordStrength.high => l10n.pwStrengthHigh,
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final policy = ref.watch(passwordPolicyProvider);
    final main = _main.text;
    final check = policy?.check(main) ?? const PasswordNonAscii();
    final message = policy == null
        ? null
        : createFieldMessage(check, main, _confirm.text);
    final canSubmit = _canSubmit(policy);
    final strength = main.isEmpty ? null : _strength;

    return PopScope(
      canPop: !_busy,
      child: CupertinoPageScaffold(
        backgroundColor: PakColors.surfaceBase,
        navigationBar: CupertinoNavigationBar(
          middle: Text(l10n.loginCreate),
          backgroundColor: PakColors.surfaceBase,
          border: null,
          automaticBackgroundVisibility: false,
          // Chỉ chevron, không tên màn trước (S1 không có tiêu đề).
          previousPageTitle: null,
        ),
        child: ContentColumn(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: PakSpacing.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: PakSpacing.s5),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PakSpacing.margin,
                  ),
                  child: Text(
                    l10n.createWarning,
                    style: PakTextStyles.body.copyWith(
                      color: PakColors.inkPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: PakSpacing.s5),
                _field(
                  const ValueKey('row.main'),
                  SecretField(
                    key: const ValueKey('create.field.main'),
                    controller: _main,
                    placeholder: l10n.createFieldMain,
                    enabled: !_busy,
                    textInputAction: TextInputAction.next,
                    onChanged: _onMainChanged,
                    onSubmitted: (_) => _confirmFocus.requestFocus(),
                  ),
                ),
                // Dòng độ mạnh ở trên, thông báo ở dưới (UX-DR21).
                if (strength != null)
                  InlineMessage(_strengthText(l10n, strength)),
                if (message case PolicyMessage(:final check))
                  InlineMessage(
                    _policyText(l10n, check),
                    top: strength == null
                        ? inlineMessageGap
                        : inlineMessageLineGap,
                  ),
                const SizedBox(height: PakSpacing.s4),
                _field(
                  const ValueKey('row.confirm'),
                  SecretField(
                    key: const ValueKey('create.field.confirm'),
                    controller: _confirm,
                    focusNode: _confirmFocus,
                    placeholder: l10n.createFieldConfirm,
                    enabled: !_busy,
                    onChanged: _onConfirmChanged,
                    onSubmitted: (_) => unawaited(_submit()),
                  ),
                ),
                if (message is MismatchMessage) InlineMessage(l10n.pwMismatch),
                const SizedBox(height: PakSpacing.s5),
                _field(
                  const ValueKey('row.submit'),
                  PakPrimaryButton(
                    label: l10n.loginCreate,
                    busy: _busy,
                    onPressed: canSubmit ? () => unawaited(_submit()) : null,
                  ),
                ),
                if (_failed) InlineMessage(l10n.createFailed),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hàng có key cố định: dòng thông báo xuất hiện/biến mất phía trên
  /// không làm `Column` dựng lại ô (dựng lại `SecretField` sẽ `clear()`
  /// controller đang dùng).
  static Widget _field(Key key, Widget child) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: PakSpacing.margin),
    child: child,
  );
}
