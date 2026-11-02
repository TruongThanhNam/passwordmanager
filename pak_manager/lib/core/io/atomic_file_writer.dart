import 'dart:io';

import '../ports/file_sync_port.dart';

/// Các bước của một lần ghi nguyên tử, theo thứ tự.
enum AtomicWriteStep {
  /// Mở `<path>.tmp` (tạo mới hoặc cắt về rỗng).
  createTmp,

  /// Ghi bytes vào file tạm.
  writeTmp,

  /// fsync file tạm (`RandomAccessFile.flush`) rồi đóng.
  fsyncTmp,

  /// Đổi tên file tạm thành file đích (điểm commit).
  rename,

  /// fsync thư mục cha qua [FileSyncPort].
  fsyncDirectory,
}

/// Lý do một lần ghi thất bại.
enum AtomicWriteError {
  /// Thư mục cha của file đích không tồn tại; không tạo gì.
  parentMissing,

  /// Lỗi I/O ở một bước bất kỳ. Nếu lỗi xảy ra sau [AtomicWriteStep.rename]
  /// thì file đích đã mang bytes mới nhưng độ bền chưa chắc chắn.
  io,
}

/// Kết quả của [AtomicFileWriter.write].
sealed class AtomicWriteResult {
  const AtomicWriteResult();
}

/// File đích đã mang bytes mới và thư mục cha đã được fsync.
final class AtomicWriteSuccess extends AtomicWriteResult {
  const AtomicWriteSuccess();
}

final class AtomicWriteFailure extends AtomicWriteResult {
  const AtomicWriteFailure(this.error);

  final AtomicWriteError error;

  @override
  String toString() => 'AtomicWriteFailure(${error.name})';
}

/// Ghi một file theo kiểu nguyên tử (AD-13): ghi `<path>.tmp` cùng thư mục →
/// fsync → rename → fsync thư mục. Tắt đột ngột ở bất kỳ bước nào trước rename
/// để nguyên file đích cũ; `*.tmp` sót lại được dọn khi khởi động.
///
/// Không bao giờ tạo thư mục; không ném exception (trả [AtomicWriteResult]).
final class AtomicFileWriter {
  AtomicFileWriter(this._fileSync, {this._onStep});

  final FileSyncPort _fileSync;

  /// Chỉ cho test: gọi trước mỗi bước, ném để mô phỏng tiến trình chết.
  final void Function(AtomicWriteStep)? _onStep;

  Future<AtomicWriteResult> write(String path, List<int> bytes) async {
    final target = File(path);
    final parent = target.parent;
    try {
      if (!await parent.exists()) {
        return const AtomicWriteFailure(AtomicWriteError.parentMissing);
      }
    } on Object {
      return const AtomicWriteFailure(AtomicWriteError.io);
    }

    final tmp = File('$path.tmp');
    var renamed = false;
    try {
      _onStep?.call(AtomicWriteStep.createTmp);
      final raf = await tmp.open(mode: FileMode.write);
      try {
        _onStep?.call(AtomicWriteStep.writeTmp);
        await raf.writeFrom(bytes);
        _onStep?.call(AtomicWriteStep.fsyncTmp);
        await raf.flush();
      } finally {
        await raf.close();
      }
      _onStep?.call(AtomicWriteStep.rename);
      await tmp.rename(path);
      renamed = true;
      _onStep?.call(AtomicWriteStep.fsyncDirectory);
      await _fileSync.fsyncDirectory(parent.path);
      return const AtomicWriteSuccess();
    } on Object {
      if (!renamed) {
        await _deleteQuietly(tmp);
      }
      return const AtomicWriteFailure(AtomicWriteError.io);
    }
  }
}

Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) {
      await file.delete();
    }
  } on Object {
    // File tạm sót lại sẽ được dọn khi khởi động.
  }
}
