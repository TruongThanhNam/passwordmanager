import 'package:cupertino_ui/cupertino_ui.dart';

import 'theme/pak_spacing.dart';

/// Cột nội dung của mọi màn hình (UX-DR7, UX-DR49, AD-1): nằm trong safe area,
/// căn giữa theo chiều ngang, sát mép trên, rộng tối đa
/// [PakSpacing.contentMaxTablet]. Màn hẹp hơn thì [child] rộng hết màn.
///
/// Chỉ cột bị giới hạn; nền do scaffold bên ngoài phủ toàn màn.
class ContentColumn extends StatelessWidget {
  const ContentColumn({super.key, required this.child});

  static const double maxWidth = PakSpacing.contentMaxTablet;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          // Lấp đủ bề ngang được phép, để nội dung không co về bề rộng riêng.
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}
