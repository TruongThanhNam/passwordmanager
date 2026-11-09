import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/format/settings_codec.dart';
import 'package:pak_manager/core/io/atomic_file_writer.dart';
import 'package:pak_manager/core/model/settings.dart';
import 'package:pak_manager/core/ports/file_sync_port.dart';
import 'package:pak_manager/services/settings_store.dart';

/// Timer giả: chỉ chạy khi test gọi [fire].
class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    if (_active) {
      _active = false;
      _callback();
    }
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

class _Timers {
  final created = <_FakeTimer>[];

  Timer call(Duration duration, void Function() callback) {
    final timer = _FakeTimer(duration, callback);
    created.add(timer);
    return timer;
  }

  Iterable<_FakeTimer> get active => created.where((t) => t.isActive);
}

/// Writer giả: ghi lại nội dung từng lần ghi; có thể giữ lần ghi chưa xong
/// ([hold]) hoặc trả lỗi ([fail]).
class _FakeWrite {
  final writes = <Settings>[];
  final paths = <String>[];
  final _held = <Completer<void>>[];
  bool hold = false;
  bool fail = false;
  int _running = 0;
  int maxRunning = 0;

  Future<AtomicWriteResult> call(String path, List<int> bytes) async {
    _running++;
    maxRunning = _running > maxRunning ? _running : maxRunning;
    paths.add(path);
    writes.add(SettingsCodec.decode(bytes));
    try {
      if (hold) {
        final gate = Completer<void>();
        _held.add(gate);
        await gate.future;
      }
      return fail
          ? const AtomicWriteFailure(AtomicWriteError.io)
          : const AtomicWriteSuccess();
    } finally {
      _running--;
    }
  }

  void releaseNext() => _held.removeAt(0).complete();
}

class _NoopFileSync implements FileSyncPort {
  final calls = <String>[];

  @override
  Future<void> fsyncDirectory(String path) async => calls.add(path);
}

