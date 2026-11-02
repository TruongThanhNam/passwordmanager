import Darwin
import Foundation

/// Cài API Pigeon `PlatformApi` cho iOS (AD-14): đồng hồ, backup, fsync thư mục.
///
/// Không dùng API "required reason" (`stat`/`fstat`, `creationDate`,
/// `systemUptime`, `mach_absolute_time`…) và không lưu bí mật nào (FR-11).
final class PlatformApiImpl: PlatformApi {
  /// `kern.bootsessionuuid`; không đọc được thì trả `""` (AD-8).
  func bootId() throws -> String {
    var size = 0
    guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 0 else {
      return ""
    }
    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname("kern.bootsessionuuid", &buffer, &size, nil, 0) == 0 else {
      return ""
    }
    let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    return String(decoding: bytes, as: UTF8.self)
  }

  /// `mach_continuous_time` (tính cả lúc máy ngủ) đổi sang ms theo timebase.
  func monotonicMs() throws -> Int64 {
    var timebase = mach_timebase_info_data_t()
    guard mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.denom != 0 else {
      throw PigeonError(code: "clock", message: "mach_timebase_info", details: nil)
    }
    let ticks = mach_continuous_time()
    let numer = UInt64(timebase.numer)
    let denom = UInt64(timebase.denom)
    // Chia trước rồi nhân để không tràn UInt64.
    let nanos = (ticks / denom) * numer + (ticks % denom) * numer / denom
    return Int64(nanos / 1_000_000)
  }

  /// Đặt `isExcludedFromBackup` cho thư mục rồi đọc lại để chắc cờ đã có (AD-11).
  func excludeFromBackup(dirPath: String) throws {
    var url = URL(fileURLWithPath: dirPath, isDirectory: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try url.setResourceValues(values)

    url.removeAllCachedResourceValues()
    let check = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
    guard check.isExcludedFromBackup == true else {
      throw PigeonError(code: "backup", message: "isExcludedFromBackup chưa được đặt", details: nil)
    }
  }

  /// `open(O_RDONLY)` + `fsync` + `close` trên thư mục (AD-13).
  func fsyncDirectory(dirPath: String) throws {
    let fd = open(dirPath, O_RDONLY)
    guard fd >= 0 else {
      throw PigeonError(code: "io", message: "open errno \(errno)", details: nil)
    }
    defer { close(fd) }
    guard fsync(fd) == 0 else {
      throw PigeonError(code: "io", message: "fsync errno \(errno)", details: nil)
    }
  }
}
