import 'dart:async';
import 'dart:io';

import '../core/io/pak_paths.dart';
import '../core/ports/file_sync_port.dart';
import 'lockout_guard.dart';
import 'settings_store.dart';

/// Các bước của [WipeCoordinator.run], theo thứ tự. [WipeCoordinator.onStep]
/// nhận từng giá trị **sau khi** bước đó xong (test dùng để mô phỏng tắt app
/// ở giữa quy trình).
enum WipeStep {
  /// `LockoutGuard.markWiping()`.
  markWiping,

  /// Hook vô hiệu `VaultSession` hiện hành.
  invalidateSession,

  /// Xóa `vault/header` (điểm mất tài khoản), rồi fsync `vault/`.
  deleteHeader,

  /// Xóa mọi entry còn lại của `vault/`.
  deleteVaultEntries,

  /// Xóa thư mục `vault/`, rồi fsync `pak/`.
  deleteVaultDir,

  /// Xóa `pak/tmp/`.
  deleteTmp,

  /// `SettingsStore.clearLastExport()`.
  clearLastExport,

  /// Hook xóa clipboard.
  clearClipboard,

  /// `LockoutGuard.reset()`.
  resetGuard,
}

/// Kết quả [WipeCoordinator.run].
sealed class WipeResult {
  const WipeResult();
}

/// Mọi bước đã xong: không còn tài khoản, vault, bộ đếm hay `lastExportAt`
/// cũ; `guard` về trạng thái đầu.
final class WipeDone extends WipeResult {
  const WipeDone();

  @override
  String toString() => 'WipeDone()';
}

/// Một bước lỗi nên quy trình dừng tại đó. `wiping` vẫn nằm trên đĩa (trừ khi
/// chính `markWiping` lỗi, lúc đó chưa xóa gì), nên lần mở app sau xóa nốt.
final class WipeFailed extends WipeResult {
  const WipeFailed();

  @override
  String toString() => 'WipeFailed()';
}

/// Kết quả [WipeCoordinator.resumeIfNeeded].
enum WipeResume {
  /// Không có gì dở dang: đi tiếp `LockoutGuard.normalize`.
  notNeeded,

  /// `wiping` còn trên đĩa hoặc `failCount` đã tới giới hạn: chưa xóa gì,
  /// người gọi dựng S5 để chạy [WipeCoordinator.run].
  pending,

  /// Không có tài khoản nhưng còn file hay `guard` sót: đã dọn im lặng.
  cleaned,

  /// Dọn im lặng bị lỗi.
  failed,
}

/// Chủ duy nhất của quy trình xóa dữ liệu (AD-21) cho cả ba lối vào: lần sai
/// thứ 10, "Xóa & Tạo tài khoản mới" (story 2.4) và xóa nốt khi khởi động.
///
/// [run] theo thứ tự `markWiping` → vô hiệu phiên → xóa `vault/header` rồi
/// fsync `vault/` → xóa mọi entry còn lại của `vault/` (không theo symlink)
/// → xóa `vault/` rồi fsync `pak/` → xóa `pak/tmp/` → `clearLastExport` →
/// xóa clipboard → `LockoutGuard.reset()`. Mỗi bước idempotent; bước nào lỗi
/// thì dừng và trả [WipeFailed] (không ném). Tắt app ở bất kỳ điểm nào, chạy
/// lại luôn về trạng thái chưa có tài khoản. `header` luôn đi trước nên
/// không bao giờ còn tài khoản mà thiếu dữ liệu đi kèm.
///
/// Không dùng đồng hồ.
final class WipeCoordinator {
  WipeCoordinator({
    required this._paths,
    required this._guard,
    required this._settings,
    required this._fileSync,
    this._invalidateSession,
    this._clearClipboard,
    this._onStep,
  });

  final PakPaths _paths;
  final LockoutGuard _guard;
  final SettingsStore _settings;
  final FileSyncPort _fileSync;

  /// Hook vô hiệu `VaultSession` hiện hành. Hiện chưa lối vào nào có phiên
  /// nên main.dart không nối; story sau nối khi có.
  final FutureOr<void> Function()? _invalidateSession;

  /// Hook xóa clipboard nếu còn giữ giá trị app đã copy (Epic 3 nối).
  final FutureOr<void> Function()? _clearClipboard;

  final void Function(WipeStep step)? _onStep;

  /// Lần [run] đang chạy; gọi chồng nhận chính kết quả của nó.
  Future<WipeResult>? _inFlight;

  /// Chạy toàn bộ quy trình xóa. Không ném.
  Future<WipeResult> run() => _inFlight ??= _run().whenComplete(() {
    _inFlight = null;
  });

