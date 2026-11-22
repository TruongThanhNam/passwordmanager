import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/model/settings.dart';
import 'package:pak_manager/features/auth/erase_dialog.dart';
import 'package:pak_manager/features/auth/login_screen.dart';
import 'package:pak_manager/features/auth/wiping_screen.dart';
import 'package:pak_manager/features/shared/hold_confirm_button.dart';
import 'package:pak_manager/features/shared/pak_buttons.dart';
import 'package:pak_manager/features/shared/secret_field.dart';
import 'package:pak_manager/features/shared/theme/pak_colors.dart';
import 'package:pak_manager/services/account_service.dart';

import '../../support/account_fakes.dart';

const _wrong = 'Sai mật khẩu.';
const _corrupt =
    'Dữ liệu bị hỏng — Mật khẩu đúng nhưng không đọc được dữ liệu. Bạn có thể '
    'dùng "Xóa & Tạo tài khoản mới" rồi import lại từ file export.';
const _nonAscii =
    'Chỉ dùng chữ không dấu, số, ký hiệu và khoảng trắng. Chữ có dấu có thể '
    'bị bàn phím ghi khác đi và khiến bạn không đăng nhập được.';

const _erase = 'Xóa & Tạo tài khoản mới';

const _retry = 'Chưa kiểm tra được mật khẩu. Hãy thử lại.';
const _unavailable = 'Không mở được dữ liệu của app. Hãy khởi động lại app.';

String _attempts(int n) => 'Còn $n lần thử trước khi dữ liệu bị xóa.';

String _lockout(String time) => 'Thử lại sau $time';

const _fullWait = Duration(minutes: 30);

final _field = find.byKey(const ValueKey('login.field'));

