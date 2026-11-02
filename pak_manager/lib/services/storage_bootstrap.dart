import 'dart:io';

import '../core/io/pak_paths.dart';
import '../core/io/tmp_sweeper.dart';
import '../core/ports/app_directory_port.dart';
import '../core/ports/backup_port.dart';

/// Bước khởi động lưu trữ, theo thứ tự chạy.
enum StorageBootstrapStep {
  /// Lấy đường dẫn `ApplicationSupport`.
  resolvePath,

  /// Tạo `pak/`.
  createPakDir,

  /// Đặt cờ loại khỏi backup cho `pak/`.
  excludeFromBackup,

  /// Dọn `*.tmp` còn sót.
  sweepTmp,
}

/// Kết quả của [StorageBootstrap.run].
sealed class StorageBootstrapResult {
  const StorageBootstrapResult();
}

/// `pak/` đã tồn tại, đã được loại khỏi backup và đã dọn `*.tmp`.
final class StorageReady extends StorageBootstrapResult {
  const StorageReady(this.paths);

  final PakPaths paths;

  @override
  String toString() => 'StorageReady($paths)';
}

/// Một bước khởi động lỗi (fail-closed): không được đọc/ghi dữ liệu app.
final class StorageUnavailable extends StorageBootstrapResult {
  const StorageUnavailable(this.failedStep);

  final StorageBootstrapStep failedStep;

  @override
  String toString() => 'StorageUnavailable(${failedStep.name})';
}

/// Chuẩn bị thư mục dữ liệu trước mọi I/O (AD-11, AD-13): lấy đường dẫn →
/// tạo `pak/` → `excludeFromBackup(pak)` → dọn `*.tmp`. Chạy trước `runApp`.
///
/// Đây là nơi duy nhất được tạo `pak/`; `AtomicFileWriter` không tạo thư mục.
/// Không ném exception.
final class StorageBootstrap {
  StorageBootstrap({
    required this._directories,
    required this._backup,
    this._sweepTmp = sweepTmpFiles,
  });

  final AppDirectoryPort _directories;
  final BackupPort _backup;
  final Future<int> Function(String pakDir) _sweepTmp;

  Future<StorageBootstrapResult> run() async {
    final String root;
    try {
      root = await _directories.applicationSupportPath();
    } on Object {
      return const StorageUnavailable(StorageBootstrapStep.resolvePath);
    }
    // Đường dẫn rỗng sẽ biến `pak/` thành `/pak`: coi là lỗi.
    if (root.trim().isEmpty) {
      return const StorageUnavailable(StorageBootstrapStep.resolvePath);
    }
    final paths = PakPaths(root);

    try {
      await Directory(paths.pakDir).create(recursive: true);
    } on Object {
      return const StorageUnavailable(StorageBootstrapStep.createPakDir);
    }

    // Vault không bao giờ nằm ngoài cờ loại backup: lỗi ở đây là fail-closed.
    try {
      await _backup.excludeFromBackup(paths.pakDir);
    } on Object {
      return const StorageUnavailable(StorageBootstrapStep.excludeFromBackup);
    }

    try {
      await _sweepTmp(paths.pakDir);
    } on Object {
      return const StorageUnavailable(StorageBootstrapStep.sweepTmp);
    }
    return StorageReady(paths);
  }
}
