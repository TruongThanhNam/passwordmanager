import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/crypto/wipe.dart';
import 'package:pak_manager/core/format/guard_codec.dart';
import 'package:pak_manager/core/guard/guard_state.dart';
import 'package:pak_manager/core/io/atomic_file_writer.dart';
import 'package:pak_manager/core/io/pak_paths.dart';
import 'package:pak_manager/services/lockout_guard.dart';
import 'package:sodium/sodium_sumo.dart';

import '../core/vault_fixture.dart';
import '../support/port_fakes.dart';

/// Chuỗi giả (chỉ dữ liệu test).
const _wrongX = 'fixture-only wrong horse 42!';
const _wrongY = 'fixture-only other horse 42?';

final class _SimulatedCrash implements Exception {}

Uint8List _bytes(String s) => ascii.encode(s);

void main() {
  late SodiumSumo sodium;

  /// Số lần ghi `guard` (đếm bước tạo file tạm) qua mọi guard của test.
  var writes = 0;
  late Directory sandbox;
  late PakPaths paths;
  late FakeClock clock;

  setUpAll(() async => sodium = await initSodium());

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('pak_guard_');
    paths = PakPaths(sandbox.path);
    Directory(paths.pakDir).createSync();
    // Đủ lớn để đặt mốc cũ trước thời điểm hiện tại mà không âm.
    clock = FakeClock(const Duration(hours: 10).inMilliseconds);
    writes = 0;
  });
  tearDown(() => sandbox.deleteSync(recursive: true));

  File guardFile() => File(paths.guardFile);

  /// Bytes của `guard`, hoặc `null` khi chưa có file.
  List<int>? diskBytes() =>
      guardFile().existsSync() ? guardFile().readAsBytesSync() : null;

  /// Trạng thái trên đĩa (file phải đọc được).
  GuardState diskState() =>
      (GuardCodec.decode(guardFile().readAsBytesSync()) as GuardOk).state;

  void writeDisk(GuardState state) =>
      guardFile().writeAsBytesSync(GuardCodec.encode(state));

  /// Mọi file dưới `pak/` (để thấy `guard.tmp` sót lại).
  List<String> pakNames() => [
    for (final e in Directory(paths.pakDir).listSync())
      e.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
  ]..sort();

  /// [failAt] khác `null` thì writer "chết" ở bước đó.
  LockoutGuard guard({
    AtomicWriteStep? Function()? failAt,
    RecordingFileSync? sync,
  }) => LockoutGuard(
    sodium: sodium,
    writer: AtomicFileWriter(
      sync ?? RecordingFileSync(),
      onStep: (step) {
        if (step == AtomicWriteStep.createTmp) {
          writes++;
        }
        if (failAt?.call() == step) {
          throw _SimulatedCrash();
        }
      },
    ),
    path: paths.guardFile,
    clock: clock,
  );

  /// [failCount] với mốc chờ tại thời điểm hiện tại của [clock].
  GuardState markedNow(int failCount) => GuardState(
    failCount: failCount,
    waitBootId: clock.boot,
    waitStartMono: clock.ms,
  );

  const minute = Duration(minutes: 1);

  group('normalize', () {
    test('ad08_with_account_recreates_missing_guard', () async {
      final g = guard();

      await g.normalize(hasAccount: true);

      expect(g.state, GuardState.initial);
      expect(diskBytes(), GuardCodec.encode(GuardState.initial));
    });

    final unreadable = <String, List<int> Function()>{
      'garbage': () => [0xff, 0x00, 0x13],
      'not_object': () => utf8.encode('[0]'),
      'wrong_type': () => utf8.encode(
        '{"v":1,"failCount":"3","waitBootId":null,"waitStartMono":null,'
        '"wiping":false}',
      ),
      'missing_key': () => utf8.encode('{"v":1,"failCount":3}'),
      'version_2': () => utf8.encode(
        '{"v":2,"failCount":3,"waitBootId":null,"waitStartMono":null,'
        '"wiping":false}',
      ),
      'failcount_11': () => utf8.encode(
        '{"v":1,"failCount":11,"waitBootId":null,"waitStartMono":null,'
        '"wiping":false}',
      ),
      // JSON hợp lệ nhưng vượt 4 KiB.
      'oversize': () => utf8.encode(
        '{"v":1,"failCount":3,"waitBootId":"${'b' * 4096}",'
        '"waitStartMono":null,"wiping":false}',
      ),
    };
    for (final MapEntry(key: name, value: bytes) in unreadable.entries) {
      test('ad08_with_account_recreates_unreadable_guard_$name', () async {
        guardFile().writeAsBytesSync(bytes());
        final g = guard();

        await g.normalize(hasAccount: true);

        expect(g.state, GuardState.initial);
        expect(g.state.attemptsLeft, 10);
        expect(diskBytes(), GuardCodec.encode(GuardState.initial));
      });
    }

    test('ad08_valid_guard_is_loaded_without_writing', () async {
      // Mốc hợp lệ: cùng lần khởi động, trước thời điểm hiện tại.
      final saved = GuardState(
        failCount: 7,
        waitBootId: clock.boot,
        waitStartMono: clock.ms - 60000,
      );
      writeDisk(saved);
      final before = diskBytes();
      final sync = RecordingFileSync();
      final g = guard(sync: sync);

      await g.normalize(hasAccount: true);

      expect(g.state, saved);
      expect(g.state.attemptsLeft, 3);
      expect(diskBytes(), before);
      expect(sync.calls, isEmpty);
    });

    test('ad08_without_account_never_writes_guard', () async {
      final sync = RecordingFileSync();
      final g = guard(sync: sync);
      await g.normalize(hasAccount: false);
      expect(g.state, GuardState.initial);
      expect(diskBytes(), isNull);

      guardFile().writeAsBytesSync([1, 2, 3]);
      await g.normalize(hasAccount: false);
      expect(g.state, GuardState.initial);
      expect(diskBytes(), [1, 2, 3]);

      writeDisk(const GuardState(failCount: 2));
      await g.normalize(hasAccount: false);
      expect(g.state.failCount, 2);
      expect(sync.calls, isEmpty);
    });

    for (final step in AtomicWriteStep.values) {
      test('ad08_recreate_failure_at_${step.name}_keeps_ram_at_zero', () async {
        guardFile().writeAsBytesSync([0xff]);
        final g = guard(failAt: () => step);

        await g.normalize(hasAccount: true);

        expect(g.state, GuardState.initial);
        expect(pakNames().where((n) => n.endsWith('.tmp')), isEmpty);
      });
    }
  });

  group('recordAttempt', () {
    test('fr05_ad08_attempt_is_on_disk_when_it_returns', () async {
      final g = guard();
      await g.normalize(hasAccount: true);

      expect(await g.recordAttempt(), isTrue);

      expect(g.state.failCount, 1);
      expect(diskState().failCount, 1);
      expect(g.state.attemptsLeft, 9);
    });

    test('fr04_ad08_attempts_cap_at_max', () async {
      writeDisk(const GuardState(failCount: 9));
      final g = guard();
      await g.normalize(hasAccount: true);

      expect(await g.recordAttempt(), isTrue);
      expect(diskState().failCount, 10);
      expect(g.state.exhausted, isTrue);
      expect(await g.recordAttempt(), isTrue);
      expect(diskState().failCount, 10);
      expect(g.state.attemptsLeft, 0);
    });

    test('ad08_tenth_attempt_keeps_old_mark_and_never_reads_clock', () async {
      final saved = GuardState(
        failCount: 9,
        waitBootId: clock.boot,
        waitStartMono: clock.ms - waitDuration.inMilliseconds,
      );
      writeDisk(saved);
      final g = guard();
      await g.normalize(hasAccount: true);
      clock.error = StateError('đồng hồ giả lỗi');
      clock.bootError = StateError('bootId giả lỗi');

      expect(await g.recordAttempt(), isTrue);

      expect(
        diskState(),
        GuardState(
          failCount: 10,
          waitBootId: saved.waitBootId,
          waitStartMono: saved.waitStartMono,
        ),
      );
    });

    for (final step in AtomicWriteStep.values) {
      test('ad08_crash_at_${step.name}_keeps_ram_count', () async {
        writeDisk(const GuardState(failCount: 2));
        AtomicWriteStep? failAt;
        final g = guard(failAt: () => failAt);
        await g.normalize(hasAccount: true);

        failAt = step;
        expect(await g.recordAttempt(), isFalse);

        // RAM chỉ đổi khi ghi thành công: UI không giảm N.
        expect(g.state.failCount, 2);
        expect(pakNames().where((n) => n.endsWith('.tmp')), isEmpty);
        // Trước rename: file cũ còn nguyên. Sau rename (fsync thư mục lỗi):
        // file đã mang bytes mới, độ bền chưa chắc.
        final onDisk = diskState().failCount;
        expect(onDisk, step == AtomicWriteStep.fsyncDirectory ? 3 : 2);

        // Mở lại app: RAM theo đúng file trên đĩa.
        final restarted = guard();
        await restarted.normalize(hasAccount: true);
        expect(restarted.state.failCount, onDisk);

        // Writer hết lỗi: lần ghi kế tiếp đếm tiếp từ RAM.
        failAt = null;
        expect(await g.recordAttempt(), isTrue);
        expect(diskState().failCount, 3);
      });
    }
  });

  group('wait', () {
    test(
      'fr04_ad08_fifth_attempt_writes_count_and_mark_in_one_write',
      () async {
        writeDisk(const GuardState(failCount: 4));
        final g = guard();
        await g.normalize(hasAccount: true);
        writes = 0;

        expect(await g.recordAttempt(), isTrue);

        expect(writes, 1);
        expect(diskState(), markedNow(5));
        expect(g.state, markedNow(5));
        expect(await g.waitRemaining(), waitDuration);
      },
    );

    test('fr04_ad08_each_attempt_five_to_nine_sets_new_mark', () async {
      writeDisk(const GuardState(failCount: 4));
      final g = guard();
      await g.normalize(hasAccount: true);
      expect(await g.recordAttempt(), isTrue);
      for (var n = 6; n <= 9; n++) {
        clock.advance(waitDuration);
        expect(await g.waitRemaining(), Duration.zero);

        expect(await g.recordAttempt(), isTrue);

        expect(diskState(), markedNow(n));
        expect(await g.waitRemaining(), waitDuration);
      }
    });

    for (final which in ['mono', 'boot']) {
      test(
        'fr04_ad08_clock_failure_on_fifth_attempt_writes_nothing_$which',
        () async {
          writeDisk(const GuardState(failCount: 4));
          final g = guard();
          await g.normalize(hasAccount: true);
          final before = diskBytes();
          writes = 0;
          if (which == 'mono') {
            clock.error = StateError('đồng hồ giả lỗi');
          } else {
            clock.bootError = StateError('bootId giả lỗi');
          }

          expect(await g.recordAttempt(), isFalse);

          expect(writes, 0);
          expect(diskBytes(), before);
          expect(g.state, const GuardState(failCount: 4));
        },
      );
    }

    test('fr04_attempts_one_to_four_never_read_clock', () async {
      final g = guard();
      await g.normalize(hasAccount: true);
      clock.error = StateError('đồng hồ giả lỗi');
      clock.bootError = StateError('bootId giả lỗi');

      for (var n = 1; n <= 4; n++) {
        expect(await g.recordAttempt(), isTrue);
        expect(diskState(), GuardState(failCount: n));
        expect(await g.waitRemaining(), Duration.zero);
      }
      expect(clock.reads, 0);
      expect(clock.bootReads, 0);
    });

    test('fr04_ad09_wait_counts_down_and_expires', () async {
      writeDisk(const GuardState(failCount: 4));
      final g = guard();
      await g.normalize(hasAccount: true);
      expect(await g.recordAttempt(), isTrue);

      clock.advance(minute * 10);
      expect(await g.waitRemaining(), minute * 20);
      clock.advance(minute * 20 - const Duration(milliseconds: 1));
      expect(await g.waitRemaining(), const Duration(milliseconds: 1));
      clock.advance(const Duration(milliseconds: 1));
      expect(await g.waitRemaining(), Duration.zero);
      // Mốc hết hạn không bị xóa; lần thử kế tiếp ghi đè.
      expect(diskState(), g.state);
      expect(g.state.waitStartMono, isNotNull);
    });

    test('fr06_ad08_restart_same_boot_keeps_remaining_without_write', () async {
      writeDisk(const GuardState(failCount: 4));
      final g = guard();
      await g.normalize(hasAccount: true);
      expect(await g.recordAttempt(), isTrue);
      final saved = diskBytes();

      clock.advance(minute * 12);
      writes = 0;
      final restarted = guard();
      await restarted.normalize(hasAccount: true);

      expect(writes, 0);
      expect(diskBytes(), saved);
      expect(await restarted.waitRemaining(), minute * 18);
      expect(writes, 0);
    });

    test('tc03_ad09_only_monotonic_time_counts', () async {
      // Chỉnh đồng hồ máy +1 giờ không đi vào đâu: guard chỉ đọc đồng hồ đơn
      // điệu, và nó chỉ chạy thêm 1 phút.
      writeDisk(const GuardState(failCount: 4));
      final g = guard();
      await g.normalize(hasAccount: true);
      expect(await g.recordAttempt(), isTrue);

      clock.advance(minute);

      expect(await g.waitRemaining(), minute * 29);
    });

    test('tc03_ad08_reboot_reanchors_on_normalize', () async {
      writeDisk(const GuardState(failCount: 4));
      final g = guard();
      await g.normalize(hasAccount: true);
      expect(await g.recordAttempt(), isTrue);

      // Khởi động lại: `bootId` khác; đồng hồ đơn điệu đã chạy quá mốc cũ
      // nên chỉ `bootId` cho biết máy đã khởi động lại.
      clock
        ..boot = 'fake-boot-2'
        ..ms += waitDuration.inMilliseconds;
      writes = 0;
      final restarted = guard();
      await restarted.normalize(hasAccount: true);

      expect(writes, 1);
      expect(diskState(), markedNow(5));
      expect(restarted.state, markedNow(5));
      expect(await restarted.waitRemaining(), waitDuration);
    });

    test('tc03_ad08_mono_backwards_reanchors_on_normalize', () async {
      writeDisk(const GuardState(failCount: 4));
      final g = guard();
      await g.normalize(hasAccount: true);
      expect(await g.recordAttempt(), isTrue);

      clock.ms -= 1;
      final restarted = guard();
      await restarted.normalize(hasAccount: true);

      expect(diskState(), markedNow(5));
      expect(await restarted.waitRemaining(), waitDuration);
    });

    final partial = <String, GuardState>{
      'both_null': const GuardState(failCount: 7),
      'mono_null': const GuardState(failCount: 7, waitBootId: 'fake-boot'),
      'boot_null': const GuardState(failCount: 7, waitStartMono: 5),
    };
    for (final MapEntry(key: name, value: saved) in partial.entries) {
      test('ad08_missing_mark_anchored_on_normalize_$name', () async {
        writeDisk(saved);
        final g = guard();

        await g.normalize(hasAccount: true);

        expect(diskState(), markedNow(7));
        expect(g.state, markedNow(7));
        expect(await g.waitRemaining(), waitDuration);
      });
    }

    for (final step in AtomicWriteStep.values) {
      test('tc03_ad08_reanchor_crash_at_${step.name}_never_shortens', () async {
        // Mốc cũ của lần khởi động trước, còn 1 phút nếu không neo lại.
        writeDisk(
          GuardState(
            failCount: 6,
            waitBootId: 'fake-boot-old',
            waitStartMono: clock.ms - minute.inMilliseconds * 29,
          ),
        );
        final g = guard(failAt: () => step);

        await g.normalize(hasAccount: true);

        // RAM mang mốc mới dù ghi lỗi.
        expect(g.state, markedNow(6));
        expect(await g.waitRemaining(), waitDuration);
        expect(pakNames().where((n) => n.endsWith('.tmp')), isEmpty);

        // Mở lại app sau 1 phút: sau rename đĩa có mốc mới (còn 29:00);
        // trước rename đĩa còn mốc cũ, neo lại lần nữa (30:00).
        clock.advance(minute);
        final restarted = guard();
        await restarted.normalize(hasAccount: true);
        expect(
          await restarted.waitRemaining(),
          step == AtomicWriteStep.fsyncDirectory ? minute * 29 : waitDuration,
        );
      });
    }

    test('ad08_normalize_clock_failure_keeps_mark_without_write', () async {
      const saved = GuardState(failCount: 6);
      writeDisk(saved);
      clock.error = StateError('đồng hồ giả lỗi');
      writes = 0;
      final g = guard();

      await g.normalize(hasAccount: true);

      expect(writes, 0);
      expect(g.state, saved);
      expect(await g.waitRemaining(), waitDuration);

      // Đồng hồ đọc lại được: lần hỏi kế tiếp neo mốc, ghi xuống đĩa, rồi
      // đếm ngược thật (không đứng mãi ở 30:00).
      clock.error = null;
      expect(await g.waitRemaining(), waitDuration);
      expect(writes, 1);
      expect(diskState(), saved.withWaitMark(clock.boot, clock.ms));
      clock.advance(minute);
      expect(await g.waitRemaining(), waitDuration - minute);
    });

    test('ad08_normalize_without_account_never_reanchors', () async {
      const saved = GuardState(failCount: 7);
      writeDisk(saved);
      writes = 0;
      final g = guard();

      await g.normalize(hasAccount: false);

      expect(writes, 0);
      expect(clock.reads, 0);
      expect(clock.bootReads, 0);
      expect(g.state, saved);
    });

    for (final which in ['mono', 'boot']) {
      test('ad08_ad09_wait_query_clock_failure_is_full_wait_$which', () async {
        writeDisk(const GuardState(failCount: 4));
        final g = guard();
        await g.normalize(hasAccount: true);
        expect(await g.recordAttempt(), isTrue);
        clock.advance(minute * 25);
        if (which == 'mono') {
          clock.error = StateError('đồng hồ giả lỗi');
        } else {
          clock.bootError = StateError('bootId giả lỗi');
        }
        writes = 0;

        expect(await g.waitRemaining(), waitDuration);
        expect(writes, 0);
        expect(g.state, diskState());
      });
    }

    test('ad08_wait_query_outside_range_never_reads_clock', () async {
      writeDisk(const GuardState(failCount: 3));
      final g = guard();
      await g.normalize(hasAccount: true);
      clock.error = StateError('đồng hồ giả lỗi');

      expect(await g.waitRemaining(), Duration.zero);
      expect(clock.reads, 0);
      expect(clock.bootReads, 0);
    });

    test(
      'tc03_ad08_boot_id_change_at_runtime_reanchors_on_wait_query',
      () async {
        writeDisk(const GuardState(failCount: 4));
        final g = guard();
        await g.normalize(hasAccount: true);
        expect(await g.recordAttempt(), isTrue);
        clock.advance(minute * 20);

        // `bootId` đọc ra khác giữa hai lần đọc trong cùng process (đọc chập
        // chờn): neo lại, chỉ kéo dài thời gian chờ.
        clock.boot = 'fake-boot-2';
        expect(await g.waitRemaining(), waitDuration);
        expect(diskState(), markedNow(5));

        // Ghi lỗi khi neo lại: RAM vẫn mang mốc mới.
        AtomicWriteStep? failAt;
        final flaky = guard(failAt: () => failAt);
        await flaky.normalize(hasAccount: true);
        clock
          ..advance(minute)
          ..boot = 'fake-boot-3';
        failAt = AtomicWriteStep.writeTmp;
        expect(await flaky.waitRemaining(), waitDuration);
        expect(flaky.state, markedNow(5));
      },
    );

    test('fr04_ad08_tenth_attempt_ends_wait', () async {
      writeDisk(const GuardState(failCount: 8));
      final g = guard();
      await g.normalize(hasAccount: true);
      expect(await g.recordAttempt(), isTrue);
      clock.advance(waitDuration);

      expect(await g.recordAttempt(), isTrue);

      expect(g.state.failCount, 10);
      expect(await g.waitRemaining(), Duration.zero);
    });

    test('fr05_ad08_success_after_wait_clears_mark', () async {
      writeDisk(const GuardState(failCount: 4));
      final g = guard();
      await g.normalize(hasAccount: true);
      expect(await g.recordAttempt(), isTrue);
      clock.advance(waitDuration);

      await g.recordSuccess();

      expect(diskState(), GuardState.initial);
      expect(await g.waitRemaining(), Duration.zero);
    });

    test('ad08_wait_query_waits_for_pending_attempt', () async {
      writeDisk(const GuardState(failCount: 4));
      final g = guard();
      await g.normalize(hasAccount: true);
      final gate = Completer<void>();
      clock.hold = gate;

      // Lần ghi trước KDF đang đọc đồng hồ thì UI hỏi thời gian chờ: hai
      // lời gọi chạy tuần tự, không lời nào đọc trạng thái cũ.
      final attempt = g.recordAttempt();
      final remaining = g.waitRemaining();
      await Future<void>.delayed(Duration.zero);
      expect(clock.reads, 1);
      gate.complete();

      expect(await attempt, isTrue);
      expect(await remaining, waitDuration);
      expect(diskState(), markedNow(5));
      expect(g.state, markedNow(5));
    });
  });

  group('recordSuccess', () {
    test('fr05_ad08_success_resets_count_and_clears_wait', () async {
      writeDisk(
        const GuardState(
          failCount: 7,
          waitBootId: 'fake-boot-1',
          waitStartMono: 1800000,
        ),
      );
      final g = guard();
      await g.normalize(hasAccount: true);

      await g.recordSuccess();

      expect(g.state, GuardState.initial);
      expect(diskBytes(), GuardCodec.encode(GuardState.initial));
    });

    test('ad08_success_write_failure_still_resets_ram', () async {
      writeDisk(const GuardState(failCount: 4));
      AtomicWriteStep? failAt;
      final g = guard(failAt: () => failAt);
      await g.normalize(hasAccount: true);

      failAt = AtomicWriteStep.writeTmp;
      await g.recordSuccess();
      expect(g.state, GuardState.initial);
      expect(diskState().failCount, 4);

      // Lần ghi trước KDF kế tiếp ghi lại trạng thái đúng.
      failAt = null;
      expect(await g.recordAttempt(), isTrue);
      expect(diskState().failCount, 1);
    });
  });

  group('last wrong digest', () {
    test('fr05_repeat_of_last_wrong_only', () {
      final g = guard();
      expect(g.isRepeatOfLastWrong(_bytes(_wrongX)), isFalse);

      g.rememberWrong(_bytes(_wrongX));
      expect(g.isRepeatOfLastWrong(_bytes(_wrongX)), isTrue);
      expect(g.isRepeatOfLastWrong(_bytes(_wrongY)), isFalse);

      // Chỉ nhớ chuỗi sai ngay trước.
      g.rememberWrong(_bytes(_wrongY));
      expect(g.isRepeatOfLastWrong(_bytes(_wrongY)), isTrue);
      expect(g.isRepeatOfLastWrong(_bytes(_wrongX)), isFalse);
    });

    test('fr05_success_forgets_last_wrong', () async {
      final g = guard();
      g.rememberWrong(_bytes(_wrongX));

      await g.recordSuccess();

      expect(g.isRepeatOfLastWrong(_bytes(_wrongX)), isFalse);
    });

    test('ad22_digest_survives_wipe_of_password_bytes', () {
      final g = guard();
      final pw = _bytes(_wrongX);
      g.rememberWrong(pw);
      wipe(pw);

      expect(g.isRepeatOfLastWrong(_bytes(_wrongX)), isTrue);
      expect(g.isRepeatOfLastWrong(pw), isFalse);
    });

    test('ad22_digest_stays_in_ram_never_on_disk', () async {
      final g = guard();
      await g.normalize(hasAccount: true);
      g.rememberWrong(_bytes(_wrongX));
      expect(await g.recordAttempt(), isTrue);

      // File chỉ mang schema AD-20, không chứa mật khẩu hay gì thêm.
      final text = utf8.decode(diskBytes()!);
      expect(diskBytes(), GuardCodec.encode(const GuardState(failCount: 1)));
      expect(text, isNot(contains(_wrongX)));
      expect(pakNames(), ['guard']);

      // Process mới (khóa digest mới, RAM trống) không nhận ra chuỗi cũ.
      final restarted = guard();
      await restarted.normalize(hasAccount: true);
      expect(restarted.state.failCount, 1);
      expect(restarted.isRepeatOfLastWrong(_bytes(_wrongX)), isFalse);
    });
  });

  group('load', () {
    test('ad21_load_reads_without_writing_or_reading_clock', () async {
      writeDisk(
        const GuardState(failCount: 6, waitBootId: 'old', waitStartMono: 5),
      );
      final before = diskBytes();
      final g = guard();

      await g.load();

      expect(
        g.state,
        const GuardState(failCount: 6, waitBootId: 'old', waitStartMono: 5),
      );
      expect(diskBytes(), before);
      expect(writes, 0);
      expect(clock.reads, 0);
      expect(clock.bootReads, 0);
    });

    test(
      'ad21_load_missing_or_unreadable_file_is_initial_and_not_written',
      () async {
        final g = guard();
        await g.load();
        expect(g.state, GuardState.initial);
        expect(diskBytes(), isNull);

        guardFile().writeAsBytesSync([0xff, 0x00]);
        await g.load();
        expect(g.state, GuardState.initial);
        expect(diskBytes(), [0xff, 0x00]);
        expect(writes, 0);
      },
    );
  });

  group('markWiping', () {
    test('ad21_mark_wiping_writes_flag_and_keeps_count', () async {
      writeDisk(markedNow(7));
      final g = guard();
      await g.load();

      expect(await g.markWiping(), isTrue);

      expect(g.state, markedNow(7).withWiping());
      expect(diskState(), markedNow(7).withWiping());
    });

    test(
      'ad21_mark_wiping_write_failure_keeps_ram_and_returns_false',
      () async {
        writeDisk(const GuardState(failCount: 10));
        AtomicWriteStep? failAt = AtomicWriteStep.writeTmp;
        final g = guard(failAt: () => failAt);
        await g.load();

        expect(await g.markWiping(), isFalse);

        expect(g.state.wiping, isFalse);
        expect(diskState(), const GuardState(failCount: 10));
        failAt = null;
        expect(await g.markWiping(), isTrue);
        expect(diskState().wiping, isTrue);
      },
    );

    test('ad21_mark_wiping_waits_for_pending_attempt', () async {
      writeDisk(const GuardState(failCount: 4));
      final g = guard();
      await g.load();
      final gate = Completer<void>();
      clock.hold = gate;

      // Lần ghi trước KDF đang đọc đồng hồ: `markWiping` đi sau, không ghi đè.
      final attempt = g.recordAttempt();
      final marking = g.markWiping();
      await Future<void>.delayed(Duration.zero);
      gate.complete();

      expect(await attempt, isTrue);
      expect(await marking, isTrue);
      expect(diskState(), markedNow(5).withWiping());
    });
  });

  group('reset', () {
    test('ad21_reset_writes_initial_and_forgets_wrong_string', () async {
      writeDisk(markedNow(7).withWiping());
      final g = guard();
      await g.load();
      g.rememberWrong(_bytes(_wrongX));

      expect(await g.reset(), isTrue);

      expect(g.state, GuardState.initial);
      expect(diskBytes(), GuardCodec.encode(GuardState.initial));
      expect(g.isRepeatOfLastWrong(_bytes(_wrongX)), isFalse);
    });

    test('ad21_reset_write_failure_still_resets_ram', () async {
      writeDisk(markedNow(7).withWiping());
      final g = guard(failAt: () => AtomicWriteStep.createTmp);
      await g.load();
      g.rememberWrong(_bytes(_wrongX));

      expect(await g.reset(), isFalse);

      expect(g.state, GuardState.initial);
      expect(g.isRepeatOfLastWrong(_bytes(_wrongX)), isFalse);
      // Đĩa còn `wiping`: lần mở sau xóa lại.
      expect(diskState().wiping, isTrue);
    });
  });

  group('recordSuccess result', () {
    test('ad21_record_success_returns_whether_disk_write_succeeded', () async {
      writeDisk(const GuardState(failCount: 10));
      AtomicWriteStep? failAt = AtomicWriteStep.writeTmp;
      final g = guard(failAt: () => failAt);
      await g.load();

      expect(await g.recordSuccess(), isFalse);
      expect(g.state, GuardState.initial);
      expect(diskState().failCount, 10);

      failAt = null;
      expect(await g.recordSuccess(), isTrue);
      expect(diskState(), GuardState.initial);
    });
  });
}
