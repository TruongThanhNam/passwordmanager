// Fake dùng chung cho port, timer và `SecureKey`: Dart thuần, không phụ
// thuộc Flutter, nên test core, service lẫn UI đều dùng được. Không gọi
// libsodium thật hay plugin; chỉ dữ liệu giả.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:pak_manager/core/ports/app_directory_port.dart';
import 'package:pak_manager/core/ports/backup_port.dart';
import 'package:pak_manager/core/ports/clock_port.dart';
import 'package:pak_manager/core/ports/file_sync_port.dart';
import 'package:pak_manager/core/ports/system_info_port.dart';
import 'package:sodium/sodium_sumo.dart';

/// `SecureKey` giả [length] byte toàn 0 (mặc định 32), chỉ ghi nhận
/// `dispose`.
final class FakeSecureKey implements SecureKey {
  FakeSecureKey({this.length = 32});

  @override
  final int length;

  bool disposed = false;

  @override
  void dispose() => disposed = true;

  @override
  T runUnlockedSync<T>(SecureCallbackFn<T> callback, {bool writable = false}) =>
      callback(Uint8List(length));

  @override
  FutureOr<T> runUnlockedAsync<T>(
    SecureCallbackFn<FutureOr<T>> callback, {
    bool writable = false,
  }) => callback(Uint8List(length));

  @override
  Uint8List extractBytes() => Uint8List(length);

  @override
  SecureKey copy() => FakeSecureKey(length: length);
}

/// Đồng hồ đơn điệu giả: [ms] đặt tay; [error] khác `null` thì ném. [boot]
/// là `bootId` (đổi tay để mô phỏng khởi động lại máy); [bootError] khác
/// `null` thì `bootId()` ném.
final class FakeClock implements ClockPort {
  FakeClock([this.ms = 1000000]);

  int ms;
  Object? error;

  String boot = 'fake-boot';
  Object? bootError;

  /// Khác `null` thì [monotonicMs] chờ nó rồi mới đọc [ms]/[error].
  Completer<void>? hold;

  /// Số lần đọc [monotonicMs].
  int reads = 0;

  void advance(Duration d) => ms += d.inMilliseconds;

  @override
  Future<int> monotonicMs() async {
    reads++;
    final gate = hold;
    if (gate != null) {
      await gate.future;
    }
    final e = error;
    if (e != null) {
      Error.throwWithStackTrace(e, StackTrace.current);
    }
    return ms;
  }

  @override
  Future<String> bootId() async {
    final e = bootError;
    if (e != null) {
      Error.throwWithStackTrace(e, StackTrace.current);
    }
    return boot;
  }
}

/// Timer giả do [FakeTimers.create] dựng; chỉ chạy khi test gọi [fire].
final class FakeTimer implements Timer {
  FakeTimer(this.duration, this._wake);

  final Duration duration;
  final void Function() _wake;
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;

  void fire() {
    if (_active) {
      _active = false;
      _wake();
    }
  }
}

/// Nhà máy timer giả (tear-off [create] thay cho `Timer.new`): không timer
/// nào tự chạy, test bắn bằng [FakeTimer.fire] hoặc [fireAll].
final class FakeTimers {
  final List<FakeTimer> created = [];

  Timer create(Duration duration, void Function() wake) {
    final timer = FakeTimer(duration, wake);
    created.add(timer);
    return timer;
  }

  /// Timer còn hiệu lực.
  List<FakeTimer> get active => created.where((t) => t.isActive).toList();

  /// Bắn mọi timer còn hiệu lực.
  void fireAll() {
    for (final t in active) {
      t.fire();
    }
  }
}

/// fsync thư mục giả: mỗi lần gọi ghi đường dẫn vào [calls], gọi [onCall]
/// rồi ném [error] nếu [failAlways] hoặc đây là lần gọi thứ [failAt] (đếm
/// từ 1).
final class RecordingFileSync implements FileSyncPort {
  RecordingFileSync({
    this.failAt,
    this.failAlways = false,
    this.onCall,
    this.error = const FileSystemException('fsync giả lỗi'),
  });

  final int? failAt;
  final bool failAlways;

  /// Chạy sau khi ghi [calls], trước khi (có thể) ném; ví dụ để chụp trạng
  /// thái file lúc fsync.
  final void Function(String path)? onCall;

  /// Lỗi ném ra khi fsync thất bại.
  final Object error;

  /// Đường dẫn của từng lần gọi, theo thứ tự.
  final List<String> calls = [];

  @override
  Future<void> fsyncDirectory(String path) async {
    calls.add(path);
    onCall?.call(path);
    if (failAlways || calls.length == failAt) {
      Error.throwWithStackTrace(error, StackTrace.current);
    }
  }
}

/// Cờ loại khỏi backup giả: chỉ ghi đường dẫn vào [calls].
final class RecordingBackup implements BackupPort {
  /// Thư mục của từng lần gọi, theo thứ tự.
  final List<String> calls = [];

  @override
  Future<void> excludeFromBackup(String dirPath) async => calls.add(dirPath);
}

/// API Android giả: trả [sdkInt]; `null` thì ném [error] (mặc định
/// `StateError`) như kênh nền tảng lỗi.
final class FakeSystemInfo implements SystemInfoPort {
  FakeSystemInfo(this.sdkInt, {this.error});

  final int? sdkInt;

  /// Lỗi ném ra khi [sdkInt] là `null`.
  final Object? error;

  @override
  Future<int> androidSdkInt() async {
    final value = sdkInt;
    if (value == null) {
      Error.throwWithStackTrace(
        error ?? StateError('API Android giả lỗi'),
        StackTrace.current,
      );
    }
    return value;
  }
}

/// Thư mục ứng dụng giả luôn lỗi (`StateError`).
final class FailingDirectory implements AppDirectoryPort {
  @override
  Future<String> applicationSupportPath() async =>
      throw StateError('không có thư mục');
}

/// Thư mục ứng dụng giả treo tới khi test hoàn tất [completer]; đếm số lần
/// gọi ở [calls].
final class PendingDirectory implements AppDirectoryPort {
  final Completer<String> completer = Completer<String>();
  int calls = 0;

  @override
  Future<String> applicationSupportPath() {
    calls++;
    return completer.future;
  }
}
