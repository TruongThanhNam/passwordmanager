import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/policy/password_policy.dart';
import 'package:pak_manager/core/policy/strength_estimator.dart';
import 'package:pak_manager/features/auth/create_account_screen.dart';
import 'package:pak_manager/features/shared/pak_buttons.dart';
import 'package:pak_manager/features/shared/secret_field.dart';
import 'package:pak_manager/services/account_service.dart';

import '../../core/policy/policy_test_support.dart';
import '../../support/account_fakes.dart';

final _main = find.byKey(const ValueKey('create.field.main'));
final _confirm = find.byKey(const ValueKey('create.field.confirm'));

const _nonAscii =
    'Chỉ dùng chữ không dấu, số, ký hiệu và khoảng trắng. Chữ có dấu có thể '
    'bị bàn phím ghi khác đi và khiến bạn không đăng nhập được.';
const _mismatch = 'Hai mật khẩu không khớp.';
const _failed = 'Không tạo được tài khoản. Hãy thử lại.';

/// Mở S2 với dịch vụ giả [service] (mặc định: chưa có tài khoản).
Future<FakeAccountService> _openS2(
  WidgetTester tester, {
  FakeAccountService? service,
  PasswordPolicy? policy,
}) async {
  final fake = service ?? FakeAccountService();
  await pumpGateApp(tester, service: fake, policy: policy);
  await openCreateScreen(tester);
  return fake;
}

Future<void> _type(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(
    find.descendant(of: field, matching: find.byType(EditableText)),
    text,
  );
  await tester.pump();
}

PakPrimaryButton _button(WidgetTester tester) =>
    tester.widget<PakPrimaryButton>(find.byType(PakPrimaryButton));

TextEditingController _controller(WidgetTester tester, Finder field) =>
    tester.widget<SecretField>(field).controller;

String _strengthLine(PasswordStrength strength) =>
    'Độ mạnh: ${switch (strength) {
      PasswordStrength.low => 'Thấp',
      PasswordStrength.medium => 'Trung bình',
      PasswordStrength.high => 'Cao',
    }}';

