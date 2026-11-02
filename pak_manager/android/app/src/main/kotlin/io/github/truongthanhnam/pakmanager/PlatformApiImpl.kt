package io.github.truongthanhnam.pakmanager

import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import android.system.Os
import android.system.OsConstants

/**
 * Cài API Pigeon `PlatformApi` cho Android (AD-14): đồng hồ, backup, fsync thư mục.
 * Không lưu bất kỳ dữ liệu hay bí mật nào (FR-11).
 */
class PlatformApiImpl(context: Context) : PlatformApi {
  private val appContext = context.applicationContext

  /** `Settings.Global.BOOT_COUNT`; không đọc được thì trả `""` (AD-8). */
  override fun bootId(): String =
    try {
      Settings.Global.getInt(appContext.contentResolver, Settings.Global.BOOT_COUNT).toString()
    } catch (e: Exception) {
      ""
    }

  /** Đồng hồ đơn điệu tính cả lúc máy ngủ. */
  override fun monotonicMs(): Long = SystemClock.elapsedRealtime()

  /**
   * No-op: manifest đặt `allowBackup=false`, `dataExtractionRules` và
   * `fullBackupContent` loại mọi domain (AD-11).
   */
  override fun excludeFromBackup(dirPath: String) {}

  /** `open(O_RDONLY)` + `fsync` + `close`; lỗi ném `ErrnoException` về Dart. */
  override fun fsyncDirectory(dirPath: String) {
    val fd = Os.open(dirPath, OsConstants.O_RDONLY, 0)
    try {
      Os.fsync(fd)
    } finally {
      Os.close(fd)
    }
  }
}
