import 'package:cupertino_ui/cupertino_ui.dart';

import '../../l10n/app_localizations.dart';
import '../shared/content_column.dart';
import '../shared/inline_message.dart';
import '../shared/pak_buttons.dart';
import '../shared/theme/pak_colors.dart';
import '../shared/theme/pak_spacing.dart';
import '../shared/theme/pak_text_styles.dart';

/// Khoảng từ đáy status bar tới đỉnh tên app (UX-DR31).
const double loginTitleTop = 120;

/// Khoảng từ tên app tới ô mật khẩu (S3) / nút "Tạo tài khoản" (S1).
const double loginTitleToField = 48;

/// Màn Login (UX-DR31): nền `surface-base`, không nav-bar, "PAK Manager"
/// large-title căn giữa.
///
/// - S1 ([hasAccount] `false`): chỉ nút "Tạo tài khoản" đúng chỗ ô mật khẩu
///   của S3. Không có "Quên mật khẩu", gợi ý hay câu hỏi bảo mật (FR-10).
///   [unavailable]: nút vô hiệu và `create.unavailable` bên dưới (fail
///   closed).
/// - S3 ([hasAccount] `true`): story 1.6 chỉ có tiêu đề; ô và nút "Đăng
///   nhập" thuộc story 1.7.
class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.hasAccount,
    this.unavailable = false,
    this.onCreate,
  });

  final bool hasAccount;
  final bool unavailable;

  /// Bấm "Tạo tài khoản" (S1).
  final VoidCallback? onCreate;

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
              if (!hasAccount) ...[
                const SizedBox(height: loginTitleToField),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PakSpacing.margin,
                  ),
                  child: PakPrimaryButton(
                    label: l10n.loginCreate,
                    onPressed: unavailable ? null : onCreate,
                  ),
                ),
                if (unavailable) InlineMessage(l10n.createUnavailable),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
