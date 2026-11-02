import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/io/atomic_file_writer.dart';
import 'package:pak_manager/core/ports/file_sync_port.dart';

/// Ghi lại mọi lần fsync thư mục và nội dung file đích tại thời điểm gọi.
class _FakeFileSync implements FileSyncPort {
  _FakeFileSync({this.target, this.fail = false});

  final String? target;
  final bool fail;
  final calls = <String>[];
  final targetAtCall = <List<int>?>[];

  @override
  Future<void> fsyncDirectory(String path) async {
    calls.add(path);
    final t = target;
    if (t != null) {
      final file = File(t);
      targetAtCall.add(file.existsSync() ? file.readAsBytesSync() : null);
    }
    if (fail) {
      throw const FileSystemException('fsync thư mục lỗi (giả)');
    }
  }
}

/// Mô phỏng tiến trình chết giữa chừng. Không phải [Exception]: writer phải
/// trả lỗi chứ không coi là thành công.
class _SimulatedCrash extends Error {}

void main() {
  late Directory sandbox;
  late String dir;
  late String target;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('pak_atomic_');
    dir = sandbox.path;
    target = '$dir${Platform.pathSeparator}cards';
  });

  tearDown(() {
    if (sandbox.existsSync()) {
      sandbox.deleteSync(recursive: true);
    }
  });

  String tmpOf(String path) => '$path.tmp';

  test(
    'nfr11_new_file_written_tmp_removed_dir_fsynced_once_after_rename',
    () async {
      final sync = _FakeFileSync(target: target);
      final result = await AtomicFileWriter(sync).write(target, [1, 2, 3]);

      expect(result, isA<AtomicWriteSuccess>());
      expect(File(target).readAsBytesSync(), [1, 2, 3]);
      expect(File(tmpOf(target)).existsSync(), isFalse);
      expect(sync.calls, [File(target).parent.path]);
      // Gọi sau rename: lúc đó file đích đã mang bytes mới.
      expect(sync.targetAtCall, [
        [1, 2, 3],
      ]);
    },
  );

  test('nfr11_overwrite_replaces_old_bytes', () async {
    File(target).writeAsBytesSync([9, 9, 9, 9]);
    final sync = _FakeFileSync();

    final result = await AtomicFileWriter(sync).write(target, [4, 5]);

    expect(result, isA<AtomicWriteSuccess>());
    expect(File(target).readAsBytesSync(), [4, 5]);
    expect(File(tmpOf(target)).existsSync(), isFalse);
    expect(sync.calls, hasLength(1));
  });

  test('nfr11_stale_tmp_is_overwritten_not_appended', () async {
    File(tmpOf(target)).writeAsBytesSync([7, 7, 7, 7, 7, 7]);

    final result = await AtomicFileWriter(_FakeFileSync()).write(target, [1]);

    expect(result, isA<AtomicWriteSuccess>());
    expect(File(target).readAsBytesSync(), [1]);
  });

  test(
    'nfr11_missing_parent_returns_parent_missing_and_creates_nothing',
    () async {
      final missingDir = '$dir${Platform.pathSeparator}vault';
      final path = '$missingDir${Platform.pathSeparator}cards';
      final sync = _FakeFileSync();

      final result = await AtomicFileWriter(sync).write(path, [1]);

      expect(result, isA<AtomicWriteFailure>());
      expect(
        (result as AtomicWriteFailure).error,
        AtomicWriteError.parentMissing,
      );
      expect(Directory(missingDir).existsSync(), isFalse);
      expect(sandbox.listSync(), isEmpty);
      expect(sync.calls, isEmpty);
    },
  );

  group('nfr11_crash_before_rename_keeps_target', () {
    const beforeRename = [
      AtomicWriteStep.createTmp,
      AtomicWriteStep.writeTmp,
      AtomicWriteStep.fsyncTmp,
      AtomicWriteStep.rename,
    ];

    for (final step in beforeRename) {
      test('nfr11_crash_at_${step.name}_keeps_old_bytes', () async {
        File(target).writeAsBytesSync([1, 1, 1]);
        final sync = _FakeFileSync();
        final writer = AtomicFileWriter(
          sync,
          onStep: (s) {
            if (s == step) {
              throw _SimulatedCrash();
            }
          },
        );

        final result = await writer.write(target, [2, 2, 2, 2]);

        expect(result, isA<AtomicWriteFailure>());
        expect((result as AtomicWriteFailure).error, AtomicWriteError.io);
        expect(File(target).readAsBytesSync(), [1, 1, 1]);
        // Lỗi (không phải crash thật) thì writer dọn luôn file tạm.
        expect(File(tmpOf(target)).existsSync(), isFalse);
        expect(sync.calls, isEmpty);
      });

      test('nfr11_crash_at_${step.name}_leaves_no_target_when_new', () async {
        final writer = AtomicFileWriter(
          _FakeFileSync(),
          onStep: (s) {
            if (s == step) {
              throw _SimulatedCrash();
            }
          },
        );

        final result = await writer.write(target, [2]);

        expect(result, isA<AtomicWriteFailure>());
        expect(File(target).existsSync(), isFalse);
      });
    }
  });

  test('nfr11_steps_run_in_order', () async {
    final steps = <AtomicWriteStep>[];
    final writer = AtomicFileWriter(_FakeFileSync(), onStep: steps.add);

    await writer.write(target, [1]);

    expect(steps, AtomicWriteStep.values);
  });

  test('nfr11_fsync_directory_failure_after_rename_returns_io', () async {
    File(target).writeAsBytesSync([1]);
    final sync = _FakeFileSync(fail: true);

    final result = await AtomicFileWriter(sync).write(target, [3, 3]);

    expect(result, isA<AtomicWriteFailure>());
    expect((result as AtomicWriteFailure).error, AtomicWriteError.io);
    expect(File(target).readAsBytesSync(), [3, 3]);
    expect(File(tmpOf(target)).existsSync(), isFalse);
    expect(sync.calls, hasLength(1));
  });

  test('nfr11_crash_at_fsync_directory_step_keeps_new_bytes', () async {
    final writer = AtomicFileWriter(
      _FakeFileSync(),
      onStep: (s) {
        if (s == AtomicWriteStep.fsyncDirectory) {
          throw _SimulatedCrash();
        }
      },
    );

    final result = await writer.write(target, [5]);

    expect(result, isA<AtomicWriteFailure>());
    expect(File(target).readAsBytesSync(), [5]);
  });
}
