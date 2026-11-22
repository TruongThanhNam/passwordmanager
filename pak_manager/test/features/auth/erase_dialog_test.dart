import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/model/settings.dart';
import 'package:pak_manager/features/auth/erase_dialog.dart';
import 'package:pak_manager/features/auth/login_screen.dart';
import 'package:pak_manager/features/auth/wiping_screen.dart';
import 'package:pak_manager/features/shared/hold_confirm_button.dart';
import 'package:pak_manager/features/shared/secret_field.dart';
import 'package:pak_manager/features/shared/theme/pak_colors.dart';
import 'package:pak_manager/services/account_service.dart';

import '../../support/account_fakes.dart';

const _erase = 'Xóa & Tạo tài khoản mới';
const _title = 'Xóa toàn bộ dữ liệu?';
const _body =
    'Mọi card, Recent và bản nháp sẽ bị xóa vĩnh viễn. Không thể khôi phục.';
const _hold = 'Giữ 3 giây để xóa';
const _cancel = 'Hủy';

final _dialog = find.byType(EraseDialog);
final _holdButton = find.byType(HoldConfirmButton);
final _ring = find.byKey(const ValueKey('hold.ring'));

const _fullHold = Duration(milliseconds: 3001);

/// S3 với `wipe()` treo; chờ xong lần hỏi `lockoutRemaining` khi mở màn.
Future<FakeAccountService> _pumpS3(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.vi,
}) async {
  final service = FakeAccountService(
    bootstrapResult: const BootstrapHasAccount(),
  );
  await pumpGateApp(
    tester,
    bootstrap: const BootstrapHasAccount(),
    service: service,
    language: language,
  );
  await tester.pump();
  return service;
}

/// Bấm nút xóa ở S3 và chờ S4 hiện hết hiệu ứng mờ.
Future<void> _openDialog(WidgetTester tester, [String label = _erase]) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(eraseDialogTransition * 2);
}

double _progress(WidgetTester tester) =>
    (tester.widget<CustomPaint>(_ring).painter! as HoldRingPainter).progress;

Future<TestGesture> _startHold(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(_holdButton));
  await tester.pump();
  return gesture;
}

