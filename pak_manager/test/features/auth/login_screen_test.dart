import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/model/settings.dart';
import 'package:pak_manager/features/auth/login_screen.dart';
import 'package:pak_manager/features/shared/pak_buttons.dart';
import 'package:pak_manager/features/shared/secret_field.dart';
import 'package:pak_manager/services/account_service.dart';

import '../../support/account_fakes.dart';

const _wrong = 'Sai mật khẩu.';
const _corrupt =
    'Dữ liệu bị hỏng — Mật khẩu đúng nhưng không đọc được dữ liệu. Bạn có thể '
    'dùng "Xóa & Tạo tài khoản mới" rồi import lại từ file export.';
const _nonAscii =
    'Chỉ dùng chữ không dấu, số, ký hiệu và khoảng trắng. Chữ có dấu có thể '
    'bị bàn phím ghi khác đi và khiến bạn không đăng nhập được.';

const _unavailable = 'Không mở được dữ liệu của app. Hãy khởi động lại app.';

String _attempts(int n) => 'Còn $n lần thử trước khi dữ liệu bị xóa.';

final _field = find.byKey(const ValueKey('login.field'));

Future<FakeAccountService> _pumpS3(
  WidgetTester tester, {
  int attemptsLeft = 10,
}) async {
  final service = FakeAccountService(
    bootstrapResult: const BootstrapHasAccount(),
  )..attemptsLeft = attemptsLeft;
  await pumpGateApp(
    tester,
    bootstrap: const BootstrapHasAccount(),
    service: service,
  );
  return service;
}

PakPrimaryButton _button(WidgetTester tester) =>
    tester.widget<PakPrimaryButton>(find.byType(PakPrimaryButton));

SecretField _secret(WidgetTester tester) =>
    tester.widget<SecretField>(find.byType(SecretField));

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await tester.pump();
}

