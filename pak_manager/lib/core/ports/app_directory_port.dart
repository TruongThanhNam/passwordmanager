/// Thư mục gốc dữ liệu riêng của app (AD-11).
abstract interface class AppDirectoryPort {
  /// Đường dẫn tuyệt đối của `ApplicationSupport`; ném exception khi lỗi.
  Future<String> applicationSupportPath();
}
