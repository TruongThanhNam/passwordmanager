import 'package:cupertino_ui/cupertino_ui.dart';

import 'theme/pak_colors.dart';
import 'theme/pak_radius.dart';
import 'theme/pak_spacing.dart';
import 'theme/pak_text_styles.dart';

/// `button-primary` (UX-DR10): nút đầy rộng hết chiều ngang được cấp, cao
/// [PakSpacing.buttonHeight], bo [PakRadius.sm]. Lề ngoài do nơi dùng đặt.
///
/// Ba trạng thái:
/// - thường: nền `accent`, chữ `on-accent` body-emphasis;
/// - vô hiệu ([onPressed] `null`): nền `accent-disabled`, chữ
///   `on-accent-disabled`;
/// - bận ([busy]): nền `accent`, activity-indicator `on-accent` thay chữ
///   (UX-DR30), không nhận bấm (chặn bấm lặp).
class PakPrimaryButton extends StatelessWidget {
  const PakPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;

  /// `null` = vô hiệu.
  final VoidCallback? onPressed;

  final bool busy;

  /// `true` khi nút nhận bấm.
  bool get enabled => onPressed != null && !busy;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null && !busy;
    final background = CupertinoDynamicColor.resolve(
      disabled ? PakColors.accentDisabled : PakColors.accent,
      context,
    );
    final foreground = CupertinoDynamicColor.resolve(
      disabled ? PakColors.onAccentDisabled : PakColors.onAccent,
      context,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        height: PakSpacing.buttonHeight,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size.fromHeight(PakSpacing.buttonHeight),
          color: background,
          disabledColor: background,
          borderRadius: BorderRadius.circular(PakRadius.sm),
          onPressed: enabled ? onPressed : null,
          child: busy
              ? CupertinoActivityIndicator(color: foreground)
              : Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PakTextStyles.bodyEmphasis.copyWith(color: foreground),
                ),
        ),
      ),
    );
  }
}

/// `button-text` (UX-DR11): chữ `accent` không nền, `ink-disabled` khi vô
/// hiệu. [emphasis] dùng body-emphasis ("Xóa hết", "Lưu").
class PakTextButton extends StatelessWidget {
  const PakTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.emphasis = false,
    this.alignment = Alignment.center,
  });

  final String label;

  /// `null` = vô hiệu.
  final VoidCallback? onPressed;

  final bool emphasis;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final color = CupertinoDynamicColor.resolve(
      onPressed == null ? PakColors.inkDisabled : PakColors.accent,
      context,
    );
    final style = emphasis ? PakTextStyles.bodyEmphasis : PakTextStyles.body;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(PakSpacing.touchIcon, PakSpacing.rowHeight),
      alignment: alignment,
      onPressed: onPressed,
      child: Text(label, style: style.copyWith(color: color)),
    );
  }
}
