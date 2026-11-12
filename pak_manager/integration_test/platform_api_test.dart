// Integration test cho API Pigeon native (AD-14, AD-11, NFR-8), chạy trên
// emulator Android / simulator iOS thật:
//   flutter test integration_test --flavor dev   (Android)
//   flutter test integration_test -d <udid>      (iOS)
//
// Gọi thẳng mọi phương thức của `PlatformApi`: nếu native bỏ đăng ký
// (`PlatformApi.setUp` trên Android, `PlatformApiSetup.setUp` trên iOS) thì
// Pigeon ném `PlatformException(channel-error)` và test fail.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pak_manager/platform/path_provider_directory.dart';
import 'package:pak_manager/platform/pigeon_ports.dart';
import 'package:pak_manager/platform/platform_api.g.dart';
import 'package:pak_manager/services/storage_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Chạy bootstrap với adapter thật; trả `pakDir` khi `StorageReady`.
  Future<String> bootstrapPakDir() async {
    final result = await StorageBootstrap(
      directories: const PathProviderDirectory(),
      backup: PigeonPlatformPorts(),
    ).run();
    expect(result, isA<StorageReady>(), reason: 'bootstrap: $result');
    return (result as StorageReady).paths.pakDir;
  }

  testWidgets('ad14_all_channels_reply', (tester) async {
    final api = PlatformApi();

    // bootId: chuỗi, có thể rỗng khi không đọc được.
    final bootId = await api.bootId();
    expect(bootId, isA<String>());

    // monotonicMs: dương và không giảm giữa hai lần gọi.
    final t1 = await api.monotonicMs();
    final t2 = await api.monotonicMs();
    expect(t1, greaterThan(0));
    expect(t2, greaterThanOrEqualTo(t1));

    // androidSdkInt: ≥ 24 trên Android (minSdk), 0 trên iOS.
    final sdk = await api.androidSdkInt();
    if (Platform.isAndroid) {
      expect(sdk, greaterThanOrEqualTo(24));
    } else {
      expect(sdk, 0);
    }

    // excludeFromBackup, fsyncDirectory, isExcludedFromBackup trên thư mục tạm
    // riêng (không đụng `pak/`, để ad11 chỉ kiểm cờ do bootstrap đặt).
    final tmp = await Directory.systemTemp.createTemp('pak_it_');
    try {
      await api.excludeFromBackup(tmp.path);
      await api.fsyncDirectory(tmp.path);
      final excluded = await api.isExcludedFromBackup(tmp.path);
      // Android không có cờ theo thư mục (manifest lo); iOS phải đọc được cờ.
      expect(excluded, Platform.isIOS ? isTrue : isFalse);
    } finally {
      await tmp.delete(recursive: true);
    }
  });

  testWidgets('nfr8_storage_bootstrap_ready', (tester) async {
    final pakDir = await bootstrapPakDir();
    expect(Directory(pakDir).existsSync(), isTrue);
  });

  testWidgets(
    'ad11_pak_excluded_from_backup_ios',
    (tester) async {
      final pakDir = await bootstrapPakDir();
      // Đọc lại độc lập với phần tự kiểm trong `excludeFromBackup`.
      expect(await PlatformApi().isExcludedFromBackup(pakDir), isTrue);
    },
    // Android: không có cờ tương ứng; manifest đã có cổng APK.
    skip: !Platform.isIOS,
  );
}
