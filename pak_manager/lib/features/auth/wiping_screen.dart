import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/account_service.dart';
import '../shared/providers.dart';
import '../shared/theme/pak_colors.dart';
import '../shared/theme/pak_text_styles.dart';

/// Khe giữa activity-indicator và dòng `wiping` (UX-DR32).
const double wipingGap = 14;

/// S5 (UX-DR32): toàn màn, nền `surface-base`, activity-indicator và một
/// dòng `wiping` căn giữa, không nút. Back bị chặn (`PopScope`).
///
/// Tự gọi [AccountService.wipe] đúng một lần ở `initState` (rebuild không
/// chạy lại) rồi báo [onFinished]; gate đã gỡ màn trong lúc xóa thì kết quả
/// bị bỏ qua (việc xóa vẫn chạy tới cùng, `wiping` còn trên đĩa nếu lỗi).
class WipingScreen extends ConsumerStatefulWidget {
  const WipingScreen({super.key, required this.onFinished});

  /// Xóa xong: [WipeDone] hoặc [WipeFailed].
  final ValueChanged<WipeResult> onFinished;

  @override
  ConsumerState<WipingScreen> createState() => _WipingScreenState();
}

class _WipingScreenState extends ConsumerState<WipingScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_wipe());
  }

  Future<void> _wipe() async {
    final service = ref.read(accountServiceProvider);
    final WipeResult result;
    if (service == null) {
      // Không có dịch vụ thì không thể xóa: fail closed. Chờ một microtask để
      // `onFinished` không chạy giữa lúc dựng cây.
      await Future<void>.value();
      result = const WipeFailed();
    } else {
      result = await service.wipe();
    }
    if (!mounted) {
      return;
    }
    widget.onFinished(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: CupertinoPageScaffold(
        backgroundColor: PakColors.surfaceBase,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(),
              const SizedBox(height: wipingGap),
              Text(
                l10n.wiping,
                textAlign: TextAlign.center,
                style: PakTextStyles.body.copyWith(color: PakColors.inkPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
