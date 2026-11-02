import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

import 'error_policy.dart';
import 'platform/path_provider_directory.dart';
import 'platform/pigeon_ports.dart';
import 'services/storage_bootstrap.dart';

/// Composition root duy nhất: file duy nhất ngoài `lib/platform/` được import
/// `lib/platform/` để nối adapter vào port (AD-2).
void main() {
  runPakApp(
    StorageBootstrap(
      directories: const PathProviderDirectory(),
      backup: PigeonPlatformPorts(),
    ),
    releaseMode: kReleaseMode,
  );
}

/// Chạy app theo chính sách lỗi (AD-18): khởi động lưu trữ xong mới `runApp`
/// (AD-11), cùng zone với `ensureInitialized`.
void runPakApp(StorageBootstrap storage, {required bool releaseMode}) {
  runWithErrorPolicy(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Kết quả chưa có nơi dùng; story 1.6 nối vào `SessionGate`, nơi
    // `StorageUnavailable` chặn mọi đọc/ghi dữ liệu.
    await storage.run();
    runApp(const PakApp());
  }, releaseMode: releaseMode);
}

/// Gốc ứng dụng. Story 1.1 chỉ dựng khung rỗng; `SessionGate`, theme và
/// localization được thêm ở các story sau (AD-23).
class PakApp extends StatelessWidget {
  const PakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: CupertinoPageScaffold(child: SizedBox.shrink()),
    );
  }
}
