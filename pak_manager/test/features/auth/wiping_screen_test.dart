import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/model/settings.dart';
import 'package:pak_manager/features/auth/login_screen.dart';
import 'package:pak_manager/features/auth/wiping_screen.dart';
import 'package:pak_manager/features/shared/pak_buttons.dart';
import 'package:pak_manager/features/shared/secret_field.dart';
import 'package:pak_manager/features/shared/theme/pak_colors.dart';
import 'package:pak_manager/services/account_service.dart';

import '../../support/account_fakes.dart';

const _wipingVi = 'Đang xóa dữ liệu…';

/// App thật với bootstrap [BootstrapWiping]: S5 hiện ngay, `wipe()` treo tới
/// khi test gọi `completeWipe`.
Future<FakeAccountService> _pumpS5(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.vi,
}) async {
  final service = FakeAccountService(bootstrapResult: const BootstrapWiping());
  await pumpGateApp(
    tester,
    bootstrap: const BootstrapWiping(),
    service: service,
    language: language,
  );
  await tester.pump();
  return service;
}

void main() {
  testWidgets('ux_dr32_s5_shows_only_indicator_and_wiping_line', (
    tester,
  ) async {
    await _pumpS5(tester);

    expect(find.byType(WipingScreen), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text(_wipingVi), findsOneWidget);
    // Không nút, không ô, không tên app, không thanh điều hướng.
    expect(find.byType(CupertinoButton), findsNothing);
    expect(find.byType(PakPrimaryButton), findsNothing);
    expect(find.byType(SecretField), findsNothing);
    expect(find.byType(CupertinoNavigationBar), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .toList();
    expect(texts, [_wipingVi]);
  });

  testWidgets('ux_dr32_s5_background_is_surface_base', (tester) async {
    await _pumpS5(tester);

    final scaffold = tester.widget<CupertinoPageScaffold>(
      find.byType(CupertinoPageScaffold),
    );
    expect(scaffold.backgroundColor, PakColors.surfaceBase);
  });

  testWidgets('ux_dr32_s5_indicator_and_line_centered_with_gap_14', (
    tester,
  ) async {
    await _pumpS5(tester);

    final screen = tester.getRect(find.byType(CupertinoPageScaffold));
    final indicator = tester.getRect(find.byType(CupertinoActivityIndicator));
    final text = tester.getRect(find.text(_wipingVi));
    expect(indicator.center.dx, closeTo(screen.center.dx, 0.5));
    expect(text.center.dx, closeTo(screen.center.dx, 0.5));
    expect(text.top - indicator.bottom, 14);
    // Khối hai phần nằm giữa màn theo chiều dọc.
    final blockCenter = (indicator.top + text.bottom) / 2;
    expect(blockCenter, closeTo(screen.center.dy, 0.5));
  });

  testWidgets('ux_dr32_s5_en_string', (tester) async {
    await _pumpS5(tester, language: AppLanguage.en);

    expect(find.text('Erasing data…'), findsOneWidget);
  });

  testWidgets('ux_dr32_s5_back_is_blocked_while_wiping', (tester) async {
    final service = await _pumpS5(tester);

    // Android Back: gate chuyển cho navigator, `PopScope` chặn; không thoát.
    final handled = await tester.binding.handlePopRoute();
    await tester.pump();

    expect(handled, isTrue);
    expect(find.byType(WipingScreen), findsOneWidget);
    expect(service.wipeCalls, 1);
  });

  testWidgets('ad21_s5_calls_wipe_exactly_once_even_after_rebuilds', (
    tester,
  ) async {
    final service = await _pumpS5(tester);
    expect(service.wipeCalls, 1);

    // Xoay/đổi cỡ màn và pump nhiều lần: rebuild không chạy lại `wipe()`.
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(service.wipeCalls, 1);
  });

  testWidgets('ad21_s5_disposed_before_wipe_finishes_is_safe', (tester) async {
    final service = await _pumpS5(tester);

    // Gate bị gỡ khi lần xóa còn treo.
    await tester.pumpWidget(const SizedBox());
    service.completeWipe();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(service.wipeCalls, 1);
  });

  testWidgets('ad21_s5_without_service_fails_closed_to_s1_unavailable', (
    tester,
  ) async {
    await pumpGateApp(tester, bootstrap: const BootstrapWiping());
    await tester.pumpAndSettle();

    // Không có dịch vụ thì không xóa được: S1 vô hiệu, không kẹt ở S5.
    expect(find.byType(WipingScreen), findsNothing);
    expect(
      tester.widget<PakPrimaryButton>(find.byType(PakPrimaryButton)).onPressed,
      isNull,
    );
  });
}
