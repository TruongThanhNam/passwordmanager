import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/features/shared/pak_buttons.dart';
import 'package:pak_manager/features/shared/theme/pak_colors.dart';
import 'package:pak_manager/features/shared/theme/pak_radius.dart';

Future<void> _pump(WidgetTester tester, Widget button) => tester.pumpWidget(
  CupertinoApp(
    theme: const CupertinoThemeData(brightness: Brightness.light),
    home: CupertinoPageScaffold(
      child: Center(
        child: Padding(padding: const EdgeInsets.all(16), child: button),
      ),
    ),
  ),
);

/// ARGB của màu (màu dynamic đã resolve vẫn là `CupertinoDynamicColor`).
int? _argb(Color? color) => color?.toARGB32();

/// Màu nền nút (CupertinoButton vẽ bằng DecoratedBox).
int? _background(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(CupertinoButton),
      matching: find.byType(DecoratedBox),
    ),
  );
  return _argb(switch (box.decoration) {
    final BoxDecoration d => d.color,
    final ShapeDecoration d => d.color,
    _ => null,
  });
}

void main() {
  testWidgets('ux_dr10_primary_button_normal_state', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      PakPrimaryButton(label: 'Tạo tài khoản', onPressed: () => taps++),
    );

    expect(tester.getSize(find.byType(PakPrimaryButton)).height, 48);
    expect(_background(tester), PakColors.accent.color.toARGB32());
    final text = tester.widget<Text>(find.text('Tạo tài khoản'));
    expect(_argb(text.style?.color), PakColors.onAccent.color.toARGB32());
    expect(text.style?.fontWeight, FontWeight.w600);
    final button = tester.widget<CupertinoButton>(find.byType(CupertinoButton));
    expect(button.borderRadius, BorderRadius.circular(PakRadius.sm));

    await tester.tap(find.byType(PakPrimaryButton));
    expect(taps, 1);
  });

  testWidgets('ux_dr10_primary_button_disabled_state', (tester) async {
    await _pump(
      tester,
      const PakPrimaryButton(label: 'Tạo tài khoản', onPressed: null),
    );

    expect(_background(tester), PakColors.accentDisabled.color.toARGB32());
    final text = tester.widget<Text>(find.text('Tạo tài khoản'));
    expect(
      _argb(text.style?.color),
      PakColors.onAccentDisabled.color.toARGB32(),
    );
    expect(
      tester.widget<CupertinoButton>(find.byType(CupertinoButton)).onPressed,
      isNull,
    );
  });

  testWidgets(
    'ux_dr10_ux_dr30_busy_button_shows_on_accent_spinner_and_blocks',
    (tester) async {
      var taps = 0;
      await _pump(
        tester,
        PakPrimaryButton(
          label: 'Tạo tài khoản',
          busy: true,
          onPressed: () => taps++,
        ),
      );

      // Bận: nền vẫn accent, chữ thay bằng spinner on-accent.
      expect(_background(tester), PakColors.accent.color.toARGB32());
      expect(find.text('Tạo tài khoản'), findsNothing);
      final spinner = tester.widget<CupertinoActivityIndicator>(
        find.byType(CupertinoActivityIndicator),
      );
      expect(_argb(spinner.color), PakColors.onAccent.color.toARGB32());

      await tester.tap(find.byType(PakPrimaryButton));
      await tester.tap(find.byType(PakPrimaryButton));
      expect(taps, 0);
    },
  );

  testWidgets('ux_dr10_primary_button_semantics_tap_only_when_enabled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    SemanticsData data() => tester
        .getSemantics(find.bySemanticsLabel('Tạo tài khoản'))
        .getSemanticsData();

    await _pump(
      tester,
      PakPrimaryButton(label: 'Tạo tài khoản', onPressed: () => taps++),
    );
    expect(data().hasAction(SemanticsAction.tap), isTrue);
    tester.semantics.tap(find.semantics.byLabel('Tạo tài khoản'));
    expect(taps, 1);

    await _pump(
      tester,
      const PakPrimaryButton(label: 'Tạo tài khoản', onPressed: null),
    );
    expect(data().hasAction(SemanticsAction.tap), isFalse);

    await _pump(
      tester,
      PakPrimaryButton(
        label: 'Tạo tài khoản',
        busy: true,
        onPressed: () => taps++,
      ),
    );
    expect(data().hasAction(SemanticsAction.tap), isFalse);
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('ux_dr11_text_button_uses_accent_and_ink_disabled', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      PakTextButton(label: 'Khóa Vault', onPressed: () => taps++),
    );

    var text = tester.widget<Text>(find.text('Khóa Vault'));
    expect(_argb(text.style?.color), PakColors.accent.color.toARGB32());
    expect(text.style?.fontWeight, FontWeight.w400);
    await tester.tap(find.text('Khóa Vault'));
    expect(taps, 1);

    await _pump(
      tester,
      const PakTextButton(label: 'Xóa hết', onPressed: null, emphasis: true),
    );
    text = tester.widget<Text>(find.text('Xóa hết'));
    expect(_argb(text.style?.color), PakColors.inkDisabled.color.toARGB32());
    expect(text.style?.fontWeight, FontWeight.w600);
  });
}
