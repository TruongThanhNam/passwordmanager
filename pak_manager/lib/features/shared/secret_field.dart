import 'package:cupertino_ui/cupertino_ui.dart';

import 'theme/pak_colors.dart';
import 'theme/pak_radius.dart';
import 'theme/pak_spacing.dart';
import 'theme/pak_text_styles.dart';

/// Mục menu ngữ cảnh được giữ lại trên ô bí mật: dán được, chọn tất cả được;
/// không bao giờ Copy/Cut (AD-14).
const Set<ContextMenuButtonType> secretFieldMenuTypes = {
  ContextMenuButtonType.paste,
  ContextMenuButtonType.selectAll,
};

/// Ô nhập bí mật duy nhất của app (AD-14, NFR-9, UX-DR19): mọi ô mật khẩu
/// dùng widget này, không dùng `CupertinoTextField` trực tiếp.
///
/// - Không autofill (`autofillHints: null`), tắt `autocorrect`,
///   `enableSuggestions`, `enableIMEPersonalizedLearning`.
/// - Menu ngữ cảnh chỉ còn Dán và Chọn tất cả, kể cả khi đang hiện; phím
///   tắt Copy/Cut không làm gì.
/// - Giữ nguyên ký tự không ASCII (bộ gõ Telex/VNI): không lọc phím.
/// - Nút mắt hiện/ẩn; icon là hành động kế tiếp (đang ẩn → mắt, đang hiện →
///   mắt gạch chéo).
/// - `controller.clear()` trong `dispose()`: rời màn là xóa nội dung.
///
/// Dáng `text-field-login` (S1/S2/S3): cao [PakSpacing.buttonHeight], nền
/// `surface-raised`, viền 1px `border`, bo [PakRadius.sm], đệm trái 15.
class SecretField extends StatefulWidget {
  const SecretField({
    super.key,
    required this.controller,
    this.placeholder,
    this.focusNode,
    this.textInputAction = TextInputAction.done,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.revealLabel,
    this.hideLabel,
  });

  /// Do nơi dùng tạo và hủy; [SecretField] xóa nội dung khi bị gỡ.
  final TextEditingController controller;

  final String? placeholder;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// `false` khi đang bận (KDF/ghi): khóa ô và nút mắt.
  final bool enabled;

  /// Nhãn trợ năng của nút mắt (chuỗi ARB của nơi dùng); `null` = không
  /// nhãn.
  final String? revealLabel;
  final String? hideLabel;

  @override
  State<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<SecretField> {
  bool _obscured = true;

  @override
  void dispose() {
    // Con (EditableText) đã bị gỡ trước nên không còn listener của ô.
    widget.controller.clear();
    super.dispose();
  }

  static Widget _contextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final items = [
      for (final item in editableTextState.contextMenuButtonItems)
        if (secretFieldMenuTypes.contains(item.type)) item,
    ];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return CupertinoAdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = CupertinoDynamicColor.resolve(
      widget.enabled ? PakColors.accent : PakColors.inkDisabled,
      context,
    );
    final decoration = BoxDecoration(
      color: PakColors.surfaceRaised,
      border: Border.all(color: PakColors.border),
      borderRadius: BorderRadius.circular(PakRadius.sm),
    );
    final field = CupertinoTextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      autofillHints: null,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      keyboardType: TextInputType.text,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      contextMenuBuilder: _contextMenu,
      maxLines: 1,
      placeholder: widget.placeholder,
      placeholderStyle: PakTextStyles.body.copyWith(
        color: PakColors.inkDisabled,
      ),
      style: PakTextStyles.body.copyWith(color: PakColors.inkPrimary),
      cursorColor: PakColors.accent,
      padding: const EdgeInsets.only(left: 15),
      // Ô khóa (bận) giữ nguyên nền vì decoration là của riêng ô.
      decoration: decoration,
      // Node riêng (container) có action tap: không bị gộp vào node của ô,
      // nên VoiceOver/TalkBack chọn và kích hoạt được nút mắt.
      suffix: Semantics(
        container: true,
        button: true,
        label: _obscured ? widget.revealLabel : widget.hideLabel,
        onTap: widget.enabled
            ? () => setState(() => _obscured = !_obscured)
            : null,
        excludeSemantics: true,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(PakSpacing.touchIcon),
          onPressed: widget.enabled
              ? () => setState(() => _obscured = !_obscured)
              : null,
          child: Icon(
            _obscured ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
            size: 22,
            color: iconColor,
          ),
        ),
      ),
    );
    // Phím tắt Copy/Cut (Ctrl/Cmd+C/X) vẫn chạy khi đang hiện mật khẩu: chặn
    // `CopySelectionTextIntent` (cả copy lẫn cut) để không gì ra clipboard
    // (AD-14). Action của EditableText là overridable nên ancestor thắng.
    return Actions(
      actions: <Type, Action<Intent>>{
        CopySelectionTextIntent: DoNothingAction(),
      },
      child: SizedBox(height: PakSpacing.buttonHeight, child: field),
    );
  }
}
