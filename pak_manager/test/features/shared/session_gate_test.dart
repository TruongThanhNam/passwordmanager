import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/features/auth/create_account_screen.dart';
import 'package:pak_manager/features/auth/login_screen.dart';
import 'package:pak_manager/features/shared/home_shell.dart';
import 'package:pak_manager/features/shared/icons/tab_icons.dart';
import 'package:pak_manager/features/shared/pak_buttons.dart';
import 'package:pak_manager/features/shared/secret_field.dart';
import 'package:pak_manager/features/shared/session_gate.dart';
import 'package:pak_manager/features/shared/theme/pak_colors.dart';
import 'package:pak_manager/services/account_service.dart';

import '../../support/account_fakes.dart';

/// Gõ hai ô S2 hợp lệ, bấm tạo, rồi trả [result] từ dịch vụ giả.
Future<void> _createWith(
  WidgetTester tester,
  FakeAccountService service,
  CreateResult result,
) async {
  await tester.enterText(
    find.byKey(const ValueKey('create.field.main')),
    validPassword,
  );
  await tester.enterText(
    find.byKey(const ValueKey('create.field.confirm')),
    validPassword,
  );
  await tester.pump();
  await tester.tap(find.byType(PakPrimaryButton));
  await tester.pump();
  service.completeCreate(result);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fr01_fr10_s1_shows_title_and_only_create_button', (
    tester,
  ) async {
    await pumpGateApp(tester, service: FakeAccountService());

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('PAK Manager'), findsOneWidget);
    expect(find.text('Tạo tài khoản'), findsOneWidget);
    // Đúng một nút, không ô mật khẩu, không "Quên mật khẩu"/gợi ý/câu hỏi.
    expect(find.byType(PakPrimaryButton), findsOneWidget);
    expect(find.byType(CupertinoButton), findsOneWidget);
    expect(find.byType(SecretField), findsNothing);
    expect(find.byType(CupertinoNavigationBar), findsNothing);
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .toList();
    expect(texts, ['PAK Manager', 'Tạo tài khoản']);
  });

  testWidgets('ux_dr31_s1_button_sits_48_below_title', (tester) async {
    await pumpGateApp(tester, service: FakeAccountService());

    final title = tester.getRect(find.text('PAK Manager'));
    final button = tester.getRect(find.byType(PakPrimaryButton));
    expect(button.top - title.bottom, 48);
    expect(button.height, 48);
    // Lề ngang 16 trong cột nội dung (tên app phủ hết bề ngang cột).
    expect(button.left - title.left, 16);
    expect(title.right - button.right, 16);
  });

  testWidgets('fr01_s3_placeholder_has_title_only_before_story_1_7', (
    tester,
  ) async {
    await pumpGateApp(
      tester,
      bootstrap: const BootstrapHasAccount(),
      service: FakeAccountService(),
    );

    expect(find.text('PAK Manager'), findsOneWidget);
    expect(find.byType(PakPrimaryButton), findsNothing);
    expect(find.text('Tạo tài khoản'), findsNothing);
    expect(
      tester.widget<LoginScreen>(find.byType(LoginScreen)).hasAccount,
      isTrue,
    );
  });

  testWidgets('ad11_unavailable_storage_disables_create_and_explains', (
    tester,
  ) async {
    await pumpGateApp(
      tester,
      bootstrap: const BootstrapUnavailable(),
      withPolicy: false,
    );

    final button = tester.widget<PakPrimaryButton>(
      find.byType(PakPrimaryButton),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text('Không mở được dữ liệu của app. Hãy khởi động lại app.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(PakPrimaryButton));
    await tester.pumpAndSettle();
    expect(find.byType(CreateAccountScreen), findsNothing);
  });

  testWidgets('ux_dr32_s1_pushes_s2_with_back_chevron_only', (tester) async {
    await pumpGateApp(tester, service: FakeAccountService());
    await openCreateScreen(tester);

    expect(find.byType(CreateAccountScreen), findsOneWidget);
    final nav = tester.widget<CupertinoNavigationBar>(
      find.byType(CupertinoNavigationBar),
    );
    expect(nav.previousPageTitle, isNull);
    expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
    // Nút back chỉ có chevron (glyph icon), không chữ: S1 không có tiêu đề.
    expect(
      find.descendant(
        of: find.byType(CupertinoNavigationBarBackButton),
        matching: find.textContaining(RegExp('[A-Za-zÀ-ỹ]')),
      ),
      findsNothing,
    );

    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(find.byType(CreateAccountScreen), findsNothing);
    expect(find.text('PAK Manager'), findsOneWidget);
  });

  testWidgets('ux_dr50_android_back_pops_s2_then_leaves_s1_to_os', (
    tester,
  ) async {
    await pumpGateApp(tester, service: FakeAccountService());
    await openCreateScreen(tester);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(CreateAccountScreen), findsNothing);

    // Ở gốc: gate không giữ Back, để OS xử lý.
    final gate = tester.state<SessionGateState>(find.byType(SessionGate));
    expect(await gate.didPopRoute(), isFalse);
  });

  testWidgets('fr45_ad23_create_success_replaces_tree_with_three_tab_shell', (
    tester,
  ) async {
    final service = FakeAccountService();
    await pumpGateApp(tester, service: service);
    await openCreateScreen(tester);
    final gate = tester.state<SessionGateState>(find.byType(SessionGate));
    expect(gate.epoch, 0);

    final fields = tester
        .widgetList<SecretField>(find.byType(SecretField))
        .map((f) => f.controller)
        .toList();
    expect(fields, hasLength(2));

    final session = fakeSession();
    await _createWith(tester, service, CreateSuccess(session));

    // Cây cũ (S1, S2, mọi SecretField) đã bị gỡ; controller đã xóa.
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(CreateAccountScreen), findsNothing);
    expect(find.byType(SecretField), findsNothing);
    for (final controller in fields) {
      expect(controller.text, isEmpty);
    }
    expect(gate.epoch, 1);
    expect(gate.session, same(session));
    expect(
      find.ancestor(
        of: find.byType(HomeShell),
        matching: find.byKey(const ValueKey<int>(1)),
      ),
      findsOneWidget,
    );

    // Khung 3 tab, mặc định tab Quản lý mật khẩu.
    expect(find.byType(CupertinoTabScaffold), findsOneWidget);
    final bar = tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar));
    expect(bar.items.map((i) => i.label), [
      'Quản lý mật khẩu',
      'Tạo mật khẩu',
      'Cài đặt',
    ]);
    expect(bar.currentIndex, 0);
    expect(find.byType(CupertinoTabView), findsOneWidget);
    final title = tester.widget<CupertinoNavigationBar>(
      find.byType(CupertinoNavigationBar),
    );
    expect((title.middle! as Text).data, 'Quản lý mật khẩu');
  });

  testWidgets('fr45_each_tab_has_own_navigator_and_title', (tester) async {
    final service = FakeAccountService();
    await pumpGateApp(tester, service: service);
    await openCreateScreen(tester);
    await _createWith(tester, service, CreateSuccess(fakeSession()));

    await tester.tap(find.text('Tạo mật khẩu'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar)).currentIndex,
      1,
    );
    // Tab 2 có tiêu đề `generator.title` (vi trùng nhãn tab).
    expect(
      find.byType(CupertinoTabView, skipOffstage: false),
      findsNWidgets(2),
    );

    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    expect(
      find.byType(CupertinoTabView, skipOffstage: false),
      findsNWidgets(3),
    );
    // Mỗi tab có navigator riêng, dưới navigator gốc của phiên.
    expect(find.byType(Navigator, skipOffstage: false), findsNWidgets(4));
  });

  testWidgets('ux_dr29_ux_dr06_tab_bar_visuals', (tester) async {
    final service = FakeAccountService();
    await pumpGateApp(tester, service: service);
    await openCreateScreen(tester);
    await _createWith(tester, service, CreateSuccess(fakeSession()));

    final bar = tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar));
    expect(bar.height, 49);
    expect(bar.iconSize, 26);
    expect(bar.backgroundColor, PakColors.surfaceToolbar);
    expect(bar.activeColor, PakColors.accent);
    expect(bar.inactiveColor, PakColors.inkTabInactive);
    expect(bar.border?.top.color, PakColors.separator);

    // Icon vẽ bằng CustomPainter theo màu IconTheme: tab chọn = accent.
    final painters = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(PakTabIcon),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((p) => p.painter! as PakTabIconPainter)
        .toList();
    expect(painters.map((p) => p.glyph), PakTabGlyph.values);
    expect(painters[0].color.toARGB32(), PakColors.accent.color.toARGB32());
    for (final inactive in painters.skip(1)) {
      expect(
        inactive.color.toARGB32(),
        PakColors.inkTabInactive.color.toARGB32(),
      );
    }
    for (final icon in find.byType(PakTabIcon).evaluate()) {
      expect(tester.getSize(find.byWidget(icon.widget)), const Size(26, 26));
    }
  });

  testWidgets('fr45_gate_disposes_session_with_tree', (tester) async {
    final service = FakeAccountService();
    await pumpGateApp(tester, service: service);
    await openCreateScreen(tester);
    final dek = FakeSecureKey();
    await _createWith(tester, service, CreateSuccess(fakeSession(dek)));
    expect(dek.disposed, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(dek.disposed, isTrue);
  });
}
