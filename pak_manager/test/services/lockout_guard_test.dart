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
  late Directory sandbox;
  late PakPaths paths;

  setUpAll(() async => sodium = await initSodium());

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('pak_guard_');
    paths = PakPaths(sandbox.path);
    Directory(paths.pakDir).createSync();
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
        if (failAt?.call() == step) {
          throw _SimulatedCrash();
        }
      },
    ),
    path: paths.guardFile,
  );

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
      const saved = GuardState(
        failCount: 7,
        waitBootId: 'fake-boot-1',
        waitStartMono: 1800000,
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

    test('ad08_attempt_keeps_wait_and_wiping_fields', () async {
      const saved = GuardState(
        failCount: 6,
        waitBootId: 'fake-boot-1',
        waitStartMono: 1800000,
      );
      writeDisk(saved);
      final g = guard();
      await g.normalize(hasAccount: true);

      expect(await g.recordAttempt(), isTrue);

      expect(
        diskState(),
        const GuardState(
          failCount: 7,
          waitBootId: 'fake-boot-1',
          waitStartMono: 1800000,
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
}