void main() {
  group('bố cục', () {
    testWidgets('ux_dr32_fr01_s2_shows_warning_fields_and_disabled_button', (
      tester,
    ) async {
      await _openS2(tester);

      expect(
        find.text(
          'Không có cách khôi phục mật khẩu chính. Nếu quên, bạn sẽ mất '
          'toàn bộ dữ liệu.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SecretField), findsNWidgets(2));
      expect(tester.widget<SecretField>(_main).placeholder, 'Mật khẩu chính');
      expect(
        tester.widget<SecretField>(_confirm).placeholder,
        'Nhập lại mật khẩu chính',
      );
      // Tiêu đề nav + nút cùng chuỗi `login.create`.
      expect(find.text('Tạo tài khoản'), findsNWidgets(2));
      expect(_button(tester).onPressed, isNull);
      // Ô trống: không dòng độ mạnh, không thông báo.
      expect(find.textContaining('Độ mạnh'), findsNothing);
    });

    testWidgets('ux_dr32_s2_vertical_rhythm', (tester) async {
      await _openS2(tester);

      final nav = tester.getRect(find.byType(CupertinoNavigationBar));
      final warning = tester.getRect(
        find.textContaining('Không có cách khôi phục'),
      );
      final main = tester.getRect(_main);
      final confirm = tester.getRect(_confirm);
      final button = tester.getRect(find.byType(PakPrimaryButton));
      expect(warning.top - nav.bottom, 24);
      expect(main.top - warning.bottom, 24);
      // Không có dòng nào dưới ô đầu khi trống.
      expect(confirm.top - main.bottom, 16);
      expect(button.top - confirm.bottom, 24);
      expect(main.width, button.width);
      expect(main.height, 48);
    });
  });

  group('luật mật khẩu (FR-2)', () {
    testWidgets('fr02_ux_dr41_non_ascii_is_kept_and_disables_button', (
      tester,
    ) async {
      await _openS2(tester);
      await _type(tester, _main, 'mậtkhẩu dài hơn mười lăm');
      await _type(tester, _confirm, 'mậtkhẩu dài hơn mười lăm');

      expect(_controller(tester, _main).text, 'mậtkhẩu dài hơn mười lăm');
      expect(find.text(_nonAscii), findsOneWidget);
      expect(_button(tester).onPressed, isNull);

      // Xóa ký tự có dấu → thông báo ẩn.
      await _type(tester, _main, 'matkhau dai hon muoi lam');
      expect(find.text(_nonAscii), findsNothing);
    });

    testWidgets('fr02_too_short_shows_current_length', (tester) async {
      await _openS2(tester);
      await _type(tester, _main, 'xq7 fake pw 12'); // 14 ký tự

      expect(find.text('Cần ít nhất 15 ký tự (hiện có 14).'), findsOneWidget);
      expect(_button(tester).onPressed, isNull);
    });

    testWidgets('fr02_too_long_is_reported_and_not_truncated', (tester) async {
      await _openS2(tester);
      final long = 'xq7 ' * 32 + 'z'; // 129 ký tự
      await _type(tester, _main, long);
      await _type(tester, _confirm, long);

      expect(_controller(tester, _main).text, hasLength(129));
      expect(find.text('Tối đa 128 ký tự.'), findsOneWidget);
      expect(_button(tester).onPressed, isNull);
    });

    testWidgets('fr02_common_password_is_rejected', (tester) async {
      // Filter giả chứa mọi chuỗi.
      await _openS2(tester, policy: PasswordPolicy(fullFilter()));
      await _type(tester, _main, validPassword);
      await _type(tester, _confirm, validPassword);

      expect(
        find.text(
          'Mật khẩu này quá phổ biến hoặc đã bị lộ. Hãy chọn mật khẩu khác.',
        ),
        findsOneWidget,
      );
      expect(_button(tester).onPressed, isNull);
    });

    testWidgets('fr02_repeated_char_is_rejected', (tester) async {
      await _openS2(tester);
      await _type(tester, _main, 'a' * 16);

      expect(
        find.text('Không dùng một ký tự lặp lại hoặc một dãy liên tiếp.'),
        findsOneWidget,
      );
    });

    testWidgets('ux_dr21_only_highest_priority_message_is_shown', (
      tester,
    ) async {
      await _openS2(tester);
      // Ngắn và có dấu: chỉ báo không ASCII.
      await _type(tester, _main, 'ấ');
      await _type(tester, _confirm, 'x');

      expect(find.text(_nonAscii), findsOneWidget);
      expect(find.textContaining('Cần ít nhất'), findsNothing);
      expect(find.text(_mismatch), findsNothing);
    });
  });

  group('nhập lại', () {
    testWidgets('ux_dr21_mismatch_only_once_confirm_reaches_length', (
      tester,
    ) async {
      await _openS2(tester);
      await _type(tester, _main, validPassword);
      // Ngắn hơn: chưa báo.
      await _type(tester, _confirm, validPassword.substring(0, 10));
      expect(find.text(_mismatch), findsNothing);
      expect(_button(tester).onPressed, isNull);

      // Dài bằng nhưng khác: báo, nút vô hiệu.
      final wrong = '${validPassword.substring(0, validPassword.length - 1)}X';
      await _type(tester, _confirm, wrong);
      expect(find.text(_mismatch), findsOneWidget);
      expect(_button(tester).onPressed, isNull);

      // Khớp: hết báo, nút bật.
      await _type(tester, _confirm, validPassword);
      expect(find.text(_mismatch), findsNothing);
      expect(_button(tester).onPressed, isNotNull);
    });

    testWidgets('ux_dr21_messages_appearing_do_not_rebuild_or_clear_fields', (
      tester,
    ) async {
      await _openS2(tester);
      // Lỗi luật dưới ô đầu, rồi đổi thành "không khớp" dưới ô nhập lại:
      // thay đổi ở cả hai phía của ô nhập lại trong `Column`.
      const accented = 'mậtkhẩu dài hơn mười lăm';
      await _type(tester, _main, accented);
      await _type(tester, _confirm, accented);
      expect(find.text(_nonAscii), findsOneWidget);
      await _type(tester, _main, 'matkhau dai hon muoi lam');
      await tester.pump(strengthDebounce);

      expect(find.text(_nonAscii), findsNothing);
      expect(find.text(_mismatch), findsOneWidget);
      expect(_controller(tester, _confirm).text, accented);
      expect(_controller(tester, _main).text, 'matkhau dai hon muoi lam');
      expect(tester.takeException(), isNull);
    });

    test('ux_dr21_create_field_message_priority', () {
      expect(createFieldMessage(const PasswordOk(), '', ''), isNull);
      expect(
        createFieldMessage(const PasswordTooShort(3), 'abc', 'abc'),
        isA<PolicyMessage>(),
      );
      expect(createFieldMessage(const PasswordOk(), 'abcd', 'ab'), isNull);
      expect(
        createFieldMessage(const PasswordOk(), 'abcd', 'abce'),
        isA<MismatchMessage>(),
      );
      expect(
        createFieldMessage(const PasswordOk(), 'abcd', 'abcde'),
        isA<MismatchMessage>(),
      );
      expect(createFieldMessage(const PasswordOk(), 'abcd', 'abcd'), isNull);
    });
  });

  group('độ mạnh (UX-DR20)', () {
    testWidgets('ux_dr20_strength_is_debounced_150ms_and_hidden_when_empty', (
      tester,
    ) async {
      await _openS2(tester);
      await _type(tester, _main, validPassword);
      final line = _strengthLine(sharedEstimator.estimate(validPassword));

      // Chưa đủ 150 ms sau phím cuối: chưa tính.
      await tester.pump(const Duration(milliseconds: 149));
      expect(find.text(line), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(line), findsOneWidget);

      // Ô trống: ẩn ngay, không chờ.
      await _type(tester, _main, '');
      expect(find.textContaining('Độ mạnh'), findsNothing);
      await tester.pump(strengthDebounce);
      expect(find.textContaining('Độ mạnh'), findsNothing);
    });

    testWidgets('ux_dr21_strength_line_sits_above_policy_message', (
      tester,
    ) async {
      await _openS2(tester);
      await _type(tester, _main, 'mậtkhẩu của tôi rất dài');
      await tester.pump(strengthDebounce);

      // Có lỗi luật vẫn hiện mức zxcvbnm (quyết định 2026-11-10).
      final strength = find.textContaining('Độ mạnh: ');
      expect(strength, findsOneWidget);
      final message = find.text(_nonAscii);
      expect(
        tester.getRect(strength).bottom,
        lessThanOrEqualTo(tester.getRect(message).top),
      );
      expect(tester.getRect(strength).top - tester.getRect(_main).bottom, 6);
      expect(tester.getRect(message).top - tester.getRect(strength).bottom, 2);
      // Thẳng mép chữ trong ô: thụt 32.
      expect(tester.getRect(strength).left - tester.getRect(_main).left, 16);
    });
  });

  group('gửi', () {
    testWidgets('ux_dr19_return_moves_to_confirm_then_submits', (tester) async {
      final service = await _openS2(tester);
      await tester.tap(_main);
      await _type(tester, _main, validPassword);

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      final confirmEditable = tester.widget<EditableText>(
        find.descendant(of: _confirm, matching: find.byType(EditableText)),
      );
      expect(confirmEditable.focusNode.hasFocus, isTrue);

      // Ô cuối, nút đang vô hiệu: Return không gửi.
      await _type(tester, _confirm, 'short');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(service.createCalls, isEmpty);

      await tester.tap(_confirm);
      await _type(tester, _confirm, validPassword);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(service.createCalls, [validPassword]);
      service.completeCreate(const CreateFailure());
      await tester.pump();
    });

    testWidgets(
      'fr01_ux_dr10_double_tap_creates_once_with_spinner_and_locked_fields',
      (tester) async {
        final service = await _openS2(tester);
        await _type(tester, _main, validPassword);
        await _type(tester, _confirm, validPassword);
        expect(_button(tester).onPressed, isNotNull);

        await tester.tap(find.byType(PakPrimaryButton));
        await tester.pump();
        await tester.tap(find.byType(PakPrimaryButton));
        await tester.pump();

        expect(service.createCalls, [validPassword]);
        expect(_button(tester).busy, isTrue);
        expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
        for (final field in [_main, _confirm]) {
          expect(tester.widget<SecretField>(field).enabled, isFalse);
        }

        // Back (nút chevron và Back hệ thống) bị chặn khi bận.
        await tester.tap(find.byType(CupertinoNavigationBarBackButton));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(CreateAccountScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(CreateAccountScreen), findsOneWidget);

        service.completeCreate(const CreateFailure());
        await tester.pump();
      },
    );

    testWidgets('fr01_failure_keeps_fields_reenables_button_and_explains', (
      tester,
    ) async {
      final service = await _openS2(tester);
      await _type(tester, _main, validPassword);
      await _type(tester, _confirm, validPassword);
      await tester.tap(find.byType(PakPrimaryButton));
      await tester.pump();

      service.completeCreate(const CreateFailure());
      await tester.pump();

      expect(find.byType(CreateAccountScreen), findsOneWidget);
      expect(_controller(tester, _main).text, validPassword);
      expect(_controller(tester, _confirm).text, validPassword);
      expect(_button(tester).busy, isFalse);
      expect(_button(tester).onPressed, isNotNull);
      expect(tester.widget<SecretField>(_main).enabled, isTrue);
      final failed = find.text(_failed);
      expect(failed, findsOneWidget);
      // Dưới nút, cách 6.
      expect(
        tester.getRect(failed).top -
            tester.getRect(find.byType(PakPrimaryButton)).bottom,
        6,
      );

      // Sửa ô → thông báo ẩn.
      await _type(tester, _confirm, '${validPassword}x');
      expect(find.text(_failed), findsNothing);
    });

    testWidgets('fr01_editing_main_field_hides_failure_message', (
      tester,
    ) async {
      final service = await _openS2(tester);
      await _type(tester, _main, validPassword);
      await _type(tester, _confirm, validPassword);
      await tester.tap(find.byType(PakPrimaryButton));
      await tester.pump();
      service.completeCreate(const CreateFailure());
      await tester.pump();
      expect(find.text(_failed), findsOneWidget);

      await _type(tester, _main, '${validPassword}x');
      expect(find.text(_failed), findsNothing);
    });

    testWidgets('fr01_failure_message_hides_when_pressing_again', (
      tester,
    ) async {
      final service = await _openS2(tester);
      await _type(tester, _main, validPassword);
      await _type(tester, _confirm, validPassword);
      await tester.tap(find.byType(PakPrimaryButton));
      await tester.pump();
      service.completeCreate(const CreateFailure());
      await tester.pump();
      expect(find.text(_failed), findsOneWidget);

      await tester.tap(find.byType(PakPrimaryButton));
      await tester.pump();
      expect(find.text(_failed), findsNothing);
      expect(service.createCalls, hasLength(2));
      service.completeCreate(const CreateFailure());
      await tester.pump();
    });

    testWidgets('ad15_missing_blocklist_never_enables_create', (tester) async {
      // Blocklist không nạp được → không có luật → không bao giờ bật nút.
      await pumpGateApp(
        tester,
        service: FakeAccountService(),
        withPolicy: false,
      );
      await openCreateScreen(tester);
      await _type(tester, _main, validPassword);
      await _type(tester, _confirm, validPassword);

      expect(_button(tester).onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });
  });
}
