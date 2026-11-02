import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/io/tmp_sweeper.dart';
import 'package:pak_manager/core/ports/app_directory_port.dart';
import 'package:pak_manager/core/ports/backup_port.dart';
import 'package:pak_manager/services/storage_bootstrap.dart';

class _FakeDirectory implements AppDirectoryPort {
  _FakeDirectory(this.log, {this.path, this.error});

  final List<String> log;
  final String? path;
  final Error? error;

  @override
  Future<String> applicationSupportPath() async {
    log.add('path');
    final e = error;
    if (e != null) {
      throw e;
    }
    return path!;
  }
}

/// Ghi lại thứ tự gọi và trạng thái `pak/` lúc đặt cờ backup.
class _FakeBackup implements BackupPort {
  _FakeBackup(this.log, {this.fail = false, this.probeTmp});

  final List<String> log;
  final bool fail;

  /// File `*.tmp` phải còn nguyên lúc đặt cờ (dọn tmp chạy sau).
  final String? probeTmp;
  final excluded = <String>[];
  bool? pakExistedAtCall;
  bool? tmpExistedAtCall;

  @override
  Future<void> excludeFromBackup(String dirPath) async {
    log.add('excludeFromBackup');
    excluded.add(dirPath);
    pakExistedAtCall = Directory(dirPath).existsSync();
    final probe = probeTmp;
    if (probe != null) {
      tmpExistedAtCall = File(probe).existsSync();
    }
    if (fail) {
      throw const FileSystemException('không đặt được cờ backup (giả)');
    }
  }
}

void main() {
  late Directory sandbox;
  late String support;
  late String pak;
  late List<String> log;
  final sep = Platform.pathSeparator;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('pak_boot_');
    support = '${sandbox.path}${sep}Application Support';
    pak = '$support${sep}pak';
    log = [];
  });

  tearDown(() {
    if (sandbox.existsSync()) {
      sandbox.deleteSync(recursive: true);
    }
  });

  Future<int> loggingSweep(String dir) {
    log.add('sweepTmp');
    return sweepTmpFiles(dir);
  }

  test(
    'nfr8_fr11_first_launch_creates_pak_then_excludes_then_sweeps',
    () async {
      final backup = _FakeBackup(log);
      final bootstrap = StorageBootstrap(
        directories: _FakeDirectory(log, path: support),
        backup: backup,
        sweepTmp: loggingSweep,
      );

      final result = await bootstrap.run();

      expect(result, isA<StorageReady>());
      final paths = (result as StorageReady).paths;
      expect(paths.pakDir, pak);
      expect(Directory(pak).existsSync(), isTrue);
      expect(log, ['path', 'excludeFromBackup', 'sweepTmp']);
      expect(backup.excluded, [pak]);
      // `pak/` đã được tạo trước khi đặt cờ.
      expect(backup.pakExistedAtCall, isTrue);
      // Mọi file của app nằm dưới pak/.
      for (final p in [
        paths.vaultDir,
        paths.guardFile,
        paths.settingsFile,
        paths.tmpDir,
        paths.headerFile,
        paths.cardsFile,
        paths.recentFile,
        paths.draftFile,
      ]) {
        expect(p, startsWith('$pak$sep'));
      }
    },
  );

  test('nfr8_nfr11_existing_pak_excluded_before_tmp_swept', () async {
    Directory('$pak${sep}vault').createSync(recursive: true);
    final tmp = File('$pak${sep}vault${sep}cards.tmp')..writeAsBytesSync([1]);
    final cards = File('$pak${sep}vault${sep}cards')..writeAsBytesSync([2]);
    final backup = _FakeBackup(log, probeTmp: tmp.path);

    final result = await StorageBootstrap(
      directories: _FakeDirectory(log, path: support),
      backup: backup,
      sweepTmp: loggingSweep,
    ).run();

    expect(result, isA<StorageReady>());
    expect(log, ['path', 'excludeFromBackup', 'sweepTmp']);
    expect(backup.tmpExistedAtCall, isTrue);
    expect(tmp.existsSync(), isFalse);
    expect(cards.readAsBytesSync(), [2]);
  });

  test('nfr11_default_sweep_removes_tmp_files', () async {
    // Không truyền `sweepTmp`: chạy đúng hàm dọn mà main() dùng.
    Directory('$pak${sep}vault').createSync(recursive: true);
    final tmp = File('$pak${sep}vault${sep}cards.tmp')..writeAsBytesSync([1]);
    final cards = File('$pak${sep}vault${sep}cards')..writeAsBytesSync([2]);

    final result = await StorageBootstrap(
      directories: _FakeDirectory(log, path: support),
      backup: _FakeBackup(log),
    ).run();

    expect(result, isA<StorageReady>());
    expect(tmp.existsSync(), isFalse);
    expect(cards.readAsBytesSync(), [2]);
  });

  test('nfr8_path_failure_is_unavailable_without_io', () async {
    final backup = _FakeBackup(log);

    final result = await StorageBootstrap(
      directories: _FakeDirectory(log, error: StateError('không có thư mục')),
      backup: backup,
      sweepTmp: loggingSweep,
    ).run();

    expect(result, isA<StorageUnavailable>());
    expect(
      (result as StorageUnavailable).failedStep,
      StorageBootstrapStep.resolvePath,
    );
    expect(log, ['path']);
  });

  test('nfr8_empty_path_is_unavailable', () async {
    final result = await StorageBootstrap(
      directories: _FakeDirectory(log, path: ''),
      backup: _FakeBackup(log),
      sweepTmp: loggingSweep,
    ).run();

    expect(
      (result as StorageUnavailable).failedStep,
      StorageBootstrapStep.resolvePath,
    );
    expect(log, ['path']);
  });

  test('nfr8_create_pak_failure_is_unavailable_without_io', () async {
    // ApplicationSupport là một file: không tạo được `pak/` bên trong.
    File(support).writeAsBytesSync([0]);

    final result = await StorageBootstrap(
      directories: _FakeDirectory(log, path: support),
      backup: _FakeBackup(log),
      sweepTmp: loggingSweep,
    ).run();

    expect(
      (result as StorageUnavailable).failedStep,
      StorageBootstrapStep.createPakDir,
    );
    expect(log, ['path']);
  });

  test('nfr8_exclude_from_backup_failure_is_fail_closed', () async {
    Directory(pak).createSync(recursive: true);
    final tmp = File('$pak${sep}a.tmp')..writeAsBytesSync([1]);

    final result = await StorageBootstrap(
      directories: _FakeDirectory(log, path: support),
      backup: _FakeBackup(log, fail: true),
      sweepTmp: loggingSweep,
    ).run();

    expect(
      (result as StorageUnavailable).failedStep,
      StorageBootstrapStep.excludeFromBackup,
    );
    expect(log, ['path', 'excludeFromBackup']);
    // Không dọn tmp, không I/O dữ liệu.
    expect(tmp.existsSync(), isTrue);
  });

  test('nfr11_sweep_failure_is_unavailable', () async {
    final result = await StorageBootstrap(
      directories: _FakeDirectory(log, path: support),
      backup: _FakeBackup(log),
      sweepTmp: (_) async => throw StateError('dọn tmp lỗi'),
    ).run();

    expect(
      (result as StorageUnavailable).failedStep,
      StorageBootstrapStep.sweepTmp,
    );
  });
}
