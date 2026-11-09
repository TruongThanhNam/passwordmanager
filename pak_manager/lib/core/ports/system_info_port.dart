/// Thông tin nền tảng cần để dựng giao diện hệ thống (AD-14).
abstract interface class SystemInfoPort {
  /// API level Android (`Build.VERSION.SDK_INT`); iOS trả `0`.
  Future<int> androidSdkInt();
}
