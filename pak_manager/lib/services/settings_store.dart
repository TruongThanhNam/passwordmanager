import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/format/settings_codec.dart';
import '../core/io/atomic_file_writer.dart';
import '../core/model/settings.dart';

/// Tạo timer gom ghi; test thay bằng timer giả.
typedef SettingsTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

/// Hàm ghi file; mặc định là [AtomicFileWriter.write].
typedef SettingsWriteFn = Future<AtomicWriteResult> Function(
  String path,
  List<int> bytes,
);

/// Chủ duy nhất của file `settings` (AD-13, AD-20).
///
/// - Nạp một lần trước frame đầu ([load]); bản trong RAM ([current]) là nguồn
///   sự thật.
/// - Mỗi thay đổi bật cờ [dirty] và hẹn ghi sau [debounce], tính từ thay đổi
///   đầu tiên (không gia hạn khi có thay đổi tiếp).
/// - Mọi lần ghi đi qua một hàng đợi tuần tự; nội dung ghi là snapshot lấy lúc
///   lần ghi bắt đầu chạy. Ghi lỗi thì giữ [dirty]; [flush] hoặc [update] kế
///   tiếp ghi lại.
/// - Không bao giờ ném. `path == null` (lưu trữ không dùng được) thì chỉ ở RAM,
///   không I/O.
final class SettingsStore extends ChangeNotifier {
  SettingsStore._(
    this._path,
    this._write,
    this._current, {
    required this._createTimer,
  });

  /// Store chỉ ở RAM, không I/O. Dùng cho test và khi không có lưu trữ.
  SettingsStore.inMemory([Settings initial = Settings.defaults])
    : this._(null, null, initial, createTimer: Timer.new);

  /// Khoảng gom ghi.
  static const debounce = Duration(milliseconds: 300);

  /// File lớn hơn mức này bị coi là hỏng (toàn bộ mặc định).
  static const maxFileBytes = 64 * 1024;

  /// Đọc `settings` tại [path] (tối đa [maxFileBytes]) rồi tạo store.
  ///
  /// Không có file, đọc lỗi, `path` là thư mục hay file quá lớn đều cho
  /// [Settings.defaults]. Chỉ đọc, không bao giờ ghi. Không ném.
  static Future<SettingsStore> load(
    String? path,
    AtomicFileWriter writer, {
    SettingsTimerFactory createTimer = Timer.new,
    SettingsWriteFn? write,
  }) async {
    var settings = Settings.defaults;
    if (path != null) {
      final bytes = await _readCapped(path);
      if (bytes != null) {
        settings = SettingsCodec.decode(bytes);
      }
    }
    return SettingsStore._(
      path,
      write ?? writer.write,
      settings,
      createTimer: createTimer,
    );
  }

  final String? _path;
  final SettingsWriteFn? _write;
  final SettingsTimerFactory _createTimer;

  Settings _current;
  bool _dirty = false;

  /// Tăng ở mỗi thay đổi; lần ghi chỉ tắt [dirty] khi không có thay đổi mới
  /// trong lúc ghi.
  int _revision = 0;
  Timer? _timer;
  Future<void> _queue = Future<void>.value();
  bool _disposed = false;

  Settings get current => _current;

  /// `true` khi RAM có thay đổi chưa ghi thành công xuống file.
  bool get dirty => _dirty;

  /// Áp [change] lên [current] mới nhất.
  ///
  /// Kết quả không hợp lệ ([Settings.isValid]) thì trả `false` và không đổi
  /// gì. Kết quả bằng [current] thì không notify, nhưng vẫn hẹn ghi lại nếu
  /// còn [dirty] (lần ghi trước lỗi).
  bool update(Settings Function(Settings current) change) {
    final next = change(_current);
    if (!next.isValid) {
      return false;
    }
    if (next != _current) {
      _current = next;
      _revision++;
      if (_path != null) {
        _dirty = true;
      }
      notifyListeners();
    }
    if (_dirty) {
      _schedule();
    }
    return true;
  }

  /// Ghi ngay nếu còn thay đổi chưa ghi, rồi chờ hàng đợi ghi xong. Không ném.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (_dirty) {
      _enqueue();
    }
    return _queue;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _schedule() {
    if (_path == null || _timer != null || _disposed) {
      return;
    }
    _timer = _createTimer(debounce, () {
      _timer = null;
      _enqueue();
    });
  }

  void _enqueue() {
    final path = _path;
    final write = _write;
    if (path == null || write == null) {
      return;
    }
    _queue = _queue.then((_) => _writeSnapshot(path, write));
  }

  Future<void> _writeSnapshot(String path, SettingsWriteFn write) async {
    // Một lần ghi xếp trước đã mang snapshot này xuống file.
    if (!_dirty) {
      return;
    }
    final revision = _revision;
    final AtomicWriteResult result;
    try {
      result = await write(path, SettingsCodec.encode(_current));
    } on Object {
      return;
    }
    if (result is AtomicWriteSuccess && revision == _revision) {
      _dirty = false;
    }
  }
}

/// Bytes của file, hoặc `null` khi không có file, không phải file thường,
/// lớn hơn [SettingsStore.maxFileBytes] hay đọc lỗi.
Future<List<int>?> _readCapped(String path) async {
  try {
    if (await FileSystemEntity.type(path) != FileSystemEntityType.file) {
      return null;
    }
    final raf = await File(path).open();
    try {
      // Đọc dư một byte để phát hiện file vượt ngưỡng.
      final bytes = await raf.read(SettingsStore.maxFileBytes + 1);
      return bytes.length > SettingsStore.maxFileBytes ? null : bytes;
    } finally {
      await raf.close();
    }
  } on Object {
    return null;
  }
}
