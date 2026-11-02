// Nguồn duy nhất của API Pigeon (AD-14). Sinh lại trong pak_manager/:
//   dart run pigeon --input pigeons/platform_api.dart
// CI chạy lại lệnh trên và fail nếu file sinh ra khác bản đã commit.
//
// `@HostApi` đồng bộ, kênh mặc định, không FFI/JNI. Chỉ ba nhóm: đồng hồ,
// backup, fsync thư mục. Clipboard thêm ở Epic 3.
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

  /// `open(O_RDONLY)` + `fsync` + `close` trên thư mục [dirPath] để rename
  /// trong thư mục đó bền qua mất điện.
  void fsyncDirectory(String dirPath);
}
