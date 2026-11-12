// Nguồn duy nhất của API Pigeon (AD-14). Sinh lại trong pak_manager/:
//   dart run pigeon --input pigeons/platform_api.dart
// CI chạy lại lệnh trên và fail nếu file sinh ra khác bản đã commit.
//
// `@HostApi` đồng bộ, kênh mặc định, không FFI/JNI. Các nhóm: đồng hồ,
// backup, fsync thư mục, API level Android (style thanh hệ thống), đọc cờ backup (test). Clipboard
// thêm ở Epic 3.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/platform_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/app/src/main/kotlin/io/github/truongthanhnam/pakmanager/PlatformApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'io.github.truongthanhnam.pakmanager',
    ),
    swiftOut: 'ios/Runner/PlatformApi.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'pak_manager',
  ),
)
@HostApi()
abstract class PlatformApi {
  /// Định danh lần khởi động máy: Android `BOOT_COUNT`, iOS
  /// `kern.bootsessionuuid`. Không đọc được thì trả `""`.
  String bootId();

  /// Đồng hồ đơn điệu tính cả lúc máy ngủ, đơn vị ms: Android
  /// `SystemClock.elapsedRealtime()`, iOS `mach_continuous_time`.
  int monotonicMs();

  /// iOS: đặt `isExcludedFromBackup` cho [dirPath]. Android: no-op, manifest
  /// đã loại mọi domain khỏi backup.
  void excludeFromBackup(String dirPath);

  /// fsync thư mục [dirPath] để rename trong thư mục đó bền qua mất điện.
  /// Android: `open(O_RDONLY)` + `fsync` + `close`. iOS: `fcntl(F_FULLFSYNC)`
  /// (xả cả cache ổ đĩa), chỉ lùi về `fsync` khi `F_FULLFSYNC` không được hỗ
  /// trợ.
  void fsyncDirectory(String dirPath);

  /// API level Android (`Build.VERSION.SDK_INT`), để chọn style thanh điều
  /// hướng theo khả năng của máy. iOS trả `0`.
  int androidSdkInt();

  /// Chỉ đọc: iOS trả `isExcludedFromBackup` của [dirPath] (đọc lại từ đĩa, bỏ
  /// cache). Android trả `false` (không có cờ tương ứng, manifest lo backup).
  /// Dùng cho integration test (AD-11, AD-14).
  bool isExcludedFromBackup(String dirPath);
}
