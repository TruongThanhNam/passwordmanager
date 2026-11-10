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

final _field = find.byKey(const ValueKey('login.field'));

Future<FakeAccountService> _pumpS3(WidgetTester tester) async {
  final service = FakeAccountService(
    bootstrapResult: const BootstrapHasAccount(),
  );
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
      expect(texts, ['PAK Manager', 'Đăng nhập']);
    },
  );

  testWidgets('ux_dr31_s3_spacing_48_field_24_button', (tester) async {
    await _pumpS3(tester);

    final title = tester.getRect(find.text('PAK Manager'));
    final field = tester.getRect(_field);
    final button = tester.getRect(find.byType(PakPrimaryButton));
    expect(field.top - title.bottom, 48);
    expect(button.top - field.bottom, 24);

    // Có thông báo: cách ô 6, nút vẫn cách 24 dưới thông báo.
    await _type(tester, 'mậtkhẩu dài hơn mười lăm');
    final message = tester.getRect(find.text(_nonAscii));
    final field2 = tester.getRect(_field);
    final button2 = tester.getRect(find.byType(PakPrimaryButton));
    expect(message.top - field2.bottom, 6);
    expect(button2.top - message.bottom, 24);
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
    await _type(tester, validPassword);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();
    service.completeUnlock(const UnlockWrongPassword());
    await tester.pump();
    expect(find.text('Incorrect password.'), findsOneWidget);
  });
}
