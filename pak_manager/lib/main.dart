import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium_sumo.dart';

import 'core/crypto/random_source.dart';
import 'core/io/atomic_file_writer.dart';
import 'core/io/pak_paths.dart';
import 'core/policy/blocklist_filter.dart';
import 'core/policy/password_policy.dart';
import 'core/policy/strength_estimator.dart';
import 'core/ports/file_sync_port.dart';
import 'core/ports/system_info_port.dart';
import 'error_policy.dart';
import 'features/shared/orientation.dart';
import 'features/shared/pak_app.dart';
import 'features/shared/providers.dart';
import 'platform/path_provider_directory.dart';
import 'platform/pigeon_ports.dart';
import 'services/account_service.dart';
import 'services/settings_store.dart';
import 'services/storage_bootstrap.dart';

/// Asset Bloom filter blocklist (AD-15).
const blocklistAsset = 'assets/blocklist.bloom';

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
/// nạp `settings` trước frame đầu (AD-13) → nối tài khoản (Sodium, blocklist,
/// `AccountService.bootstrap`) → đọc API Android → `runApp`. Không bước nào
/// ném ra trước `runApp`: lưu trữ lỗi thì `settings` chỉ ở RAM với giá trị
/// mặc định; lưu trữ, Sodium hoặc blocklist lỗi thì `SessionGate` nhận
/// `BootstrapUnavailable` (fail closed, không đọc/ghi vault); không đọc được
/// API Android thì dùng `0` (style an toàn nhất).
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
    final result = await storage.run();
    final writer = AtomicFileWriter(fileSync);
    final settings = await SettingsStore.load(switch (result) {
      StorageReady(:final paths) => paths.settingsFile,
      StorageUnavailable() => null,
    }, writer);
    final account = switch (result) {
      StorageReady(:final paths) => await _wireAccount(
        paths,
        writer: writer,
        fileSync: fileSync,
      ),
      StorageUnavailable() => const _AccountWiring.unavailable(),
    };
    final androidSdkInt = await _readAndroidSdkInt(systemInfo);
    runApp(
      ProviderScope(
        overrides: [
          accountServiceProvider.overrideWithValue(account.service),
          passwordPolicyProvider.overrideWithValue(account.policy),
          if (account.estimator case final estimator?)
            strengthEstimatorProvider.overrideWithValue(estimator),
          bootstrapResultProvider.overrideWithValue(account.bootstrap),
        ],
        child: PakApp(settings: settings, androidSdkInt: androidSdkInt),
      ),
    );
  }, releaseMode: releaseMode);
}

/// Những gì `SessionGate` cần từ tầng dưới.
final class _AccountWiring {
  const _AccountWiring({
    required this.service,
    required this.policy,
    required this.estimator,
    required this.bootstrap,
  });

  /// Fail closed: không có dịch vụ, không có luật, không đọc/ghi vault.
  const _AccountWiring.unavailable()
    : service = null,
      policy = null,
      estimator = null,
      bootstrap = const BootstrapUnavailable();

  final AccountService? service;
  final PasswordPolicy? policy;
  final StrengthEstimator? estimator;
  final BootstrapResult bootstrap;
}

/// Nối `AccountService` khi lưu trữ đã sẵn sàng: khởi tạo Sodium, nạp
/// blocklist, dựng `StrengthEstimator` (làm nóng từ điển) rồi chạy
/// `bootstrap()` (chỉ kiểm `vault/header`, nên không cần màn chờ, UX-DR30).
/// Sodium hoặc blocklist lỗi → [_AccountWiring.unavailable]. Không ném.
Future<_AccountWiring> _wireAccount(
  PakPaths paths, {
  required AtomicFileWriter writer,
  required FileSyncPort fileSync,
}) async {
  final SodiumSumo sodium;
  try {
    sodium = await SodiumSumoInit.init();
  } on Object {
    return const _AccountWiring.unavailable();
  }
  final BlocklistFilter? blocklist;
  try {
    final data = await rootBundle.load(blocklistAsset);
    blocklist = BlocklistFilter.parse(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } on Object {
    return const _AccountWiring.unavailable();
  }
  if (blocklist == null) {
    return const _AccountWiring.unavailable();
  }
  final StrengthEstimator estimator;
  try {
    estimator = StrengthEstimator();
  } on Object {
    return const _AccountWiring.unavailable();
  }
  final service = AccountService(
    sodium: sodium,
    random: SodiumRandomSource(sodium),
    writer: writer,
    fileSync: fileSync,
    paths: paths,
  );
  final bootstrap = await service.bootstrap();
  if (bootstrap is BootstrapUnavailable) {
    return const _AccountWiring.unavailable();
  }
  return _AccountWiring(
    service: service,
    policy: PasswordPolicy(blocklist),
    estimator: estimator,
    bootstrap: bootstrap,
  );
}

Future<int> _readAndroidSdkInt(SystemInfoPort systemInfo) async {
  try {
    return await systemInfo.androidSdkInt();
  } on Object {
    return 0;
  }
}
