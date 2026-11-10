import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/model/settings.dart';
import 'package:pak_manager/features/settings/settings_screen.dart';
import 'package:pak_manager/features/shared/content_column.dart';
import 'package:pak_manager/features/shared/pak_buttons.dart';
import 'package:pak_manager/features/shared/theme/pak_colors.dart';
import 'package:pak_manager/features/shared/theme/pak_radius.dart';
import 'package:pak_manager/features/shared/theme/pak_spacing.dart';

import '../../support/account_fakes.dart';

Future<void> _openSettings(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.vi,
}) async {
  final service = FakeAccountService();
  await pumpGateApp(tester, service: service, language: language);
  await createAndEnterShell(tester, service);
  await tester.tap(
    find.text(language == AppLanguage.vi ? 'Cài đặt' : 'Settings'),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fr49_ux_dr36_settings_shows_only_lock_vault_block', (
    tester,
  ) async {
    await _openSettings(tester);

    expect(find.byType(SettingsScreen), findsOneWidget);
    final nav = tester.widget<CupertinoNavigationBar>(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(CupertinoNavigationBar),
      ),
    );
    expect((nav.middle! as Text).data, 'Cài đặt');
    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .toList();
    expect(texts, unorderedEquals(['Cài đặt', 'Khóa Vault']));
    expect(find.byType(PakTextButton), findsOneWidget);
    expect(find.textContaining(RegExp('Sign out|Đăng xuất')), findsNothing);
  });

  testWidgets('ux_dr36_lock_vault_cell_visuals', (tester) async {
    // Khổ điện thoại: cột nội dung rộng hết màn.
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _openSettings(tester);

    final scaffold = tester.widget<CupertinoPageScaffold>(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(CupertinoPageScaffold),
      ),
    );
    expect(scaffold.backgroundColor, PakColors.surfaceGrouped);

    final cellFinder = find.byKey(const ValueKey('settings.lockVault.cell'));
    final cell = tester.widget<Container>(cellFinder);
    final decoration = cell.decoration! as BoxDecoration;
    expect(
      decoration.color!.toARGB32(),
      PakColors.surfaceRaised.color.toARGB32(),
    );
    expect(decoration.borderRadius, BorderRadius.circular(PakRadius.md));

    final rect = tester.getRect(cellFinder);
    expect(rect.height, 44);
    final screen = tester.getRect(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(ContentColumn),
      ),
    );
    expect(rect.left - screen.left, 16);
    expect(screen.right - rect.right, 16);
    final navRect = tester.getRect(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(CupertinoNavigationBar),
      ),
    );
    expect(rect.top - navRect.bottom, PakSpacing.sectionGap);

    // button-text: chữ accent, nằm trong ô.
    final label = tester.widget<Text>(find.text('Khóa Vault'));
    expect(label.style!.color!.toARGB32(), PakColors.accent.color.toARGB32());
    expect(
      find.descendant(of: cellFinder, matching: find.byType(PakTextButton)),
      findsOneWidget,
    );
  });

  testWidgets('fr49_lock_vault_label_english', (tester) async {
    await _openSettings(tester, language: AppLanguage.en);
    expect(find.text('Lock Vault'), findsOneWidget);
  });
}