  /// Xử lý xóa dở dang lúc khởi động (AD-26), trước `LockoutGuard.normalize`.
  /// Nạp `guard` vào RAM trước (chỉ đọc), rồi:
  ///
  /// 1. `wiping` hoặc `failCount` ≥ 10 → [WipeResume.pending] (chưa xóa).
  /// 2. Không có tài khoản ([hasAccount] `false`) mà `vault/` còn entry hoặc
  ///    `guard` khác `GuardState.initial` → [run] ngay, im lặng:
  ///    [WipeResume.cleaned] hoặc [WipeResume.failed].
  /// 3. Còn lại → [WipeResume.notNeeded].
  ///
  /// Đọc đĩa lỗi (nạp `guard` hay liệt kê `vault/` ném) thì trả
  /// [WipeResume.failed], không dọn gì (fail closed). Không ném.
  Future<WipeResume> resumeIfNeeded({required bool hasAccount}) async {
    try {
      await _guard.load();
      final state = _guard.state;
      if (state.wiping || state.exhausted) {
        return WipeResume.pending;
      }
      if (hasAccount) {
        return WipeResume.notNeeded;
      }
      if (state.isInitial && !await _vaultHasLeftovers()) {
        return WipeResume.notNeeded;
      }
      return await run() is WipeDone ? WipeResume.cleaned : WipeResume.failed;
    } on Object {
      return WipeResume.failed;
    }
  }

  Future<WipeResult> _run() async {
    try {
      if (!await _guard.markWiping()) {
        return const WipeFailed();
      }
      _step(WipeStep.markWiping);

      await _invalidateSession?.call();
      _step(WipeStep.invalidateSession);

      await _deleteHeader();
      _step(WipeStep.deleteHeader);

      await _deleteVaultEntries();
      _step(WipeStep.deleteVaultEntries);

      await _deleteVaultDir();
      _step(WipeStep.deleteVaultDir);

      await _deleteEntry(_paths.tmpDir);
      _step(WipeStep.deleteTmp);

      if (!await _settings.clearLastExport()) {
        return const WipeFailed();
      }
      _step(WipeStep.clearLastExport);

      await _clearClipboard?.call();
      _step(WipeStep.clearClipboard);

      if (!await _guard.reset()) {
        return const WipeFailed();
      }
      _step(WipeStep.resetGuard);
      return const WipeDone();
    } on Object {
      return const WipeFailed();
    }
  }

  void _step(WipeStep step) => _onStep?.call(step);

  /// `vault/` không phải thư mục (liên kết hay file) hoặc còn entry nào đó.
  Future<bool> _vaultHasLeftovers() async {
    final type = await FileSystemEntity.type(
      _paths.vaultDir,
      followLinks: false,
    );
    switch (type) {
      case FileSystemEntityType.notFound:
        return false;
      case FileSystemEntityType.directory:
        return !await Directory(_paths.vaultDir)
            .list(followLinks: false)
            .isEmpty;
      default:
        return true;
    }
  }

  /// Xóa `vault/header` trước hết, rồi fsync `vault/` để việc mất `header`
  /// bền trước mọi xóa khác. `vault/` là liên kết hoặc file thì xóa luôn nó
  /// (không đi qua liên kết tới `header`).
  Future<void> _deleteHeader() async {
    final type = await FileSystemEntity.type(
      _paths.vaultDir,
      followLinks: false,
    );
    switch (type) {
      case FileSystemEntityType.notFound:
        return;
      case FileSystemEntityType.directory:
        await _deleteEntry(_paths.headerFile);
        await _fileSync.fsyncDirectory(_paths.vaultDir);
      default:
        await _deleteEntry(_paths.vaultDir);
    }
  }

  Future<void> _deleteVaultEntries() async {
    if (await FileSystemEntity.type(_paths.vaultDir, followLinks: false) !=
        FileSystemEntityType.directory) {
      return;
    }
    final entries = await Directory(_paths.vaultDir)
        .list(followLinks: false)
        .toList();
    for (final entry in entries) {
      await _deleteEntry(entry.path);
    }
  }

  Future<void> _deleteVaultDir() async {
    await _deleteEntry(_paths.vaultDir);
    if (await FileSystemEntity.type(_paths.pakDir, followLinks: false) ==
        FileSystemEntityType.directory) {
      await _fileSync.fsyncDirectory(_paths.pakDir);
    }
  }
}

/// Xóa [path] dù là file, liên kết hay thư mục (đệ quy), không theo liên
/// kết: liên kết chỉ bị gỡ, đích của nó không bị chạm. Không có thì bỏ qua.
Future<void> _deleteEntry(String path) async {
  switch (await FileSystemEntity.type(path, followLinks: false)) {
    case FileSystemEntityType.notFound:
      return;
    case FileSystemEntityType.link:
      await Link(path).delete();
    case FileSystemEntityType.directory:
      final children = await Directory(path).list(followLinks: false).toList();
      for (final child in children) {
        await _deleteEntry(child.path);
      }
      await Directory(path).delete();
    default:
      await File(path).delete();
  }
}