/// Cho các future/microtask đang chờ chạy hết.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late Directory sandbox;
  late String path;
  late _Timers timers;
  late _FakeWrite write;
  late _NoopFileSync fileSync;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('pak_settings_');
    path = '${sandbox.path}${Platform.pathSeparator}settings';
    timers = _Timers();
    write = _FakeWrite();
    fileSync = _NoopFileSync();
  });

  tearDown(() => sandbox.deleteSync(recursive: true));

  Future<SettingsStore> load([String? at]) => SettingsStore.load(
    at,
    AtomicFileWriter(fileSync),
    createTimer: timers.call,
    write: write.call,
  );

  SettingsStore inMemory() => SettingsStore.inMemory();

  group('nạp', () {
    test('fr47_first_install_uses_defaults_without_writing', () async {
      final store = await load(path);
      addTearDown(store.dispose);

      expect(store.current, Settings.defaults);
      expect(store.dirty, isFalse);
      expect(File(path).existsSync(), isFalse);
      expect(write.writes, isEmpty);
      expect(timers.created, isEmpty);
    });

    test('fr47_valid_file_is_read_field_by_field', () async {
      final golden = File('test/fixtures/settings/v1/custom.json')
          .readAsBytesSync();
      File(path).writeAsBytesSync(golden);

      final store = await load(path);
      addTearDown(store.dispose);

      expect(store.current, SettingsCodec.decode(golden));
      expect(store.current.language, AppLanguage.vi);
      expect(write.writes, isEmpty);
      expect(File(path).readAsBytesSync(), golden);
    });

    test('fr47_corrupt_file_uses_defaults_and_is_not_rewritten', () async {
      File(path).writeAsBytesSync([0xFF, 0x00, 0x7B]);

      final store = await load(path);
      addTearDown(store.dispose);

      expect(store.current, Settings.defaults);
      expect(write.writes, isEmpty);
      expect(File(path).readAsBytesSync(), [0xFF, 0x00, 0x7B]);
    });

    test('fr47_settings_directory_uses_defaults', () async {
      Directory(path).createSync();

      final store = await load(path);
      addTearDown(store.dispose);

      expect(store.current, Settings.defaults);
      expect(Directory(path).existsSync(), isTrue);
    });

    test('fr47_missing_parent_uses_defaults', () async {
      final store = await load(
        '${sandbox.path}${Platform.pathSeparator}nope'
        '${Platform.pathSeparator}settings',
      );
      addTearDown(store.dispose);

      expect(store.current, Settings.defaults);
    });

    test('fr47_file_over_64kb_uses_defaults', () async {
      final custom = SettingsCodec.encode(
        Settings.defaults.copyWith(autolockMin: 1),
      );
      // JSON hợp lệ (đệm khoảng trắng) đúng 64 KB thì vẫn đọc được.
      final exact = [
        ...custom,
        ...List.filled(SettingsStore.maxFileBytes - custom.length, 0x20),
      ];
      File(path).writeAsBytesSync(exact);
      final atLimit = await load(path);
      addTearDown(atLimit.dispose);
      expect(atLimit.current.autolockMin, 1);

      File(path).writeAsBytesSync([...exact, 0x20]);
      final over = await load(path);
      addTearDown(over.dispose);
      expect(over.current, Settings.defaults);
    });

    test('fr47_storage_unavailable_keeps_store_in_memory', () async {
      final store = await load();
      addTearDown(store.dispose);

      expect(store.current, Settings.defaults);
      expect(store.update((s) => s.copyWith(autolockMin: 5)), isTrue);
      expect(store.current.autolockMin, 5);
      expect(store.dirty, isFalse);
      expect(timers.created, isEmpty);
      await store.flush();
      expect(write.writes, isEmpty);
      expect(fileSync.calls, isEmpty);
      expect(sandbox.listSync(), isEmpty);
    });
  });

  group('update', () {
    test('fr46_update_applies_change_and_notifies', () {
      final store = inMemory();
      addTearDown(store.dispose);
      var notified = 0;
      store.addListener(() => notified++);

      expect(store.update((s) => s.copyWith(sessionMin: 1)), isTrue);
      expect(store.current.sessionMin, 1);
      expect(notified, 1);
    });

    test('fr46_equal_result_does_not_notify', () {
      final store = inMemory();
      addTearDown(store.dispose);
      var notified = 0;
      store.addListener(() => notified++);

      expect(store.update((s) => s.copyWith()), isTrue);
      expect(store.update((s) => s.copyWith(autolockMin: 3)), isTrue);
      expect(notified, 0);
    });

    test('fr46_invalid_result_is_rejected_without_change', () async {
      final store = await load(path);
      addTearDown(store.dispose);
      var notified = 0;
      store.addListener(() => notified++);

      expect(store.update((s) => s.copyWith(autolockMin: 7)), isFalse);
      expect(
        store.update(
          (s) => s.copyWith(gen: s.gen.copyWith(length: genLengthMax + 1)),
        ),
        isFalse,
      );
      expect(store.update((s) => s.copyWith(lastExportAt: -1)), isFalse);
      expect(store.current, Settings.defaults);
      expect(store.dirty, isFalse);
      expect(notified, 0);
      expect(timers.created, isEmpty);
    });

    test('fr47_update_sees_latest_current', () {
      final store = inMemory();
      addTearDown(store.dispose);

      store.update((s) => s.copyWith(autolockMin: 1));
      store.update((s) => s.copyWith(sessionMin: s.autolockMin + 4));
      expect(store.current.sessionMin, 5);
    });
  });

  group('ghi', () {
    test('fr47_two_updates_within_300ms_write_once_latest_snapshot', () async {
      final store = await load(path);
      addTearDown(store.dispose);

      store.update((s) => s.copyWith(autolockMin: 1));
      store.update((s) => s.copyWith(sessionMin: 5));

      // Timer 300 ms bắt đầu từ thay đổi đầu tiên, không gia hạn.
      expect(timers.created, hasLength(1));
      expect(timers.created.single.duration, SettingsStore.debounce);
      expect(SettingsStore.debounce, const Duration(milliseconds: 300));
      expect(write.writes, isEmpty);

      timers.created.single.fire();
      await _settle();

      expect(write.writes, [store.current]);
      expect(write.paths, [path]);
      expect(store.current.autolockMin, 1);
      expect(store.current.sessionMin, 5);
      expect(store.dirty, isFalse);
    });

    test('fr47_writes_are_sequential_and_snapshot_at_start', () async {
      final store = await load(path);
      addTearDown(store.dispose);
      write.hold = true;

      store.update((s) => s.copyWith(autolockMin: 1));
      timers.created.last.fire();
      await _settle();
      expect(write.writes, hasLength(1));

      // Đổi trong lúc lần ghi đầu chưa xong: lần ghi sau phải chờ.
      store.update((s) => s.copyWith(autolockMin: 5));
      expect(timers.created, hasLength(2));
      timers.created.last.fire();
      store.update((s) => s.copyWith(sessionMin: 1));
      await _settle();
      expect(write.writes, hasLength(1));
      expect(store.dirty, isTrue);

      write.releaseNext();
      await _settle();
      // Snapshot lấy lúc lần ghi thứ hai bắt đầu: có cả thay đổi sau cùng.
      expect(write.writes, hasLength(2));
      expect(write.writes.last, store.current);
      expect(write.writes.last.sessionMin, 1);
      expect(write.maxRunning, 1);

      write.releaseNext();
      await store.flush();
      expect(store.dirty, isFalse);
      expect(write.writes, hasLength(2));
    });

    test('fr47_failed_write_keeps_ram_and_dirty_then_flush_retries', () async {
      final store = await load(path);
      addTearDown(store.dispose);
      write.fail = true;

      store.update((s) => s.copyWith(clipboardMin: 10));
      timers.created.single.fire();
      await _settle();

      expect(write.writes, hasLength(1));
      expect(store.current.clipboardMin, 10);
      expect(store.dirty, isTrue);
      expect(timers.active, isEmpty);

      write.fail = false;
      await store.flush();
      expect(write.writes, hasLength(2));
      expect(write.writes.last.clipboardMin, 10);
      expect(store.dirty, isFalse);
    });

    test('fr47_failed_write_retried_by_next_noop_update', () async {
      final store = await load(path);
      addTearDown(store.dispose);
      write.fail = true;

      store.update((s) => s.copyWith(clipboardMin: 10));
      timers.created.single.fire();
      await _settle();
      expect(store.dirty, isTrue);

      write.fail = false;
      expect(store.update((s) => s), isTrue);
      expect(timers.active, hasLength(1));
      timers.active.single.fire();
      await _settle();

      expect(write.writes, hasLength(2));
      expect(store.dirty, isFalse);
    });

    test('fr47_flush_before_300ms_writes_now_and_cancels_timer', () async {
      final store = await load(path);
      addTearDown(store.dispose);

      store.update((s) => s.copyWith(appearance: Appearance.dark));
      final timer = timers.created.single;
      await store.flush();

      expect(write.writes, [store.current]);
      expect(timer.isActive, isFalse);
      timer.fire();
      await _settle();
      expect(write.writes, hasLength(1));
    });

    test('fr47_concurrent_flush_writes_once', () async {
      final store = await load(path);
      addTearDown(store.dispose);
      write.hold = true;

      store.update((s) => s.copyWith(language: AppLanguage.en));
      var done = 0;
      final first = store.flush().then((_) => done++);
      final second = store.flush().then((_) => done++);
      await _settle();
      expect(done, 0);
      expect(write.writes, hasLength(1));

      write.releaseNext();
      await Future.wait([first, second]);
      expect(done, 2);
      expect(write.writes, hasLength(1));
      expect(store.dirty, isFalse);
    });

    test('fr47_flush_without_changes_does_not_write', () async {
      final store = await load(path);
      addTearDown(store.dispose);

      await store.flush();
      expect(write.writes, isEmpty);
      expect(File(path).existsSync(), isFalse);
    });

    test('fr47_dispose_cancels_pending_timer', () async {
      final store = await load(path);
      store.update((s) => s.copyWith(autolockMin: 10));
      final timer = timers.created.single;

      store.dispose();

      expect(timer.isActive, isFalse);
      timer.fire();
      await _settle();
      expect(write.writes, isEmpty);
    });

    test('nfr11_store_writes_through_atomic_file_writer', () async {
      final store = await SettingsStore.load(
        path,
        AtomicFileWriter(fileSync),
        createTimer: timers.call,
      );
      addTearDown(store.dispose);

      store.update((s) => s.copyWith(lastExportAt: 1762300800000));
      await store.flush();

      expect(File(path).readAsBytesSync(), SettingsCodec.encode(store.current));
      expect(fileSync.calls, [sandbox.path]);
      expect(store.dirty, isFalse);

      // Lần nạp sau đọc lại đúng giá trị đã ghi.
      final reloaded = await load(path);
      addTearDown(reloaded.dispose);
      expect(reloaded.current, store.current);
    });
  });
}
