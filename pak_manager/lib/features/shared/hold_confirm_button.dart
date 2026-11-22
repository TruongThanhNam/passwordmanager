import 'dart:async';
import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';

import 'theme/pak_colors.dart';
import 'theme/pak_spacing.dart';

/// Thời gian phải giữ để xác nhận (UX-DR14).
const Duration holdConfirmDuration = Duration(seconds: 3);

/// Thời gian vòng chạy ngược về 0 khi nhả sớm.
const Duration holdConfirmRewind = Duration(milliseconds: 600);

/// Độ dày vòng tiến trình (UX-DR14).
const double holdRingStroke = 4;

/// Cỡ icon thùng rác giữa nút.
const double holdIconSize = 28;

/// `hold-confirm-button` (UX-DR14): nút tròn [PakSpacing.holdButton] không
/// nền, icon thùng rác `accent` ở giữa, vòng dày [holdRingStroke] quanh nút
/// (nền `track`, phần đã giữ `accent`) chạy theo chiều kim đồng hồ từ 12 giờ.
///
/// - Nhấn giữ: vòng chạy đều 0 → 1 trong [holdConfirmDuration] kể từ lúc
///   nhấn; đủ thì gọi [onConfirmed] đúng một lần. Mỗi lần nhấn bắt đầu từ
///   0, kể cả khi nhấn lại lúc vòng còn đang chạy ngược.
/// - Nhả hoặc hủy chạm trước đó: vòng chạy ngược về 0 trong
///   [holdConfirmRewind], không gọi gì; tap nhanh không làm gì, không thông
///   báo.
/// - Controller bị hủy trong `dispose`: widget bị gỡ giữa lúc giữ thì không
///   bao giờ gọi [onConfirmed].
///
/// Chưa có hành động thay thế cho VoiceOver/TalkBack: nút chỉ mang nhãn
/// [semanticLabel] (xem Design Notes story 2.4).
class HoldConfirmButton extends StatefulWidget {
  const HoldConfirmButton({
    super.key,
    required this.onConfirmed,
    required this.semanticLabel,
  });

  /// Gọi đúng một lần khi giữ đủ [holdConfirmDuration].
  final VoidCallback onConfirmed;

  /// Nhãn trợ năng (chuỗi `erase.hold`).
  final String semanticLabel;

  @override
  State<HoldConfirmButton> createState() => _HoldConfirmButtonState();
}

class _HoldConfirmButtonState extends State<HoldConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Con trỏ đang giữ; các con trỏ khác bị bỏ qua.
  int? _pointer;

  /// Đã xác nhận: không nhận thêm lần giữ nào.
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: holdConfirmDuration,
          reverseDuration: holdConfirmRewind,
          // Reduce Motion/Remove animations không được rút ngắn 3 giây: đây là
          // chốt an toàn của một thao tác xóa không hoàn tác (UX-DR14).
          animationBehavior: AnimationBehavior.preserve,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && !_confirmed) {
            _confirmed = true;
            widget.onConfirmed();
          }
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent event) {
    if (!mounted || _confirmed || _pointer != null) {
      return;
    }
    _pointer = event.pointer;
    // Mỗi lần nhấn chạy lại từ 0 (kể cả khi vòng còn đang lùi): một lần giữ
    // phải là 3 giây liên tục.
    unawaited(_controller.forward(from: 0));
  }

  void _release(PointerEvent event) {
    // Sự kiện nhả có thể tới sau khi widget đã bị gỡ giữa lúc giữ.
    if (!mounted || event.pointer != _pointer) {
      return;
    }
    _pointer = null;
    if (!_confirmed) {
      unawaited(_controller.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoDynamicColor.resolve(PakColors.accent, context);
    final track = CupertinoDynamicColor.resolve(PakColors.track, context);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerUp: _release,
        onPointerCancel: _release,
        child: SizedBox.square(
          dimension: PakSpacing.holdButton,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => CustomPaint(
              key: const ValueKey('hold.ring'),
              painter: HoldRingPainter(
                progress: _controller.value,
                trackColor: track,
                progressColor: accent,
              ),
              child: child,
            ),
            child: Center(
              child: Icon(
                CupertinoIcons.trash,
                size: holdIconSize,
                color: accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vẽ vòng của [HoldConfirmButton]: vòng nền [trackColor] và cung
/// [progressColor] quét `progress` (0–1) vòng theo chiều kim đồng hồ từ 12
/// giờ.
class HoldRingPainter extends CustomPainter {
  const HoldRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  /// 0 = rỗng, 1 = đầy.
  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(holdRingStroke / 2);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = holdRingStroke
        ..color = trackColor,
    );
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = holdRingStroke
          ..color = progressColor,
      );
    }
  }

  @override
  bool shouldRepaint(HoldRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}
