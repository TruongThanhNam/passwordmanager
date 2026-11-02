/// Loại dữ liệu app khỏi backup của OS (AD-11).
abstract interface class BackupPort {
  /// Đặt cờ loại khỏi backup cho [dirPath]; ném exception khi thất bại.
  Future<void> excludeFromBackup(String dirPath);
}