/// S3 với [attemptsLeft] và thời gian chờ [lockout]; chờ xong lần hỏi
/// `lockoutRemaining` khi mở màn.
Future<FakeAccountService> _pumpS3(
  WidgetTester tester, {
  int attemptsLeft = 10,
  Duration lockout = Duration.zero,
}) async {
  final service =
      FakeAccountService(bootstrapResult: const BootstrapHasAccount())
        ..attemptsLeft = attemptsLeft
        ..lockout = lockout;
  await pumpGateApp(
    tester,
    bootstrap: const BootstrapHasAccount(),
    service: service,
  );
  await tester.pump();
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
      // Không "Quên mật khẩu", gợi ý hay nút nào khác ngoài nút mắt và nút
      // xóa (FR-9).
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      expect(texts, ['PAK Manager', _attempts(10), 'Đăng nhập', _erase]);
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

  testWidgets('fr07_ux_dr21_ux_dr42_retry_is_above_attempts_and_n_kept', (
    tester,
  ) async {
    final service = await _pumpS3(tester, attemptsLeft: 7);
    await _type(tester, validPassword);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();

    service.completeUnlock(const UnlockRetry());
    await tester.pump();

    // `login.retry` nằm trên `login.attempts`, N không giảm, không hiện
    // `login.corrupt`/`login.wrong`.
    expect(find.text(_retry), findsOneWidget);
    expect(find.text(_corrupt), findsNothing);
    expect(find.text(_wrong), findsNothing);
    expect(find.text(_attempts(7)), findsOneWidget);
    final retry = tester.getRect(find.text(_retry));
    final attempts = tester.getRect(find.text(_attempts(7)));
    expect(retry.bottom, lessThanOrEqualTo(attempts.top));
    // Chữ ink-secondary, không màu đỏ (UX-DR21).
    expect(
      tester.widget<Text>(find.text(_retry)).style?.color?.toARGB32(),
      PakColors.inkSecondary.color.toARGB32(),
    );
    // Ô giữ nội dung, bấm "Đăng nhập" lại ngay được.
    expect(_secret(tester).controller.text, validPassword);
    expect(_secret(tester).enabled, isTrue);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();
    expect(service.unlockCalls, [validPassword, validPassword]);
    service.completeUnlock(const UnlockRetry());
    await tester.pump();

    // Sửa ô thì `login.retry` ẩn, dòng số lần thử vẫn còn.
    await _type(tester, '${validPassword}x');
    expect(find.text(_retry), findsNothing);
    expect(find.text(_attempts(7)), findsOneWidget);
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

  test('fr04_lockout_clock_rounds_up_to_whole_seconds', () {
    expect(lockoutClock(const Duration(minutes: 30)), '30:00');
    expect(
      lockoutClock(
        const Duration(minutes: 30) - const Duration(milliseconds: 1),
      ),
      '30:00',
    );
    expect(lockoutClock(const Duration(minutes: 29, seconds: 59)), '29:59');
    expect(lockoutClock(const Duration(seconds: 61)), '01:01');
    expect(lockoutClock(const Duration(seconds: 1)), '00:01');
    expect(lockoutClock(const Duration(milliseconds: 1)), '00:01');
    expect(lockoutClock(Duration.zero), '00:00');
  });

  testWidgets('fr04_ux_dr42_lockout_on_open_disables_field_and_button', (
    tester,
  ) async {
    final service = await _pumpS3(tester, attemptsLeft: 5, lockout: _fullWait);

    expect(service.lockoutQueries, 1);
    expect(find.text(_lockout('30:00')), findsOneWidget);
    expect(_secret(tester).enabled, isFalse);
    expect(_button(tester).onPressed, isNull);
    final icon = tester.widget<Icon>(
      find.descendant(of: _field, matching: find.byType(Icon)),
    );
    expect(icon.color?.toARGB32(), PakColors.inkDisabled.color.toARGB32());
  });

  testWidgets(
    'fr04_fr06_ux_dr21_ux_dr42_fifth_wrong_shows_lockout_above_attempts',
    (tester) async {
      final service = await _pumpS3(tester, attemptsLeft: 6);
      await _type(tester, validPassword);
      // Người dùng đang hiện mật khẩu trước lần sai thứ 5.
      await tester.tap(find.byIcon(CupertinoIcons.eye));
      await tester.pump();
      await tester.tap(find.byType(PakPrimaryButton));
      await tester.pump();

      service
        ..attemptsLeft = 5
        ..lockout = _fullWait;
      service.completeUnlock(const UnlockWrongPassword());
      await tester.pump();

      // "Thử lại sau 30:00" thay chỗ "Sai mật khẩu.", nằm trên dòng số lần thử.
      expect(find.text(_wrong), findsNothing);
      expect(find.text(_lockout('30:00')), findsOneWidget);
      final lockout = tester.getRect(find.text(_lockout('30:00')));
      final attempts = tester.getRect(find.text(_attempts(5)));
      final field = tester.getRect(_field);
      expect(lockout.top - field.bottom, 6);
      expect(attempts.top - lockout.bottom, 2);
      // Ô và nút vô hiệu, ô giữ nội dung nhưng đã che lại (nút mắt khóa).
      expect(_secret(tester).enabled, isFalse);
      expect(_secret(tester).controller.text, validPassword);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isTrue,
      );
      expect(_button(tester).busy, isFalse);
      expect(_button(tester).onPressed, isNull);

      // Timer bắt đầu từ kết quả `unlock`: đếm tiếp từng giây.
      service.lockout = _fullWait - lockoutTick;
      await tester.pump(lockoutTick);
      expect(find.text(_lockout('29:59')), findsOneWidget);

      // Hết giờ: về idle, ô vẫn giữ mật khẩu hợp lệ nên nút bật lại ngay,
      // không cần gõ thêm.
      service.lockout = Duration.zero;
      await tester.pump(lockoutTick);
      expect(find.textContaining('Thử lại sau'), findsNothing);
      expect(find.text(_attempts(5)), findsOneWidget);
      expect(_secret(tester).enabled, isTrue);
      expect(_secret(tester).controller.text, validPassword);
      expect(_button(tester).onPressed, isNotNull);
    },
  );

  testWidgets('fr04_ux_dr42_lockout_counts_down_every_second', (tester) async {
    final service = await _pumpS3(tester, attemptsLeft: 5, lockout: _fullWait);
    expect(find.text(_lockout('30:00')), findsOneWidget);

    service.lockout = _fullWait - const Duration(seconds: 1);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(_lockout('30:00')), findsNothing);
    expect(find.text(_lockout('29:59')), findsOneWidget);
    expect(service.lockoutQueries, 2);

    // Nhịp thứ hai: timer vẫn chạy (không phải one-shot).
    service.lockout = _fullWait - const Duration(seconds: 2);
    await tester.pump(lockoutTick);

    expect(find.text(_lockout('29:58')), findsOneWidget);
    expect(service.lockoutQueries, 3);
  });

  testWidgets('fr04_ux_dr42_lockout_end_returns_to_idle_and_stops_timer', (
    tester,
  ) async {
    final service = await _pumpS3(
      tester,
      attemptsLeft: 5,
      lockout: const Duration(seconds: 1),
    );
    expect(find.text(_lockout('00:01')), findsOneWidget);

    service.lockout = Duration.zero;
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Thử lại sau'), findsNothing);
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .toList();
    expect(texts, ['PAK Manager', _attempts(5), 'Đăng nhập', _erase]);
    expect(_secret(tester).enabled, isTrue);
    // Timer đã hủy: không hỏi lại nữa.
    final queries = service.lockoutQueries;
    await tester.pump(const Duration(seconds: 5));
    expect(service.lockoutQueries, queries);

    // Nút bật lại khi ô đủ điều kiện.
    expect(_button(tester).onPressed, isNull);
    await _type(tester, validPassword);
    expect(_button(tester).onPressed, isNotNull);
  });

  testWidgets('fr04_ux_dr42_locked_out_result_shows_lockout', (tester) async {
    final service = await _pumpS3(tester, attemptsLeft: 4);
    await _type(tester, validPassword);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();

    service.lockout = const Duration(minutes: 12, seconds: 30);
    service.completeUnlock(const UnlockLockedOut());
    await tester.pump();

    expect(find.text(_lockout('12:30')), findsOneWidget);
    expect(find.text(_attempts(4)), findsOneWidget);
    expect(_button(tester).onPressed, isNull);
  });

  testWidgets('ux_dr42_lockout_queried_on_open_and_after_results', (
    tester,
  ) async {
    final service = await _pumpS3(tester);
    expect(service.lockoutQueries, 1);
    await _type(tester, validPassword);

    Future<void> submit(UnlockResult result) async {
      await tester.tap(find.byType(PakPrimaryButton));
      await tester.pump();
      service.completeUnlock(result);
      await tester.pump();
    }

    await submit(const UnlockBusy());
    expect(service.lockoutQueries, 1);
    await submit(const UnlockWrongPassword());
    expect(service.lockoutQueries, 2);
    await submit(const UnlockCorrupt());
    expect(service.lockoutQueries, 3);
    await submit(const UnlockUnavailable());
    expect(service.lockoutQueries, 4);
  });

  testWidgets('ux_dr42_lockout_timer_cancelled_when_leaving_screen', (
    tester,
  ) async {
    final service = await _pumpS3(tester, attemptsLeft: 5, lockout: _fullWait);
    await tester.pump(const Duration(seconds: 1));
    final queries = service.lockoutQueries;
    expect(queries, 2);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));

    expect(service.lockoutQueries, queries);
  });

  testWidgets('fr04_ux_dr42_wrong_result_waits_for_lockout_before_render', (
    tester,
  ) async {
    final service = await _pumpS3(tester, attemptsLeft: 6);
    await _type(tester, validPassword);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();

    final hold = Completer<Duration>();
    service
      ..attemptsLeft = 5
      ..lockoutHold = hold;
    service.completeUnlock(const UnlockWrongPassword());
    await tester.pump();

    // Chưa có thời gian chờ: không chớp "Sai mật khẩu.", vẫn đang kiểm tra.
    expect(find.text(_wrong), findsNothing);
    expect(_button(tester).busy, isTrue);
    expect(_secret(tester).enabled, isFalse);

    hold.complete(_fullWait);
    await tester.pump();

    expect(find.text(_lockout('30:00')), findsOneWidget);
    expect(find.text(_wrong), findsNothing);
    expect(_button(tester).busy, isFalse);
    expect(_button(tester).onPressed, isNull);
  });

  testWidgets('fr04_ux_dr42_lockout_en_string', (tester) async {
    final service =
        FakeAccountService(bootstrapResult: const BootstrapHasAccount())
          ..attemptsLeft = 5
          ..lockout = _fullWait;
    await pumpGateApp(
      tester,
      bootstrap: const BootstrapHasAccount(),
      service: service,
      language: AppLanguage.en,
    );
    await tester.pump();

    expect(find.text('Try again in 30:00'), findsOneWidget);
  });

  testWidgets('fr04_ux_dr42_tenth_wrong_goes_to_s5_without_dialog', (
    tester,
  ) async {
    final service = await _pumpS3(tester, attemptsLeft: 1);
    await _type(tester, validPassword);
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pump();
    expect(_button(tester).busy, isTrue);

    service.attemptsLeft = 0;
    service.completeUnlock(const UnlockWipeRequired());
    await tester.pump();

    // Không dialog, không thông báo trung gian: S3 bị gỡ, S5 hiện ngay.
    expect(find.byType(WipingScreen), findsOneWidget);
    expect(find.text('Đang xóa dữ liệu…'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(SecretField), findsNothing);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.text(_wrong), findsNothing);
    expect(find.byType(CupertinoButton), findsNothing);
    // `unlock` không xóa; S5 gọi `wipe()` đúng một lần.
    expect(service.wipeCalls, 1);
    expect(service.unlockCalls, [validPassword]);
  });

  group('xóa & tạo tài khoản mới (S3 → S4)', () {
    // Finder tạo mới mỗi lần dùng: finder dùng chung giữa các test giữ kết
    // quả cũ.
    Finder eraseRow() => find.byKey(const ValueKey('row.erase'));
    Finder dialog() => find.byType(EraseDialog);

    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.text(_erase));
      await tester.pump();
      await tester.pump(eraseDialogTransition * 2);
    }

    /// Cuộn S3 tới cuối (không dùng `drag`: iOS cho kéo quá đáy).
    void scrollToEnd(WidgetTester tester) {
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent);
    }

    Future<void> holdFull(WidgetTester tester) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldConfirmButton)),
      );
      await tester.pump();
      await tester.pump(holdConfirmDuration + const Duration(milliseconds: 1));
      await tester.pump(eraseDialogTransition * 2);
      await gesture.up();
      await tester.pump();
    }

    testWidgets('ux_dr31_fr09_erase_button_pinned_bottom_44_inset_42', (
      tester,
    ) async {
      await _pumpS3(tester);

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final erase = tester.getRect(eraseRow());
      final submit = tester.getRect(find.byType(PakPrimaryButton));
      expect(erase.height, 44);
      expect(screen.height - erase.bottom, 42);
      // Dưới và xa nút "Đăng nhập", căn giữa theo chiều ngang.
      expect(erase.top - submit.bottom, greaterThan(100));
      expect(erase.center.dx, closeTo(screen.width / 2, 0.5));
      // Là button-text `accent`, không nền.
      final label = tester.widget<Text>(find.text(_erase));
      expect(label.style?.color?.toARGB32(), PakColors.accent.color.toARGB32());
      expect(find.byType(PakTextButton), findsOneWidget);
    });

    testWidgets('ux_dr31_fr09_erase_bottom_42_measured_from_safe_area', (
      tester,
    ) async {
      // Home indicator: 42 đo từ mép safe-area, như phần đầu màn đo từ
      // status bar (quyết định review story 2.4).
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844)
        ..padding = const FakeViewPadding(bottom: 34)
        ..viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
      await _pumpS3(tester);

      final erase = tester.getRect(eraseRow());
      expect(844 - 34 - erase.bottom, 42);
      expect(erase.height, 44);
    });

    testWidgets('ux_dr31_short_screen_scrolls_and_never_overlaps_submit', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(360, 420);
      addTearDown(tester.view.reset);
      await _pumpS3(tester);

      scrollToEnd(tester);
      await tester.pump();

      final erase = tester.getRect(eraseRow());
      final submit = tester.getRect(find.byType(PakPrimaryButton));
      expect(erase.top - submit.bottom, greaterThanOrEqualTo(24));
      expect(420 - erase.bottom, 42);
      expect(erase.height, 44);
    });

    testWidgets('ux_dr31_keyboard_inset_keeps_erase_below_submit', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(360, 700)
        ..viewInsets = const FakeViewPadding(bottom: 400);
      addTearDown(tester.view.reset);
      await _pumpS3(tester);

      scrollToEnd(tester);
      await tester.pump();

      final erase = tester.getRect(eraseRow());
      final submit = tester.getRect(find.byType(PakPrimaryButton));
      expect(erase.top, greaterThanOrEqualTo(submit.bottom + 24));
      // Nút ghim đáy phần còn lại sau bàn phím, không bị bàn phím che.
      expect(erase.bottom, lessThanOrEqualTo(700 - 400));
    });

    testWidgets('ux_dr42_erase_available_when_idle_and_opens_s4', (
      tester,
    ) async {
      final service = await _pumpS3(tester);

      await openDialog(tester);

      expect(dialog(), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(service.wipeCalls, 0);
      expect(service.unlockCalls, isEmpty);
    });

    testWidgets('ux_dr42_erase_available_after_wrong_and_keeps_message', (
      tester,
    ) async {
      final service = await _pumpS3(tester);
      await _type(tester, validPassword);
      await tester.tap(find.byType(PakPrimaryButton));
      await tester.pump();
      service.attemptsLeft = 9;
      service.completeUnlock(const UnlockWrongPassword());
      await tester.pump();

      await openDialog(tester);
      expect(dialog(), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pump();
      await tester.pump(eraseDialogTransition * 2);

      expect(dialog(), findsNothing);
      expect(find.text(_wrong), findsOneWidget);
      expect(find.text(_attempts(9)), findsOneWidget);
      expect(_secret(tester).controller.text, validPassword);
    });

    testWidgets('ux_dr42_erase_available_while_locked_out_countdown_runs', (
      tester,
    ) async {
      final service = await _pumpS3(
        tester,
        attemptsLeft: 5,
        lockout: _fullWait,
      );
      expect(_secret(tester).enabled, isFalse);

      await openDialog(tester);
      expect(dialog(), findsOneWidget);

      // Đếm ngược vẫn chạy dưới dialog.
      service.lockout = _fullWait - lockoutTick;
      await tester.pump(lockoutTick);
      await tester.tap(find.text('Hủy'));
      await tester.pump();
      await tester.pump(eraseDialogTransition * 2);

      expect(dialog(), findsNothing);
      expect(find.text(_lockout('29:59')), findsOneWidget);
      expect(_secret(tester).enabled, isFalse);
    });

    testWidgets('ux_dr42_fr07_erase_available_when_data_corrupt', (
      tester,
    ) async {
      final service = await _pumpS3(tester, attemptsLeft: 7);
      await _type(tester, validPassword);
      await tester.tap(find.byType(PakPrimaryButton));
      await tester.pump();
      service.completeUnlock(const UnlockCorrupt());
      await tester.pump();
      expect(find.text(_corrupt), findsOneWidget);

      await openDialog(tester);
      expect(dialog(), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pump();
      await tester.pump(eraseDialogTransition * 2);

      expect(find.text(_corrupt), findsOneWidget);
      expect(find.text(_attempts(7)), findsOneWidget);
      expect(service.wipeCalls, 0);
    });

    testWidgets('ux_dr42_fr09_erase_available_when_no_attempts_left', (
      tester,
    ) async {
      final service = await _pumpS3(tester, attemptsLeft: 0);
      expect(find.text(_attempts(0)), findsOneWidget);

      expect(
        tester.widget<PakTextButton>(find.byType(PakTextButton)).onPressed,
        isNotNull,
      );
      await openDialog(tester);

      expect(dialog(), findsOneWidget);
      expect(service.wipeCalls, 0);
    });

    testWidgets('ux_dr42_erase_disabled_while_checking_password', (
      tester,
    ) async {
      final service = await _pumpS3(tester);
      await _type(tester, validPassword);
      await tester.tap(find.byType(PakPrimaryButton));
      await tester.pump();
      expect(_button(tester).busy, isTrue);

      expect(
        tester.widget<PakTextButton>(find.byType(PakTextButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text(_erase));
      await tester.pump();
      await tester.pump(eraseDialogTransition * 2);
      expect(dialog(), findsNothing);
      expect(service.wipeCalls, 0);

      // Kiểm tra xong thì nút bấm được lại.
      service.completeUnlock(const UnlockWrongPassword());
      await tester.pump();
      expect(
        tester.widget<PakTextButton>(find.byType(PakTextButton)).onPressed,
        isNotNull,
      );
      await openDialog(tester);
      expect(dialog(), findsOneWidget);
    });

    testWidgets('fr09_uj04_hold_full_goes_s4_to_s5_to_s1_with_one_wipe', (
      tester,
    ) async {
      final service = await _pumpS3(tester);
      await openDialog(tester);

      await holdFull(tester);

      expect(dialog(), findsNothing);
      expect(find.byType(WipingScreen), findsOneWidget);
      expect(find.text('Đang xóa dữ liệu…'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(SecretField), findsNothing);
      expect(service.wipeCalls, 1);
      // `unlock` không bị gọi: xóa không cần mật khẩu.
      expect(service.unlockCalls, isEmpty);

      service.completeWipe();
      await tester.pump();

      expect(find.byType(WipingScreen), findsNothing);
      expect(find.text('Tạo tài khoản'), findsOneWidget);
      expect(find.text(_erase), findsNothing);
      expect(find.byType(SecretField), findsNothing);
      expect(service.wipeCalls, 1);
    });

    testWidgets('fr09_uj04_wipe_failure_after_hold_shows_s1_unavailable', (
      tester,
    ) async {
      final service = await _pumpS3(tester);
      await openDialog(tester);
      await holdFull(tester);

      service.completeWipe(const WipeFailed());
      await tester.pump();

      expect(find.text(_unavailable), findsOneWidget);
      expect(find.text(_erase), findsNothing);
      expect(
        tester.widget<LoginScreen>(find.byType(LoginScreen)).unavailable,
        isTrue,
      );
    });

    testWidgets('fr09_early_release_keeps_s3_untouched', (tester) async {
      final service = await _pumpS3(tester);
      await _type(tester, validPassword);
      await openDialog(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldConfirmButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await gesture.up();
      await tester.pump();
      await tester.pump(holdConfirmRewind);
      await tester.tap(find.text('Hủy'));
      await tester.pump();
      await tester.pump(eraseDialogTransition * 2);

      expect(service.wipeCalls, 0);
      expect(find.byType(WipingScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(_secret(tester).controller.text, validPassword);
    });

    testWidgets('fr09_cancel_keeps_field_and_does_not_wipe', (tester) async {
      final service = await _pumpS3(tester);
      await _type(tester, validPassword);
      await openDialog(tester);

      await tester.tap(find.text('Hủy'));
      await tester.pump();
      await tester.pump(eraseDialogTransition * 2);

      expect(service.wipeCalls, 0);
      expect(_secret(tester).controller.text, validPassword);
      expect(_button(tester).onPressed, isNotNull);
    });

    testWidgets('fr09_erase_button_only_on_s3_not_s1_or_s5', (tester) async {
      await pumpGateApp(tester, service: FakeAccountService());
      expect(find.text(_erase), findsNothing);
      expect(find.byType(PakTextButton), findsNothing);

      await tester.pumpWidget(const SizedBox());
      final service = FakeAccountService(
        bootstrapResult: const BootstrapWiping(),
      );
      await pumpGateApp(
        tester,
        bootstrap: const BootstrapWiping(),
        service: service,
      );
      await tester.pump();
      expect(find.byType(WipingScreen), findsOneWidget);
      expect(find.text(_erase), findsNothing);
    });

    testWidgets('fr09_en_erase_button_label', (tester) async {
      final service = FakeAccountService(
        bootstrapResult: const BootstrapHasAccount(),
      );
      await pumpGateApp(
        tester,
        bootstrap: const BootstrapHasAccount(),
        service: service,
        language: AppLanguage.en,
      );
      await tester.pump();

      expect(find.text('Erase & Create New Account'), findsOneWidget);
    });
  });
}