void main() {
  testWidgets(
    'fr03_ux_dr31_s3_has_title_field_without_placeholder_and_button',
    (tester) async {
      await _pumpS3(tester);

      expect(find.text('PAK Manager'), findsOneWidget);
      expect(find.byType(SecretField), findsOneWidget);
      expect(_secret(tester).placeholder, isNull);
      expect(find.byType(PakPrimaryButton), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Tạo tài khoản'), findsNothing);
      // Không "Quên mật khẩu", gợi ý hay nút nào khác ngoài nút mắt.
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      expect(texts, ['PAK Manager', _attempts(10), 'Đăng nhập']);
    },
  );

  testWidgets('ux_dr31_s3_spacing_48_field_24_button', (tester) async {
    await _pumpS3(tester);

    final title = tester.getRect(find.text('PAK Manager'));
    final field = tester.getRect(_field);
    final attempts = tester.getRect(find.text(_attempts(10)));
    final button = tester.getRect(find.byType(PakPrimaryButton));
    expect(field.top - title.bottom, 48);
    // Dòng số lần thử luôn có: cách ô 6, nút cách 24 dưới nó.
    expect(attempts.top - field.bottom, 6);
    expect(button.top - attempts.bottom, 24);

    // Có thông báo: cách ô 6, dòng số lần thử cách 2 dưới thông báo, nút
    // vẫn cách 24 dưới dòng cuối.
    await _type(tester, 'mậtkhẩu dài hơn mười lăm');
    final message = tester.getRect(find.text(_nonAscii));
    final field2 = tester.getRect(_field);
    final attempts2 = tester.getRect(find.text(_attempts(10)));
    final button2 = tester.getRect(find.byType(PakPrimaryButton));
    expect(message.top - field2.bottom, 6);
    expect(attempts2.top - message.bottom, 2);
    expect(button2.top - attempts2.bottom, 24);
  });

  testWidgets('fr03_short_password_disables_button_and_never_unlocks', (
    tester,
  ) async {
    final service = await _pumpS3(tester);
    expect(_button(tester).onPressed, isNull);

    await _type(tester, 'a' * 14);
    expect(_button(tester).onPressed, isNull);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(service.unlockCalls, isEmpty);
    // Không kiểm luật khác ở S3: không thông báo độ dài.
    expect(find.textContaining('15'), findsNothing);

    await _type(tester, 'a' * 15);
    expect(_button(tester).onPressed, isNotNull);
  });

  testWidgets('fr02_fr03_non_ascii_shows_message_and_never_unlocks', (
    tester,
  ) async {
    final service = await _pumpS3(tester);

    await _type(tester, 'mậtkhẩu dài hơn mười lăm');
    expect(find.text(_nonAscii), findsOneWidget);
    expect(_button(tester).onPressed, isNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(service.unlockCalls, isEmpty);

    await _type(tester, 'matkhau dai hon muoi lam');
    expect(find.text(_nonAscii), findsNothing);
    expect(_button(tester).onPressed, isNotNull);
  });

  testWidgets('fr03_no_blocklist_or_pattern_check_on_s3', (tester) async {
    final service = await _pumpS3(tester);

    // Lặp một ký tự: S2 từ chối, S3 vẫn gửi (chỉ cổng 15 + ASCII).
    await _type(tester, 'a' * 15);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();
    expect(service.unlockCalls, ['a' * 15]);
    service.completeUnlock(const UnlockWrongPassword());
    await tester.pump();
  });

  testWidgets('ux_dr42_busy_spinner_locks_field_and_unlocks_once', (
    tester,
  ) async {
    final service = await _pumpS3(tester);
    await _type(tester, validPassword);

    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();
    expect(_button(tester).busy, isTrue);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(_secret(tester).enabled, isFalse);

    await tester.tap(find.byType(PakPrimaryButton));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(service.unlockCalls, [validPassword]);

    service.completeUnlock(const UnlockWrongPassword());
    await tester.pump();
    expect(_button(tester).busy, isFalse);
    expect(_secret(tester).enabled, isTrue);
  });

  testWidgets('fr03_return_submits_when_button_enabled', (tester) async {
    final service = await _pumpS3(tester);
    await _type(tester, validPassword);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(service.unlockCalls, [validPassword]);
    service.completeUnlock(const UnlockWrongPassword());
    await tester.pump();
  });

  testWidgets('fr03_wrong_password_shows_message_and_keeps_field', (
    tester,
  ) async {
    final service = await _pumpS3(tester);
    await _type(tester, validPassword);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();

    service.completeUnlock(const UnlockWrongPassword());
    await tester.pump();
    expect(find.text(_wrong), findsOneWidget);
    expect(_secret(tester).controller.text, validPassword);
    expect(_button(tester).onPressed, isNotNull);

    // Sửa ô thì thông báo ẩn.
    await _type(tester, '${validPassword}x');
    expect(find.text(_wrong), findsNothing);
  });

  testWidgets('fr07_corrupt_shows_message_and_keeps_field', (tester) async {
    final service = await _pumpS3(tester);
    await _type(tester, validPassword);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();

    service.completeUnlock(const UnlockCorrupt());
    await tester.pump();
    expect(find.text(_corrupt), findsOneWidget);
    expect(_secret(tester).controller.text, validPassword);
    expect(find.byType(LoginScreen), findsOneWidget);

    await _type(tester, validPassword.substring(1));
    expect(find.text(_corrupt), findsNothing);
  });

  testWidgets('fr04_ux_dr42_idle_shows_attempts_line_under_field', (
    tester,
  ) async {
    await _pumpS3(tester);

    expect(find.text(_attempts(10)), findsOneWidget);
    final field = tester.getRect(_field);
    final attempts = tester.getRect(find.text(_attempts(10)));
    expect(attempts.top - field.bottom, 6);
  });

  testWidgets('fr04_fr05_ux_dr21_wrong_is_above_attempts_and_n_decreases', (
    tester,
  ) async {
    final service = await _pumpS3(tester);
    await _type(tester, validPassword);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();

    service.attemptsLeft = 9;
    service.completeUnlock(const UnlockWrongPassword());
    await tester.pump();

    expect(find.text(_attempts(10)), findsNothing);
    expect(find.text(_attempts(9)), findsOneWidget);
    final wrong = tester.getRect(find.text(_wrong));
    final attempts = tester.getRect(find.text(_attempts(9)));
    expect(wrong.bottom, lessThanOrEqualTo(attempts.top));
    // Ô giữ nội dung, nhập lại được ngay.
    expect(_secret(tester).controller.text, validPassword);
    expect(_secret(tester).enabled, isTrue);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();
    expect(service.unlockCalls, [validPassword, validPassword]);
    service.completeUnlock(const UnlockWrongPassword());
    await tester.pump();

    // Sửa ô thì "Sai mật khẩu." ẩn, dòng số lần thử vẫn còn.
    await _type(tester, '${validPassword}x');
    expect(find.text(_wrong), findsNothing);
    expect(find.text(_attempts(9)), findsOneWidget);
  });

  testWidgets('fr07_ux_dr21_corrupt_is_above_attempts_and_n_kept', (
    tester,
  ) async {
    final service = await _pumpS3(tester, attemptsLeft: 7);
    await _type(tester, validPassword);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();

    service.completeUnlock(const UnlockCorrupt());
    await tester.pump();

    final corrupt = tester.getRect(find.text(_corrupt));
    final attempts = tester.getRect(find.text(_attempts(7)));
    expect(corrupt.bottom, lessThanOrEqualTo(attempts.top));
  });

  testWidgets('fr02_ux_dr21_non_ascii_is_above_attempts', (tester) async {
    await _pumpS3(tester);
    await _type(tester, 'mậtkhẩu dài hơn mười lăm');

    final nonAscii = tester.getRect(find.text(_nonAscii));
    final attempts = tester.getRect(find.text(_attempts(10)));
    expect(nonAscii.bottom, lessThanOrEqualTo(attempts.top));
  });

  testWidgets('fr04_ad08_unavailable_shows_message_and_keeps_n', (
    tester,
  ) async {
    final service = await _pumpS3(tester, attemptsLeft: 8);
    await _type(tester, validPassword);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();

    service.completeUnlock(const UnlockUnavailable());
    await tester.pump();

    expect(find.text(_unavailable), findsOneWidget);
    expect(find.text(_attempts(8)), findsOneWidget);
    final message = tester.getRect(find.text(_unavailable));
    final attempts = tester.getRect(find.text(_attempts(8)));
    expect(message.bottom, lessThanOrEqualTo(attempts.top));
    expect(_button(tester).busy, isFalse);
    expect(_button(tester).onPressed, isNotNull);
    expect(_secret(tester).controller.text, validPassword);
  });

  testWidgets('ux_dr42_busy_result_is_ignored', (tester) async {
    final service = await _pumpS3(tester);
    await _type(tester, validPassword);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();

    service.completeUnlock(const UnlockBusy());
    await tester.pump();

    expect(find.text(_wrong), findsNothing);
    expect(find.text(_corrupt), findsNothing);
    expect(find.text(_unavailable), findsNothing);
    expect(find.text(_attempts(10)), findsOneWidget);
    expect(_button(tester).busy, isFalse);
    expect(_secret(tester).enabled, isTrue);
  });

  testWidgets('fr04_fr08_no_attempts_left_disables_submit', (tester) async {
    final service = await _pumpS3(tester, attemptsLeft: 0);
    await _type(tester, validPassword);

    expect(find.text(_attempts(0)), findsOneWidget);
    expect(_button(tester).onPressed, isNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(service.unlockCalls, isEmpty);
  });

  testWidgets('fr04_fr08_locked_out_result_disables_submit', (tester) async {
    final service = await _pumpS3(tester, attemptsLeft: 1);
    await _type(tester, validPassword);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();

    service.attemptsLeft = 0;
    service.completeUnlock(const UnlockLockedOut());
    await tester.pump();

    expect(find.text(_attempts(0)), findsOneWidget);
    expect(find.text(_wrong), findsNothing);
    expect(_button(tester).busy, isFalse);
    expect(_button(tester).onPressed, isNull);
  });

  testWidgets('fr03_en_strings', (tester) async {
    final service = FakeAccountService(
      bootstrapResult: const BootstrapHasAccount(),
    );
    await pumpGateApp(
      tester,
      bootstrap: const BootstrapHasAccount(),
      service: service,
      language: AppLanguage.en,
    );
    expect(find.text('Log In'), findsOneWidget);
    expect(
      find.text('10 attempts left before your data is erased.'),
      findsOneWidget,
    );
    await _type(tester, validPassword);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();
    service.attemptsLeft = 1;
    service.completeUnlock(const UnlockWrongPassword());
    await tester.pump();
    expect(find.text('Incorrect password.'), findsOneWidget);
    // Số ít khi N = 1 (ICU plural).
    expect(
      find.text('1 attempt left before your data is erased.'),
      findsOneWidget,
    );
  });
}
