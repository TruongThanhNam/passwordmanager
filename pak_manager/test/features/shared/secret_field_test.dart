import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/features/shared/secret_field.dart';

/// Gỡ ô rồi hủy [controller] (gọi cuối mỗi test).
Future<void> _finish(
  WidgetTester tester,
  TextEditingController controller,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
}

/// Host có `Overlay` (cho menu ngữ cảnh) và có thể gỡ ô ([show] = false).
Future<void> _pump(
  WidgetTester tester,
  TextEditingController controller, {
  bool show = true,
  bool enabled = true,
}) => tester.pumpWidget(
  CupertinoApp(
    home: CupertinoPageScaffold(
      child: Center(
        child: show
            ? SecretField(controller: controller, enabled: enabled)
            : const SizedBox.shrink(),
      ),
    ),
  ),
);

void main() {
  late TextEditingController controller;

  // Gỡ cây trước khi hủy controller, đúng thứ tự trong app (con trước, cha
  // sau): `addTearDown` của test chạy trước bước dọn cây của flutter_test.
  setUp(() => controller = TextEditingController());

  testWidgets(
    'ad14_nfr9_secret_field_disables_autofill_and_keyboard_learning',
    (tester) async {
      await _pump(tester, controller);

      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.autofillHints, isNull);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.enableIMEPersonalizedLearning, isFalse);
      expect(field.smartDashesType, SmartDashesType.disabled);
      expect(field.smartQuotesType, SmartQuotesType.disabled);

      // Cấu hình thật sự gửi xuống kênh nhập liệu của OS (ô Cupertino là
      // autofill client của EditableText).
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      final config = editable.autofillClient!.textInputConfiguration;
      expect(config.autofillConfiguration.enabled, isFalse);
      expect(config.autocorrect, isFalse);
      expect(config.enableSuggestions, isFalse);
      expect(config.enableIMEPersonalizedLearning, isFalse);
      expect(config.obscureText, isTrue);

      await _finish(tester, controller);
    },
  );

  testWidgets('ad14_context_menu_has_paste_but_no_copy_or_cut', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.hasStrings') {
        return <String, Object?>{'value': true};
      }
      if (call.method == 'Clipboard.getData') {
        return <String, Object?>{'text': 'pasted'};
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await _pump(tester, controller);
    await tester.enterText(find.byType(EditableText), 'fake secret value');
    // Hiện mật khẩu: lúc này Flutter mặc định cho Copy/Cut.
    await tester.tap(find.byIcon(CupertinoIcons.eye));
    await tester.pump();

    final state = tester.state<EditableTextState>(find.byType(EditableText));
    state.userUpdateTextEditingValue(
      controller.value.copyWith(
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        ),
      ),
      SelectionChangedCause.longPress,
    );
    await tester.pump();
    final types = {for (final item in state.contextMenuButtonItems) item.type};
    // Mặc định có Copy/Cut khi đang hiện và đã chọn chữ.
    expect(
      types,
      containsAll(<ContextMenuButtonType>[
        ContextMenuButtonType.copy,
        ContextMenuButtonType.cut,
      ]),
    );

    expect(state.showToolbar(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Cut'), findsNothing);
    expect(secretFieldMenuTypes, {
      ContextMenuButtonType.paste,
      ContextMenuButtonType.selectAll,
    });

    await _finish(tester, controller);
  });

  testWidgets('ad14_copy_and_cut_shortcuts_do_nothing_when_revealed', (
    tester,
  ) async {
    final clipboardWrites = <Object?>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardWrites.add(call.arguments);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await _pump(tester, controller);
    await tester.enterText(find.byType(EditableText), 'fake secret value');
    await tester.tap(find.byIcon(CupertinoIcons.eye));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isFalse,
    );
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    await tester.pump();

    for (final key in [LogicalKeyboardKey.keyC, LogicalKeyboardKey.keyX]) {
      for (final modifier in [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.metaLeft,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(modifier);
        await tester.pump();
      }
    }

    expect(clipboardWrites, isEmpty);
    expect(controller.text, 'fake secret value');

    await _finish(tester, controller);
  });

  testWidgets('ad14_dispose_clears_controller', (tester) async {
    await _pump(tester, controller);
    await tester.enterText(find.byType(EditableText), 'fake secret value');
    expect(controller.text, 'fake secret value');

    await _pump(tester, controller, show: false);

    expect(find.byType(SecretField), findsNothing);
    expect(controller.text, isEmpty);

    await _finish(tester, controller);
  });

  testWidgets('ux_dr19_eye_toggles_obscure_and_shows_next_action', (
    tester,
  ) async {
    await _pump(tester, controller);
    EditableText editable() =>
        tester.widget<EditableText>(find.byType(EditableText));

    // Đang ẩn → icon mắt (hành động kế tiếp: hiện).
    expect(editable().obscureText, isTrue);
    expect(find.byIcon(CupertinoIcons.eye), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.eye));
    await tester.pump();
    expect(editable().obscureText, isFalse);
    expect(find.byIcon(CupertinoIcons.eye_slash), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.eye_slash));
    await tester.pump();
    expect(editable().obscureText, isTrue);

    await _finish(tester, controller);
  });

  testWidgets('ux_dr41_non_ascii_characters_are_kept', (tester) async {
    await _pump(tester, controller);
    await tester.enterText(find.byType(EditableText), 'mậtkhẩu của tôi');

    expect(controller.text, 'mậtkhẩu của tôi');

    await _finish(tester, controller);
  });

  testWidgets('ux_dr30_disabled_field_rejects_input_and_eye', (tester) async {
    await _pump(tester, controller, enabled: false);

    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(field.enabled, isFalse);
    await tester.tap(find.byIcon(CupertinoIcons.eye), warnIfMissed: false);
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );

    await _finish(tester, controller);
  });

  testWidgets('ux_dr19_login_field_is_48_tall', (tester) async {
    await _pump(tester, controller);

    expect(tester.getSize(find.byType(SecretField)).height, 48);

    await _finish(tester, controller);
  });
}
