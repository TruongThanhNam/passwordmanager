import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/features/shared/content_column.dart';

const _child = Key('child');

Future<Rect> _layout(
  WidgetTester tester,
  Size logical, {
  FakeViewPadding padding = FakeViewPadding.zero,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = logical
    ..padding = padding
    ..viewPadding = padding;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery.fromView(
      view: tester.view,
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: ContentColumn(child: SizedBox(key: _child, height: 40)),
      ),
    ),
  );
  return tester.getRect(find.byKey(_child));
}

void main() {
  testWidgets('ux_dr7_tablet_column_is_672_centered_at_top', (tester) async {
    final rect = await _layout(tester, const Size(1000, 800));

    expect(rect.width, 672);
    expect(rect.left, (1000 - 672) / 2);
    expect(rect.top, 0);
  });

  testWidgets('ux_dr7_phone_column_fills_width', (tester) async {
    final rect = await _layout(tester, const Size(375, 812));

    expect(rect.width, 375);
    expect(rect.left, 0);
    expect(rect.top, 0);
  });

  testWidgets('ux_dr49_column_respects_safe_area', (tester) async {
    final rect = await _layout(
      tester,
      const Size(1000, 800),
      padding: const FakeViewPadding(left: 40, top: 24, right: 40),
    );

    expect(rect.top, 24);
    expect(rect.width, 672);
    // Căn giữa trong vùng an toàn (đối xứng nên vẫn giữa màn).
    expect(rect.center.dx, 500);
  });
}
