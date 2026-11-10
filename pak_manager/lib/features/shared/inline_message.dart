import 'package:cupertino_ui/cupertino_ui.dart';

import 'theme/pak_colors.dart';
import 'theme/pak_spacing.dart';
import 'theme/pak_text_styles.dart';

/// Khoảng từ ô/nút tới dòng inline-message đầu tiên (UX-DR21).
const double inlineMessageGap = 6;

/// Khoảng giữa hai dòng inline-message/strength-meter liền nhau (mock S2).
const double inlineMessageLineGap = 2;

/// Thụt của inline-message: thẳng mép chữ trong ô (UX-DR21).
const double inlineMessageInset = PakSpacing.margin + PakSpacing.cellInset;

/// `inline-message` (UX-DR21) và `strength-meter` (UX-DR20): một dòng chữ
/// footnote `ink-secondary`, không icon, không màu trạng thái (UX-DR2).
/// Thụt [inlineMessageInset]; khoảng trên [top] do nơi dùng chọn
/// ([inlineMessageGap] cho dòng đầu, [inlineMessageLineGap] cho dòng sau).
class InlineMessage extends StatelessWidget {
  const InlineMessage(this.text, {super.key, this.top = inlineMessageGap});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        inlineMessageInset,
        top,
        inlineMessageInset,
        0,
      ),
      child: Text(
        text,
        style: PakTextStyles.footnote.copyWith(color: PakColors.inkSecondary),
      ),
    );
  }
}
