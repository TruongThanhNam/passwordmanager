import 'dart:math' as math show cos, pi, sin;

import 'package:cupertino_ui/cupertino_ui.dart';

import '../theme/pak_colors.dart';

/// Cỡ icon trên tab bar (UX-DR6).
const double pakTabIconSize = 26;

/// Hình của ba icon tab (UX-DR6): glyph không có trong `CupertinoIcons` nên
/// vẽ bằng `CustomPainter`, nét mảnh.
enum PakTabGlyph {
  /// Chìa khóa: tab Quản lý mật khẩu.
  key,

  /// Đũa phép có tia sáng: tab Tạo mật khẩu.
  wand,

  /// Núm xoay có vành răng: tab Cài đặt.
  dial,
}

/// Icon tab vẽ theo màu và cỡ của `IconTheme` gần nhất (tab bar đặt màu
/// chọn/chưa chọn qua `IconTheme`); cỡ mặc định [pakTabIconSize].
class PakTabIcon extends StatelessWidget {
  const PakTabIcon(this.glyph, {super.key});

  final PakTabGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? pakTabIconSize;
    final color = CupertinoDynamicColor.resolve(
      theme.color ?? PakColors.inkTabInactive,
      context,
    );
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: PakTabIconPainter(glyph, color)),
    );
  }
}

/// Painter của [PakTabIcon]; vẽ trên lưới 26×26 rồi co giãn theo `size`.
class PakTabIconPainter extends CustomPainter {
  const PakTabIconPainter(this.glyph, this.color);

  final PakTabGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / pakTabIconSize;
    canvas
      ..save()
      ..scale(scale);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (glyph) {
      case PakTabGlyph.key:
        _key(canvas, stroke);
      case PakTabGlyph.wand:
        _wand(canvas, stroke);
      case PakTabGlyph.dial:
        _dial(canvas, stroke);
    }
    canvas.restore();
  }

  /// Vòng cầm tròn bên trái, thân ngang, hai răng ở đuôi.
  static void _key(Canvas canvas, Paint stroke) {
    canvas
      ..drawCircle(const Offset(7.5, 13), 4.8, stroke)
      ..drawCircle(const Offset(7.5, 13), 1.4, stroke)
      ..drawPath(
        Path()
          ..moveTo(12.3, 13)
          ..lineTo(23, 13)
          ..moveTo(19.5, 13)
          ..lineTo(19.5, 16.5)
          ..moveTo(22.5, 13)
          ..lineTo(22.5, 17.5),
        stroke,
      );
  }

  /// Đũa chéo từ góc dưới trái, ngôi sao bốn cánh và hai tia nhỏ ở đầu đũa.
  static void _wand(Canvas canvas, Paint stroke) {
    canvas
      ..drawLine(const Offset(3.5, 22.5), const Offset(15.5, 10.5), stroke)
      ..drawLine(const Offset(13.5, 12.5), const Offset(15.5, 14.5), stroke)
      ..drawPath(_star(const Offset(19.5, 6.5), 3.6, 1.0), stroke)
      ..drawLine(const Offset(9, 4), const Offset(9, 6.5), stroke)
      ..drawLine(const Offset(7.75, 5.25), const Offset(10.25, 5.25), stroke)
      ..drawLine(const Offset(22, 14), const Offset(22, 16.5), stroke)
      ..drawLine(
        const Offset(20.75, 15.25),
        const Offset(23.25, 15.25),
        stroke,
      );
  }

  /// Vành răng (12 răng) quanh núm tròn có vạch chỉ.
  static void _dial(Canvas canvas, Paint stroke) {
    const center = Offset(13, 13);
    const teeth = 12;
    final rim = Path();
    for (var i = 0; i < teeth * 2; i++) {
      final a0 = (i / (teeth * 2)) * 2 * math.pi;
      final a1 = ((i + 1) / (teeth * 2)) * 2 * math.pi;
      final r = i.isEven ? 11.0 : 9.6;
      final p0 = center + Offset(math.cos(a0) * r, math.sin(a0) * r);
      final p1 = center + Offset(math.cos(a1) * r, math.sin(a1) * r);
      if (i == 0) {
        rim.moveTo(p0.dx, p0.dy);
      } else {
        rim.lineTo(p0.dx, p0.dy);
      }
      rim.lineTo(p1.dx, p1.dy);
    }
    rim.close();
    canvas
      ..drawPath(rim, stroke)
      ..drawCircle(center, 5.5, stroke)
      ..drawLine(center, const Offset(13, 8.8), stroke);
  }

  /// Ngôi sao bốn cánh tâm [c], bán kính ngoài [r], trong [inner].
  static Path _star(Offset c, double r, double inner) => Path()
    ..moveTo(c.dx, c.dy - r)
    ..lineTo(c.dx + inner, c.dy - inner)
    ..lineTo(c.dx + r, c.dy)
    ..lineTo(c.dx + inner, c.dy + inner)
    ..lineTo(c.dx, c.dy + r)
    ..lineTo(c.dx - inner, c.dy + inner)
    ..lineTo(c.dx - r, c.dy)
    ..lineTo(c.dx - inner, c.dy - inner)
    ..close();

  @override
  bool shouldRepaint(PakTabIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