void main() {
  testWidgets('ux_dr13_dialog_shows_title_body_ring_label_and_only_cancel', (
    tester,
  ) async {
    await _pumpS3(tester);
    await _openDialog(tester);

    expect(_dialog, findsOneWidget);
    expect(find.text(_title), findsOneWidget);
    expect(find.text(_body), findsOneWidget);
    expect(find.text(_hold), findsOneWidget);
    expect(_holdButton, findsOneWidget);
    // Không ô mật khẩu trong dialog; hàng nút chỉ có "Hủy".
    expect(
      find.descendant(of: _dialog, matching: find.byType(SecretField)),
      findsNothing,
    );
    final buttons = find.descendant(
      of: _dialog,
      matching: find.byType(CupertinoButton),
    );
    expect(buttons, findsOneWidget);
    expect(
      find.descendant(of: buttons, matching: find.text(_cancel)),
      findsOneWidget,
    );
    expect(find.text('Xóa'), findsNothing);
  });

  testWidgets('ux_dr13_dialog_width_270_radius_14_surface_raised_on_scrim', (
    tester,
  ) async {
    await _pumpS3(tester);
    await _openDialog(tester);

    final surface = find
        .descendant(of: _dialog, matching: find.byType(Container))
        .first;
    expect(tester.getSize(surface).width, 270);
    final decoration =
        tester.widget<Container>(surface).decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(14));
    expect(
      decoration.color?.toARGB32(),
      PakColors.surfaceRaised.color.toARGB32(),
    );
    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.dismissible, isFalse);
    expect(barrier.color?.toARGB32(), PakColors.scrim.color.toARGB32());
  });

  testWidgets('ux_dr13_ux_dr14_dialog_spacing_and_text_styles', (tester) async {
    await _pumpS3(tester);
    await _openDialog(tester);

    final body = tester.getRect(find.text(_body));
    final hold = tester.getRect(_holdButton);
    final label = tester.getRect(find.text(_hold));
    final cancel = tester.getRect(
      find.descendant(of: _dialog, matching: find.byType(CupertinoButton)),
    );
    final dialog = tester.getRect(
      find.descendant(of: _dialog, matching: find.byType(Container)).first,
    );
    // Nút cách thân 16, nhãn cách nút 8, hàng nút cao 44 sát đáy dialog.
    expect(hold.top - body.bottom, 16);
    expect(label.top - hold.bottom, 8);
    expect(hold.size, const Size(72, 72));
    expect(cancel.height, 44);
    expect(dialog.bottom - cancel.bottom, 0);
    // Nút giữa dialog.
    expect(hold.center.dx, closeTo(dialog.center.dx, 0.5));

    TextStyle style(String text) => tester.widget<Text>(find.text(text)).style!;
    expect(style(_title).fontSize, 17);
    expect(style(_title).fontWeight, FontWeight.w600);
    expect(
      style(_title).color?.toARGB32(),
      PakColors.inkPrimary.color.toARGB32(),
    );
    expect(style(_body).fontSize, 13);
    expect(
      style(_body).color?.toARGB32(),
      PakColors.inkPrimary.color.toARGB32(),
    );
    expect(style(_hold).fontSize, 13);
    expect(
      style(_hold).color?.toARGB32(),
      PakColors.inkSecondary.color.toARGB32(),
    );
    expect(style(_cancel).fontWeight, FontWeight.w600);
    expect(style(_cancel).color?.toARGB32(), PakColors.accent.color.toARGB32());
  });

  testWidgets('ux_dr13_tap_outside_does_not_close_dialog', (tester) async {
    final service = await _pumpS3(tester);
    await _openDialog(tester);

    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    await tester.pump(eraseDialogTransition * 2);

    expect(_dialog, findsOneWidget);
    expect(service.wipeCalls, 0);
  });

  testWidgets('ux_dr13_cancel_closes_dialog_and_s3_is_unchanged', (
    tester,
  ) async {
    final service = await _pumpS3(tester);
    await tester.enterText(
      find.byKey(const ValueKey('login.field')),
      validPassword,
    );
    await tester.pump();
    await _openDialog(tester);

    await tester.tap(find.text(_cancel));
    await tester.pump();
    await tester.pump(eraseDialogTransition * 2);

    expect(_dialog, findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      tester.widget<SecretField>(find.byType(SecretField)).controller.text,
      validPassword,
    );
    expect(service.wipeCalls, 0);
  });

  testWidgets('ux_dr50_ux_dr13_android_back_closes_dialog_not_s3', (
    tester,
  ) async {
    final service = await _pumpS3(tester);
    await _openDialog(tester);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    await tester.pump(eraseDialogTransition * 2);

    expect(_dialog, findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(service.wipeCalls, 0);
    // Back lần hai: S3 là gốc, gate để OS xử lý, không pop gì.
    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('ux_dr50_ux_dr14_android_back_while_holding_cancels_hold', (
    tester,
  ) async {
    final service = await _pumpS3(tester);
    await _openDialog(tester);
    final gesture = await _startHold(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(_progress(tester), closeTo(2 / 3, 0.02));

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    await tester.pump(eraseDialogTransition * 2);
    expect(_dialog, findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);

    // Ngón tay vẫn đè và thời gian trôi quá 3 giây: không xóa.
    await tester.pump(const Duration(seconds: 5));
    await gesture.up();
    await tester.pump();
    expect(service.wipeCalls, 0);
    expect(find.byType(WipingScreen), findsNothing);
  });

  testWidgets('ux_dr13_cancel_while_holding_closes_without_wipe', (
    tester,
  ) async {
    final service = await _pumpS3(tester);
    await _openDialog(tester);
    final gesture = await _startHold(tester);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text(_cancel));
    await tester.pump();
    await tester.pump(eraseDialogTransition * 2);
    expect(_dialog, findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await gesture.up();
    await tester.pump();
    expect(service.wipeCalls, 0);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('ux_dr14_ux_dr13_full_hold_closes_dialog_and_calls_wipe_once', (
    tester,
  ) async {
    final service = await _pumpS3(tester);
    await _openDialog(tester);
    final gesture = await _startHold(tester);

    await tester.pump(const Duration(seconds: 2));
    expect(_dialog, findsOneWidget);
    expect(service.wipeCalls, 0);

    await tester.pump(_fullHold - const Duration(seconds: 2));
    await tester.pump(eraseDialogTransition * 2);
    await gesture.up();
    await tester.pump();

    expect(_dialog, findsNothing);
    expect(find.byType(WipingScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(service.wipeCalls, 1);
  });

  testWidgets('ux_dr14_early_release_keeps_dialog_and_never_wipes', (
    tester,
  ) async {
    final service = await _pumpS3(tester);
    await _openDialog(tester);
    final gesture = await _startHold(tester);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_progress(tester), closeTo(0.5, 0.02));

    await gesture.up();
    await tester.pump();
    await tester.pump(holdConfirmRewind);

    expect(_progress(tester), 0);
    expect(_dialog, findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(service.wipeCalls, 0);
    expect(find.byType(WipingScreen), findsNothing);
  });

  testWidgets('ux_dr14_quick_tap_in_dialog_does_nothing', (tester) async {
    final service = await _pumpS3(tester);
    await _openDialog(tester);

    await tester.tap(_holdButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(_dialog, findsOneWidget);
    expect(service.wipeCalls, 0);
    expect(find.byType(WipingScreen), findsNothing);
  });

  testWidgets('ux_dr13_en_strings', (tester) async {
    await _pumpS3(tester, language: AppLanguage.en);
    await _openDialog(tester, 'Erase & Create New Account');

    expect(find.text('Erase all data?'), findsOneWidget);
    expect(
      find.text(
        'All cards, recent passwords and drafts will be permanently erased. '
        "This can't be undone.",
      ),
      findsOneWidget,
    );
    expect(find.text('Hold for 3 seconds to erase'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
