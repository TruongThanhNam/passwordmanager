import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/crypto/kdf.dart';
import 'package:pak_manager/core/format/guard_codec.dart';
import 'package:pak_manager/core/format/settings_codec.dart';
import 'package:pak_manager/core/guard/guard_state.dart';
import 'package:pak_manager/core/io/atomic_file_writer.dart';
import 'package:pak_manager/core/io/pak_paths.dart';
import 'package:pak_manager/core/model/settings.dart';
import 'package:pak_manager/services/account_service.dart';
import 'package:pak_manager/services/lockout_guard.dart';
import 'package:pak_manager/services/settings_store.dart';
import 'package:pak_manager/services/wipe_coordinator.dart';
import 'package:sodium/sodium_sumo.dart';

import '../core/vault_fixture.dart';
import '../support/port_fakes.dart';

/// Một bộ dựng coordinator trên thư mục thật của test.
typedef _Rig = ({
  WipeCoordinator coordinator,
  LockoutGuard guard,
  SettingsStore settings,
});

/// Windows không cấp quyền tạo symlink nếu thiếu Developer Mode; CI ubuntu
/// luôn chạy hai test symlink.
final String? symlinkSkip = _canCreateSymlink()
    ? null
    : 'không tạo được symlink trên máy này';

bool _canCreateSymlink() {
  final dir = Directory.systemTemp.createTempSync('pak_wipe_probe_');
  try {
    Link('${dir.path}${Platform.pathSeparator}l').createSync(dir.path);
    return true;
  } on FileSystemException {
    return false;
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void main() {
  late SodiumSumo sodium;
  late Directory sandbox;
  late Directory outside;
  late PakPaths paths;
  late FakeClock clock;

  setUpAll(() async => sodium = await initSodium());

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('pak_wipe_');
    outside = Directory.systemTemp.createTempSync('pak_wipe_outside_');
    paths = PakPaths(sandbox.path);
    clock = FakeClock(const Duration(hours: 10).inMilliseconds);
    Directory(paths.pakDir).createSync();
  });
  tearDown(() async {
    // Windows thỉnh thoảng báo thư mục chưa rỗng ngay sau khi xóa file
    // (DW-2.1-1): thử lại vài lần.
    for (final dir in [sandbox, outside]) {
      for (var i = 0; i < 5; i++) {
        try {
          if (dir.existsSync()) {
            dir.deleteSync(recursive: true);
          }
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
    }
  });

  /// Dựng một tài khoản cũ: `vault/{header,cards,recent,draft}`, `pak/tmp/`,
  /// `settings` có `lastExportAt`, `guard` với [guard].
  void seed({GuardState guard = const GuardState(failCount: 10)}) {
    Directory(paths.vaultDir).createSync();
    File(paths.headerFile).writeAsBytesSync(vaultFixture('header'));
    File(paths.cardsFile).writeAsBytesSync(vaultFixture('cards'));
    File(paths.recentFile).writeAsBytesSync(vaultFixture('recent'));
    File(paths.draftFile).writeAsBytesSync([1, 2, 3]);
    Directory(paths.tmpDir).createSync();
    File('${paths.tmpDir}${Platform.pathSeparator}x.tmp').writeAsBytesSync([9]);
    File(paths.settingsFile).writeAsBytesSync(
      SettingsCodec.encode(
        Settings.defaults.copyWith(lastExportAt: 1762300800000, autolockMin: 1),
      ),
    );
    File(paths.guardFile).writeAsBytesSync(GuardCodec.encode(guard));
  }

  GuardState diskGuard() => (GuardCodec.decode(
    File(paths.guardFile).readAsBytesSync(),
  ) as GuardOk).state;

  int? diskLastExport() =>
      SettingsCodec.decode(File(paths.settingsFile).readAsBytesSync())
          .lastExportAt;

  /// Mọi đường dẫn còn lại dưới `pak/` (tên tương đối).
  List<String> pakEntries() => [
    for (final e in Directory(
      paths.pakDir,
    ).listSync(recursive: true, followLinks: false))
      e.path.substring(paths.pakDir.length + 1),
  ]..sort();

  void expectClean() {
    expect(Directory(paths.vaultDir).existsSync(), isFalse);
    expect(Directory(paths.tmpDir).existsSync(), isFalse);
    expect(diskGuard(), GuardState.initial);
    expect(diskLastExport(), isNull);
    // Các cài đặt khác không bị đụng.
    expect(
      SettingsCodec.decode(File(paths.settingsFile).readAsBytesSync())
          .autolockMin,
      1,
    );
  }

  Future<_Rig> rig({
    RecordingFileSync? sync,
    AtomicFileWriter? guardWriter,
    SettingsWriteFn? settingsWrite,
    FutureOr<void> Function()? invalidateSession,
    FutureOr<void> Function()? clearClipboard,
    void Function(WipeStep step)? onStep,
  }) async {
    // `sync` chỉ là fsync của coordinator (`vault/`, `pak/`); `guard` và
    // `settings` ghi qua writer riêng để không lẫn vào dấu vết đó.
    final fileSync = sync ?? RecordingFileSync();
    final writer = AtomicFileWriter(RecordingFileSync());
    final guard = LockoutGuard(
      sodium: sodium,
      writer: guardWriter ?? writer,
      path: paths.guardFile,
      clock: clock,
    );
    final settings = await SettingsStore.load(
      paths.settingsFile,
      writer,
      write: settingsWrite,
    );
    addTearDown(settings.dispose);
    return (
      coordinator: WipeCoordinator(
        paths: paths,
        guard: guard,
        settings: settings,
        fileSync: fileSync,
        invalidateSession: invalidateSession,
        clearClipboard: clearClipboard,
        onStep: onStep,
      ),
      guard: guard,
      settings: settings,
    );
  }

  group('run', () {
    test('ad21_run_steps_in_order_and_header_deleted_first', () async {
      seed();
      final log = <String>[];
      // Kiểm tra gom lại rồi assert sau: `expect` ném trong callback sẽ bị
      // coordinator nuốt thành `WipeFailed`.
      final checks = <String, bool>{};
      final sync = RecordingFileSync(
        onCall: (path) {
          if (path == paths.vaultDir) {
            // fsync `vault/` ngay sau khi xóa `header`: chưa xóa gì khác.
            checks['vault: header gone'] = !File(paths.headerFile).existsSync();
            checks['vault: cards kept'] = File(paths.cardsFile).existsSync();
            checks['vault: recent kept'] = File(paths.recentFile).existsSync();
            checks['vault: draft kept'] = File(paths.draftFile).existsSync();
            log.add('fsync-vault');
          } else {
            checks['pak: path'] = path == paths.pakDir;
            checks['pak: vault gone'] = !Directory(paths.vaultDir).existsSync();
            log.add('fsync-pak');
          }
        },
      );
      final r = await rig(
        sync: sync,
        invalidateSession: () => log.add('hook-session'),
        clearClipboard: () => log.add('hook-clipboard'),
        onStep: (step) {
          log.add(step.name);
          if (step == WipeStep.markWiping) {
            // `wiping` đã nằm trên đĩa trước mọi lần xóa.
            checks['mark: wiping on disk'] = diskGuard().wiping;
            checks['mark: count kept'] = diskGuard().failCount == 10;
            checks['mark: header kept'] = File(paths.headerFile).existsSync();
          }
        },
      );

      // Như `bootstrap`/`unlock`: RAM của `guard` đã mang trạng thái đĩa.
      await r.guard.load();

      expect(await r.coordinator.run(), isA<WipeDone>());

      expect(checks.values, everyElement(isTrue), reason: '$checks');
      expect(checks, isNotEmpty);
      expect(log, [
        'markWiping',
        'hook-session',
        'invalidateSession',
        'fsync-vault',
        'deleteHeader',
        'deleteVaultEntries',
        'fsync-pak',
        'deleteVaultDir',
        'deleteTmp',
        'clearLastExport',
        'hook-clipboard',
        'clearClipboard',
        'resetGuard',
      ]);
      expectClean();
      expect(r.guard.state, GuardState.initial);
      expect(r.settings.current.lastExportAt, isNull);
    });

    test('ad21_run_is_idempotent_on_clean_and_repeated_runs', () async {
      seed();
      final r = await rig();
      expect(await r.coordinator.run(), isA<WipeDone>());
      final first = pakEntries();

      // Lần hai trên thư mục đã sạch (không `vault/`, không `tmp/`).
      expect(await r.coordinator.run(), isA<WipeDone>());

      expect(pakEntries(), first);
      expectClean();
    });

    test('ad21_run_on_missing_vault_and_tmp_still_resets_guard', () async {
      File(paths.guardFile)
          .writeAsBytesSync(GuardCodec.encode(const GuardState(failCount: 6)));
      File(paths.settingsFile).writeAsBytesSync(
        SettingsCodec.encode(
          Settings.defaults.copyWith(lastExportAt: 5, autolockMin: 1),
        ),
      );
      final sync = RecordingFileSync();
      final r = await rig(sync: sync);

      expect(await r.coordinator.run(), isA<WipeDone>());

      expectClean();
      // Không có `vault/` thì không fsync nó; `guard` được ghi qua writer.
      expect(sync.calls, isNot(contains(paths.vaultDir)));
    });

    for (final crashAfter in WipeStep.values) {
      test('ad21_crash_after_${crashAfter.name}_then_rerun_is_clean', () async {
        seed(
          guard: const GuardState(
            failCount: 7,
            waitBootId: 'b',
            waitStartMono: 1,
          ),
        );
        final first = await rig(
          onStep: (step) {
            if (step == crashAfter) {
              throw SimulatedCrash();
            }
          },
        );

        expect(await first.coordinator.run(), isA<WipeFailed>());

        // Process mới trên cùng thư mục: không biết gì về lần chạy trước.
        final second = await rig();
        final hasAccount = File(paths.headerFile).existsSync();
        final resume = await second.coordinator.resumeIfNeeded(
          hasAccount: hasAccount,
        );
        if (crashAfter == WipeStep.resetGuard) {
          // Mọi bước đã xong, chỉ báo cáo lỗi: không còn gì phải xóa.
          expect(resume, WipeResume.notNeeded);
        } else {
          expect(resume, WipeResume.pending);
          expect(await second.coordinator.run(), isA<WipeDone>());
        }

        expectClean();
        expect(second.guard.state, GuardState.initial);
        // Không còn `header` nào sót cạnh tài khoản mới.
        expect(File(paths.headerFile).existsSync(), isFalse);
      });
    }

    test('ad21_symlinks_are_removed_not_followed', skip: symlinkSkip, () async {
      seed();
      final targetFile = File('${outside.path}${Platform.pathSeparator}keep')
        ..writeAsBytesSync([7]);
      final targetDir = Directory('${outside.path}${Platform.pathSeparator}d')
        ..createSync();
      File('${targetDir.path}${Platform.pathSeparator}inner')
          .writeAsBytesSync([8]);
      Link('${paths.vaultDir}${Platform.pathSeparator}dirlink')
          .createSync(targetDir.path);
      Link('${paths.vaultDir}${Platform.pathSeparator}filelink')
          .createSync(targetFile.path);
      // Cả trong `pak/tmp/`.
      Link('${paths.tmpDir}${Platform.pathSeparator}tmplink')
          .createSync(targetDir.path);
      final r = await rig();

      expect(await r.coordinator.run(), isA<WipeDone>());

      expectClean();
      expect(targetFile.readAsBytesSync(), [7]);
      expect(
        File('${targetDir.path}${Platform.pathSeparator}inner').existsSync(),
        isTrue,
      );
    });

    test(
      'ad21_vault_dir_that_is_a_symlink_is_removed_not_followed',
      skip: symlinkSkip,
      () async {
        seed();
        final target = Directory('${outside.path}${Platform.pathSeparator}real')
          ..createSync();
        final header = File('${target.path}${Platform.pathSeparator}header')
          ..writeAsBytesSync([1]);
        Directory(paths.vaultDir).deleteSync(recursive: true);
        Link(paths.vaultDir).createSync(target.path);
        final r = await rig();

        expect(await r.coordinator.run(), isA<WipeDone>());

        expectClean();
        expect(header.readAsBytesSync(), [1]);
      },
    );

    test('ad21_header_that_is_a_directory_is_still_removed', () async {
      seed();
      File(paths.headerFile).deleteSync();
      Directory(paths.headerFile).createSync();
      File('${paths.headerFile}${Platform.pathSeparator}x')
          .writeAsBytesSync([1]);
      final r = await rig();

      expect(await r.coordinator.run(), isA<WipeDone>());

      expectClean();
    });

    test(
      'fr12_settings_write_failure_is_wipe_failed_and_keeps_wiping',
      () async {
        seed();
        final steps = <WipeStep>[];
        final r = await rig(
          settingsWrite: (_, _) async =>
              const AtomicWriteFailure(AtomicWriteError.io),
          onStep: steps.add,
        );

        expect(await r.coordinator.run(), isA<WipeFailed>());

        // Dừng ở bước lỗi: các bước sau chưa chạy, `wiping` còn trên đĩa.
        expect(steps.last, WipeStep.deleteTmp);
        expect(diskGuard().wiping, isTrue);
        expect(diskLastExport(), 1762300800000);
        expect(Directory(paths.vaultDir).existsSync(), isFalse);

        // Lần chạy sau (ghi được) xóa nốt.
        final retry = await rig();
        expect(await retry.coordinator.run(), isA<WipeDone>());
        expectClean();
      },
    );

    test('ad21_mark_wiping_failure_deletes_nothing', () async {
      seed();
      final before = pakEntries();
      final steps = <WipeStep>[];
      final r = await rig(
        guardWriter: AtomicFileWriter(
          RecordingFileSync(),
          onStep: (step) {
            if (step == AtomicWriteStep.createTmp) {
              throw SimulatedCrash();
            }
          },
        ),
        onStep: steps.add,
      );

      expect(await r.coordinator.run(), isA<WipeFailed>());

      expect(steps, isEmpty);
      expect(pakEntries(), before);
      expect(File(paths.headerFile).existsSync(), isTrue);
    });

    test('ad21_fsync_failure_stops_run_after_header_deleted', () async {
      seed();
      // fsync thứ nhất của coordinator là `vault/` ngay sau khi xóa `header`.
      final sync = RecordingFileSync(failAt: 1);
      final steps = <WipeStep>[];
      final r = await rig(sync: sync, onStep: steps.add);

      expect(await r.coordinator.run(), isA<WipeFailed>());

      expect(steps, [WipeStep.markWiping, WipeStep.invalidateSession]);
      expect(File(paths.headerFile).existsSync(), isFalse);
      expect(File(paths.cardsFile).existsSync(), isTrue);
      expect(diskGuard().wiping, isTrue);
    });

    test('ad21_hook_failure_is_wipe_failed_not_a_throw', () async {
      seed();
      final r = await rig(invalidateSession: () => throw SimulatedCrash());

      expect(await r.coordinator.run(), isA<WipeFailed>());
      expect(File(paths.headerFile).existsSync(), isTrue);
    });

    test('ad21_concurrent_runs_share_one_execution', () async {
      seed();
      final steps = <WipeStep>[];
      final r = await rig(onStep: steps.add);

      final a = r.coordinator.run();
      final b = r.coordinator.run();
      expect(await a, isA<WipeDone>());
      expect(await b, isA<WipeDone>());

      expect(steps, WipeStep.values);
    });

    test('ad26_fr12_after_wipe_create_starts_from_nothing', () async {
      seed(guard: const GuardState(failCount: 9));
      final writer = AtomicFileWriter(RecordingFileSync());
      final r = await rig();
      final service = AccountService(
        sodium: sodium,
        random: CountingRandom(),
        writer: writer,
        fileSync: RecordingFileSync(),
        paths: paths,
        guard: r.guard,
        wipe: r.coordinator,
        deriveKek: (_, _, _) async => sodium.secureCopy(seq(0xA0, kekBytes)),
        nowMs: kdfClock(),
      );

      expect(await service.wipe(), isA<WipeDone>());
      final created = await service.create('fake purple lantern 42 drift');

      expect(created, isA<CreateSuccess>());
      expect(
        [
          for (final e in Directory(paths.vaultDir).listSync())
            e.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
        ]..sort(),
        ['cards', 'header', 'recent'],
      );
      expect(Directory(paths.tmpDir).existsSync(), isFalse);
      expect(diskGuard(), GuardState.initial);
      expect(service.attemptsLeft, 10);
      expect(diskLastExport(), isNull);
      expect(r.settings.current.lastExportAt, isNull);
      (created as CreateSuccess).session.lock();
    });
  });

  group('resumeIfNeeded', () {
    test('ad26_wiping_flag_is_pending_even_without_account', () async {
      seed(guard: const GuardState(failCount: 2, wiping: true));
      File(paths.headerFile).deleteSync();
      final before = pakEntries();
      final r = await rig();

      expect(
        await r.coordinator.resumeIfNeeded(hasAccount: false),
        WipeResume.pending,
      );

      // Chưa xóa gì.
      expect(pakEntries(), before);
      expect(diskGuard().wiping, isTrue);
    });

    test('ad26_exhausted_count_is_pending_with_account', () async {
      seed();
      final before = pakEntries();
      final r = await rig();

      expect(
        await r.coordinator.resumeIfNeeded(hasAccount: true),
        WipeResume.pending,
      );
      expect(pakEntries(), before);
    });

    test(
      'ad26_account_with_normal_guard_is_not_needed_and_writes_nothing',
      () async {
        seed(guard: const GuardState(failCount: 3));
        final before = File(paths.guardFile).readAsBytesSync();
        final sync = RecordingFileSync();
        final r = await rig(sync: sync);

        expect(
          await r.coordinator.resumeIfNeeded(hasAccount: true),
          WipeResume.notNeeded,
        );

        expect(File(paths.guardFile).readAsBytesSync(), before);
        expect(sync.calls, isEmpty);
        expect(clock.reads, 0);
        expect(File(paths.headerFile).existsSync(), isTrue);
      },
    );

    test('ad26_no_account_with_leftover_files_is_cleaned', () async {
      seed(guard: GuardState.initial);
      File(paths.headerFile).deleteSync();
      final r = await rig();

      expect(
        await r.coordinator.resumeIfNeeded(hasAccount: false),
        WipeResume.cleaned,
      );
      expectClean();
    });

    test('ad26_no_account_with_stale_guard_is_cleaned', () async {
      File(paths.guardFile)
          .writeAsBytesSync(GuardCodec.encode(const GuardState(failCount: 6)));
      final r = await rig();

      expect(
        await r.coordinator.resumeIfNeeded(hasAccount: false),
        WipeResume.cleaned,
      );
      expect(diskGuard(), GuardState.initial);
    });

    test('ad26_fresh_install_does_nothing', () async {
      final sync = RecordingFileSync();
      final r = await rig(sync: sync);

      expect(
        await r.coordinator.resumeIfNeeded(hasAccount: false),
        WipeResume.notNeeded,
      );

      expect(pakEntries(), isEmpty);
      expect(sync.calls, isEmpty);
    });

    test('ad26_empty_vault_dir_without_account_is_not_leftover', () async {
      Directory(paths.vaultDir).createSync();
      final r = await rig();

      expect(
        await r.coordinator.resumeIfNeeded(hasAccount: false),
        WipeResume.notNeeded,
      );
      expect(Directory(paths.vaultDir).existsSync(), isTrue);
    });

    test('ad26_cleanup_failure_is_failed', () async {
      seed(guard: GuardState.initial);
      File(paths.headerFile).deleteSync();
      final r = await rig(sync: RecordingFileSync(failAlways: true));

      expect(
        await r.coordinator.resumeIfNeeded(hasAccount: false),
        WipeResume.failed,
      );
      expect(File(paths.cardsFile).existsSync(), isTrue);
    });
  });
}
