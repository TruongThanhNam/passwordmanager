import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart';

import 'core/io/atomic_file_writer.dart';
import 'core/ports/file_sync_port.dart';
import 'core/ports/system_info_port.dart';
import 'error_policy.dart';
import 'features/shared/orientation.dart';
import 'features/shared/pak_app.dart';
import 'platform/path_provider_directory.dart';
import 'platform/pigeon_ports.dart';
import 'services/settings_store.dart';
import 'services/storage_bootstrap.dart';

/// Composition root duy nhất: file duy nhất ngoài `lib/platform/` được import
/// `lib/platform/` để nối adapter vào port (AD-2).
void main() {
  final ports = PigeonPlatformPorts();
  runPakApp(
    StorageBootstrap(directories: const PathProviderDirectory(), backup: ports),
    fileSync: ports,
    systemInfo: ports,
    releaseMode: kReleaseMode,
  );
}

/// Chạy app theo chính sách lỗi (AD-18), cùng zone với `ensureInitialized`.
///
/// Thứ tự: edge-to-edge → khóa hướng màn hình → khởi động lưu trữ (AD-11) →
/// nạp `settings` trước frame đầu (AD-13) → đọc API Android → `runApp`. Không
/// bước nào ném ra trước `runApp`: lưu trữ lỗi thì `settings` chỉ ở RAM với
/// giá trị mặc định; không đọc được API Android thì dùng `0` (style an toàn
/// nhất).
void runPakApp(
  StorageBootstrap storage, {
  required FileSyncPort fileSync,
  required SystemInfoPort systemInfo,
  required bool releaseMode,
}) {
  runWithErrorPolicy(() async {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    // Vẽ sau thanh hệ thống (Android < 15 không tự bật; chỉ có tác dụng từ
    // API 29, máy cũ hơn xem `pakSystemUiStyle`) để thanh trong suốt lộ nền
    // app thay vì nền cửa sổ. Lỗi bị nuốt, không chặn khởi động.
    try {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)
            .catchError((Object _) {}),
      );
    } on Object {
      // Giữ chế độ mặc định của hệ thống.
    }
    final view = binding.platformDispatcher.implicitView;
    if (view != null) {
      applyOrientationPolicy(view);
    }
    // Story 1.6 nối kết quả vào `SessionGate`, nơi `StorageUnavailable` chặn
    // mọi đọc/ghi dữ liệu vault.
    final result = await storage.run();
    final settings = await SettingsStore.load(switch (result) {
      StorageReady(:final paths) => paths.settingsFile,
      StorageUnavailable() => null,
    }, AtomicFileWriter(fileSync));
    final androidSdkInt = await _readAndroidSdkInt(systemInfo);
    runApp(PakApp(settings: settings, androidSdkInt: androidSdkInt));
  }, releaseMode: releaseMode);
}

Future<int> _readAndroidSdkInt(SystemInfoPort systemInfo) async {
  try {
    return await systemInfo.androidSdkInt();
  } on Object {
    return 0;
  }
}
