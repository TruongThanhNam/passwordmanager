import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/features/shared/hold_confirm_button.dart';
import 'package:pak_manager/features/shared/theme/pak_colors.dart';

final _button = find.byType(HoldConfirmButton);
final _ring = find.byKey(const ValueKey('hold.ring'));

/// Số lần `onConfirmed` được gọi.
class _Counter {
  int confirmed = 0;
}

Future<_Counter> _pump(WidgetTester tester) async {
  final counter = _Counter();
  await tester.pumpWidget(
    CupertinoApp(
      theme: const CupertinoThemeData(brightness: Brightness.light),
      home: CupertinoPageScaffold(
        child: Center(
          child: HoldConfirmButton(
            semanticLabel: 'Giữ 3 giây để xóa',
            onConfirmed: () => counter.confirmed++,
          ),
        ),
      ),
    ),
  );
  return counter;
}

HoldRingPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_ring).painter! as HoldRingPainter;

double _progress(WidgetTester tester) => _painter(tester).progress;

void main() {
  testWidgets('ux_dr14_fr09_reduce_motion_keeps_full_3_second_hold', (
    tester,
  ) async {
    // Reduce Motion/Remove animations: AnimationController mặc định rút còn
    // 5% thời gian, một chạm sẽ xóa vault.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final counter = await _pump(tester);

    final gesture = await tester.startGesture(tester.getCenter(_button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_progress(tester), closeTo(0.5, 0.01));
    expect(counter.confirmed, 0);

    await tester.pump(const Duration(milliseconds: 1501));
    expect(counter.confirmed, 1);
    await gesture.up();
    await tester.pump();
  });

  testWidgets('ux_dr14_shape_72_trash_icon_ring_colors_and_no_background', (
    tester,
  ) async {
    await _pump(tester);

    expect(tester.getSize(_button), const Size(72, 72));
    final icon = tester.widget<Icon>(
      find.descendant(of: _button, matching: find.byType(Icon)),
    );
    expect(icon.icon, CupertinoIcons.trash);
    expect(icon.color?.toARGB32(), PakColors.accent.color.toARGB32());
    // Không nền: không DecoratedBox/ColoredBox trong nút.
    expect(
      find.descendant(of: _button, matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    expect(
      find.descendant(of: _button, matching: find.byType(ColoredBox)),
      findsNothing,
    );
    final painter = _painter(tester);
    expect(painter.progress, 0);
    expect(painter.trackColor.toARGB32(), PakColors.track.color.toARGB32());
    expect(painter.progressColor.toARGB32(), PakColors.accent.color.toARGB32());
  });

  testWidgets('ux_dr14_ring_stroke_4_track_then_accent_clockwise_from_12', (
    tester,
  ) async {
    await _pump(tester);
    final track = PakColors.track.color;
    final accent = PakColors.accent.color;
    const ring = Rect.fromLTWH(2, 2, 68, 68);

    // Chưa giữ: chỉ vòng nền.
    expect(
      tester.renderObject(_ring),
      paints..arc(
        rect: ring,
        startAngle: 0,
        sweepAngle: 2 * math.pi,
        strokeWidth: 4,
        style: PaintingStyle.stroke,
        color: track,
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(_button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    // Nửa vòng: cung accent bắt đầu 12 giờ, quét dương (kim đồng hồ).
    expect(_progress(tester), closeTo(0.5, 0.01));
    expect(
      tester.renderObject(_ring),
      paints
        ..arc(strokeWidth: 4, color: track)
        ..arc(
          rect: ring,
          startAngle: -math.pi / 2,
          strokeWidth: 4,
          style: PaintingStyle.stroke,
          color: accent,
        ),
    );
    await gesture.up();
    await tester.pump(holdConfirmRewind);
  });

  testWidgets('ux_dr14_ring_runs_evenly_from_0_to_1_in_3_seconds', (
    tester,
  ) async {
    final counter = await _pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(_button));
    await tester.pump();
    expect(_progress(tester), 0);

    await tester.pump(const Duration(milliseconds: 750));
    expect(_progress(tester), closeTo(0.25, 0.01));
    await tester.pump(const Duration(milliseconds: 750));
    expect(_progress(tester), closeTo(0.5, 0.01));
    await tester.pump(const Duration(milliseconds: 750));
    expect(_progress(tester), closeTo(0.75, 0.01));
    expect(counter.confirmed, 0);

    // `AnimationController` chỉ báo `completed` khi quá hạn, nên thêm 1 ms.
    await tester.pump(const Duration(milliseconds: 751));
    expect(_progress(tester), 1);
    expect(counter.confirmed, 1);
    await gesture.up();
  });

  testWidgets('ux_dr14_early_release_runs_ring_back_to_zero_without_confirm', (
    tester,
  ) async {
    final counter = await _pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(_button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_progress(tester), closeTo(0.5, 0.01));

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final mid = _progress(tester);
    expect(mid, lessThan(0.5));
    expect(mid, greaterThan(0));

    await tester.pump(holdConfirmRewind);
    expect(_progress(tester), 0);
    // Chờ quá 3 giây vẫn không xác nhận.
    await tester.pump(const Duration(seconds: 4));
    expect(counter.confirmed, 0);
    expect(_progress(tester), 0);
  });

  testWidgets('ux_dr14_quick_tap_does_nothing_and_shows_nothing', (
    tester,
  ) async {
    final counter = await _pump(tester);

    await tester.tap(_button);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(counter.confirmed, 0);
    expect(_progress(tester), 0);
    // Không thông báo nào: nút không có chữ.
    expect(
      find.descendant(of: _button, matching: find.byType(Text)),
      findsNothing,
    );
  });

  testWidgets('ux_dr14_cancelled_touch_runs_ring_back_without_confirm', (
    tester,
  ) async {
    final counter = await _pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(_button));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_progress(tester), greaterThan(0.3));

    await gesture.cancel();
    await tester.pump();
    await tester.pump(holdConfirmRewind);
    await tester.pump(const Duration(seconds: 4));

    expect(_progress(tester), 0);
    expect(counter.confirmed, 0);
  });

  testWidgets('ux_dr14_confirms_exactly_once_even_if_held_longer', (
    tester,
  ) async {
    final counter = await _pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(_button));
    await tester.pump();
    await tester.pump(holdConfirmDuration + const Duration(milliseconds: 1));
    expect(counter.confirmed, 1);

    await tester.pump(const Duration(seconds: 5));
    await gesture.up();
    await tester.pump(const Duration(seconds: 5));
    expect(counter.confirmed, 1);
    expect(_progress(tester), 1);

    // Giữ lại lần nữa cũng không xác nhận lần hai.
    final again = await tester.startGesture(tester.getCenter(_button));
    await tester.pump(const Duration(seconds: 4));
    await again.up();
    await tester.pump();
    expect(counter.confirmed, 1);
  });

  testWidgets('ux_dr14_second_finger_is_ignored_while_holding', (tester) async {
    final counter = await _pump(tester);
    final first = await tester.startGesture(tester.getCenter(_button));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final second = await tester.startGesture(
      tester.getCenter(_button) + const Offset(5, 5),
      pointer: 2,
    );
    await tester.pump();
    await second.up();
    await tester.pump(const Duration(milliseconds: 500));
    // Ngón thứ hai nhả không làm vòng quay ngược.
    expect(_progress(tester), greaterThan(0.45));

    await first.up();
    await tester.pump();
    await tester.pump(holdConfirmRewind);
    expect(counter.confirmed, 0);
    expect(_progress(tester), 0);
  });

  testWidgets(
    'ux_dr14_repress_during_rewind_restarts_from_zero_and_needs_full_3s',
    (tester) async {
      final counter = await _pump(tester);
      final first = await tester.startGesture(tester.getCenter(_button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2900));
      expect(_progress(tester), closeTo(2.9 / 3, 0.01));

      await first.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Vòng đang lùi, chưa về 0.
      expect(_progress(tester), greaterThan(0.5));

      final second = await tester.startGesture(tester.getCenter(_button));
      await tester.pump();
      expect(_progress(tester), 0);
      await tester.pump(const Duration(seconds: 1));
      expect(_progress(tester), closeTo(1 / 3, 0.01));
      expect(counter.confirmed, 0);

      await tester.pump(
        holdConfirmDuration +
            const Duration(milliseconds: 1) -
            const Duration(seconds: 1),
      );
      expect(counter.confirmed, 1);
      await second.up();
      await tester.pump(const Duration(seconds: 5));
      expect(counter.confirmed, 1);
    },
  );

  testWidgets('ux_dr14_dispose_while_holding_never_confirms', (tester) async {
    final counter = await _pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(_button));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    await gesture.up();

    expect(counter.confirmed, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ux_dr14_semantics_label_marks_button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    expect(
      tester.getSemantics(_button),
      matchesSemantics(label: 'Giữ 3 giây để xóa', isButton: true),
    );
    handle.dispose();
  });
}
