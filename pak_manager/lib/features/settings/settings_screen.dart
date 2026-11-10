import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../shared/content_column.dart';
import '../shared/pak_buttons.dart';
import '../shared/providers.dart';
import '../shared/theme/pak_colors.dart';
import '../shared/theme/pak_radius.dart';
import '../shared/theme/pak_spacing.dart';

/// S18 Cài đặt, bản tối thiểu (UX-DR36 khối 5, FR-49): chỉ khối "Khóa Vault"
/// là `button-text` trong một ô inset-grouped riêng. Các khối khác thêm ở
/// Epic 5. Bấm là khóa ngay, không hỏi; Khóa Vault cũng là Sign out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      backgroundColor: PakColors.surfaceGrouped,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.tabSettings),
        backgroundColor: PakColors.surfaceGrouped,
        border: null,
        automaticallyImplyLeading: false,
        automaticBackgroundVisibility: false,
      ),
      child: ContentColumn(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PakSpacing.margin,
            PakSpacing.sectionGap,
            PakSpacing.margin,
            0,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              key: const ValueKey('settings.lockVault.cell'),
              height: PakSpacing.rowHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: CupertinoDynamicColor.resolve(
                  PakColors.surfaceRaised,
                  context,
                ),
                borderRadius: BorderRadius.circular(PakRadius.md),
              ),
              child: PakTextButton(
                label: l10n.settingsLockVault,
                onPressed: () =>
                    unawaited(ref.read(sessionControllerProvider).lock()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
