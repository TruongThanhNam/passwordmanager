import 'package:cupertino_ui/cupertino_ui.dart';

import '../../l10n/app_localizations.dart';
import '../shared/hold_confirm_button.dart';
import '../shared/pak_buttons.dart';
import '../shared/theme/pak_colors.dart';
import '../shared/theme/pak_radius.dart';
import '../shared/theme/pak_spacing.dart';
import '../shared/theme/pak_text_styles.dart';

/// Bề rộng alert-dialog (UX-DR13).
const double eraseDialogWidth = 270;

/// Đệm trên của tiêu đề và hai bên của chữ trong dialog.
const double eraseDialogTopInset = 20;

/// Khe giữa tiêu đề và thân.
const double eraseTitleToBody = 4;

/// Khe giữa thân và hold-confirm-button (UX-DR14).
const double eraseBodyToHold = PakSpacing.s4;

/// Khe giữa hold-confirm-button và nhãn `erase.hold` (UX-DR14).
const double eraseHoldToLabel = PakSpacing.s2;

/// Khe giữa nhãn `erase.hold` và hairline trên hàng nút.
const double eraseLabelToButtons = PakSpacing.s4;

/// Thời gian mờ dần của dialog và scrim.
const Duration eraseDialogTransition = Duration(milliseconds: 150);

/// Mở S4 trên navigator gần nhất của [context] và trả `true` khi người dùng
/// giữ đủ 3 giây (dialog đã đóng), `false` khi hủy hoặc Back.
///
/// Chạm ra ngoài không đóng. Dialog nằm ngoài cây sau đăng nhập nên tự áp
/// chính sách Back bằng `PopScope`, không qua `ModalPresenter` (Epic 3).
Future<bool> showEraseDialog(BuildContext context) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: false,
    barrierColor: CupertinoDynamicColor.resolve(PakColors.scrim, context),
    transitionDuration: eraseDialogTransition,
    transitionBuilder: (context, animation, secondary, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (context, animation, secondary) => const EraseDialog(),
  );
  return result ?? false;
}

/// S4 (UX-DR13): alert-dialog dáng iOS rộng [eraseDialogWidth], bo
/// [PakRadius.alert], nền `surface-raised`. Tiêu đề `erase.title`
/// (body-emphasis), thân `erase.body` (footnote `ink-primary`),
/// hold-confirm-button, nhãn `erase.hold`, rồi hàng nút chỉ có "Hủy".
///
/// Giữ đủ 3 giây thì đóng với `true`; "Hủy" và Back đóng với `false` (gỡ
/// dialog cũng hủy lần giữ đang chạy). Không yêu cầu mật khẩu.
class EraseDialog extends StatefulWidget {
  const EraseDialog({super.key});

  @override
  State<EraseDialog> createState() => _EraseDialogState();
}

class _EraseDialogState extends State<EraseDialog> {
  /// Đã đóng (xác nhận hoặc hủy): chặn pop lần hai.
  bool _closed = false;

  void _close(bool confirmed) {
    if (_closed || !mounted) {
      return;
    }
    _closed = true;
    Navigator.of(context).pop(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    // Chữ nằm trên nền `surface-raised` đã resolve nên cũng phải resolve, nếu
    // không chế độ tối ra chữ đen trên nền tối.
    final inkPrimary = CupertinoDynamicColor.resolve(
      PakColors.inkPrimary,
      context,
    );
    final inkSecondary = CupertinoDynamicColor.resolve(
      PakColors.inkSecondary,
      context,
    );
    return PopScope(
      canPop: false,
      // Back (kể cả lúc đang giữ) = Hủy: đóng dialog, không xóa gì.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _close(false);
        }
      },
      child: Center(
        child: DefaultTextStyle(
          style: PakTextStyles.body.copyWith(color: inkPrimary),
          child: Container(
            width: eraseDialogWidth,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(
                PakColors.surfaceRaised,
                context,
              ),
              borderRadius: BorderRadius.circular(PakRadius.alert),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PakSpacing.s4,
                    eraseDialogTopInset,
                    PakSpacing.s4,
                    0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.eraseTitle,
                        textAlign: TextAlign.center,
                        style: PakTextStyles.bodyEmphasis.copyWith(
                          color: inkPrimary,
                        ),
                      ),
                      const SizedBox(height: eraseTitleToBody),
                      Text(
                        l10n.eraseBody,
                        textAlign: TextAlign.center,
                        style: PakTextStyles.footnote.copyWith(
                          color: inkPrimary,
                        ),
                      ),
                      const SizedBox(height: eraseBodyToHold),
                      Center(
                        child: HoldConfirmButton(
                          semanticLabel: l10n.eraseHold,
                          onConfirmed: () => _close(true),
                        ),
                      ),
                      const SizedBox(height: eraseHoldToLabel),
                      Text(
                        l10n.eraseHold,
                        textAlign: TextAlign.center,
                        style: PakTextStyles.footnote.copyWith(
                          color: inkSecondary,
                        ),
                      ),
                      const SizedBox(height: eraseLabelToButtons),
                    ],
                  ),
                ),
                ColoredBox(
                  color: CupertinoDynamicColor.resolve(
                    PakColors.separator,
                    context,
                  ),
                  child: SizedBox(height: hairline),
                ),
                SizedBox(
                  height: PakSpacing.rowHeight,
                  child: PakTextButton(
                    label: l10n.commonCancel,
                    emphasis: true,
                    onPressed: () => _close(false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
