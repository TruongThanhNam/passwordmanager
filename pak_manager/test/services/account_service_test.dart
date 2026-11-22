import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/crypto/kdf.dart';
import 'package:pak_manager/core/crypto/kdf_calibration.dart';
import 'package:pak_manager/core/crypto/random_source.dart';
import 'package:pak_manager/core/format/guard_codec.dart';
import 'package:pak_manager/core/format/header_codec.dart';
import 'package:pak_manager/core/format/vault_file_codec.dart';
import 'package:pak_manager/core/guard/guard_state.dart';
import 'package:pak_manager/core/io/atomic_file_writer.dart';
import 'package:pak_manager/core/io/pak_paths.dart';
import 'package:pak_manager/core/ports/file_sync_port.dart';
import 'package:pak_manager/services/account_service.dart';
import 'package:pak_manager/services/lockout_guard.dart';
import 'package:pak_manager/services/settings_store.dart';
import 'package:pak_manager/services/vault_session.dart';
import 'package:pak_manager/services/wipe_coordinator.dart';
import 'package:sodium/sodium_sumo.dart';

import '../core/vault_fixture.dart';
import '../support/port_fakes.dart';

/// Mật khẩu giả (đã qua `PasswordPolicy` trong UI).
const _password = 'fake purple lantern 42 drift';

/// KEK giả cố định mà `derive` giả trả về (không chạy Argon2id thật).
Uint8List _kekBytes() => seq(0xA0, kekBytes);

/// KEK thật (bọc `SecureKey` của libsodium) ghi nhận `dispose`, để kiểm
/// service luôn hủy KEK do `derive` trả về.
final class _TrackedKey implements SecureKey {
  _TrackedKey(this._inner);

  final SecureKey _inner;
  bool disposed = false;

  @override
  int get length => _inner.length;

  @override
  void dispose() {
    disposed = true;
    _inner.dispose();
  }

  @override
  T runUnlockedSync<T>(SecureCallbackFn<T> callback, {bool writable = false}) =>
      _inner.runUnlockedSync(callback, writable: writable);

  @override
  FutureOr<T> runUnlockedAsync<T>(
    SecureCallbackFn<FutureOr<T>> callback, {
    bool writable = false,
  }) => _inner.runUnlockedAsync(callback, writable: writable);

  @override
  Uint8List extractBytes() => _inner.extractBytes();

  @override
  SecureKey copy() => _inner.copy();
}

void main() {
  late SodiumSumo sodium;
  late Directory sandbox;
  late PakPaths paths;
  late FakeClock clock;

  /// Mọi bước `WipeCoordinator` đã chạy trong test hiện tại (spy qua
  /// `onStep`): `corrupt`/`retry` không bao giờ được thêm bước nào.
  late List<WipeStep> wipeSteps;

  /// Mọi KEK mà `derive` mặc định đã trả về trong test hiện tại.
  late List<_TrackedKey> keks;

  /// `derive` đã chạy và mọi KEK nó trả về đều đã bị hủy.
  void expectKeksDisposed() {
    expect(keks, isNotEmpty);
    expect(keks.map((k) => k.disposed), everyElement(isTrue));
  }

  setUpAll(() async => sodium = await initSodium());

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('pak_account_');
    paths = PakPaths(sandbox.path);
    keks = [];
    wipeSteps = [];
    // Đủ lớn để mọi mốc chờ giả đều không âm.
    clock = FakeClock(const Duration(hours: 10).inMilliseconds);
    // `pak/` do StorageBootstrap tạo; service không tạo thư mục cha.
    Directory(paths.pakDir).createSync();
  });
  tearDown(() => sandbox.deleteSync(recursive: true));

  /// Tên file (không đường dẫn) trong `vault/`, đã sắp xếp.
  List<String> vaultNames() {
    final dir = Directory(paths.vaultDir);
    if (!dir.existsSync()) {
      return const [];
    }
    return [
      for (final e in dir.listSync())
        e.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
    ]..sort();
  }

  /// Writer thật, ghi nhận thứ tự commit (tên file lúc rename) và có thể
  /// mô phỏng lỗi khi ghi [failFile].
  AtomicFileWriter recordingWriter(
    FileSyncPort sync,
    List<String> commits, {
    String? failFile,
  }) => AtomicFileWriter(
    sync,
    onStep: (step) {
      final tmps = [
        for (final name in vaultNames())
          if (name.endsWith('.tmp')) name.substring(0, name.length - 4),
      ];
      if (failFile != null &&
          step == AtomicWriteStep.writeTmp &&
          tmps.contains(failFile)) {
        throw SimulatedCrash();
      }
      if (step == AtomicWriteStep.rename) {
        commits.addAll(tmps);
      }
    },
  );

  /// Bytes của `guard`, hoặc `null` khi chưa có file.
  List<int>? guardBytes() {
    final file = File(paths.guardFile);
    return file.existsSync() ? file.readAsBytesSync() : null;
  }

  /// Trạng thái `guard` trên đĩa (file phải đọc được).
  GuardState diskState() => (GuardCodec.decode(guardBytes()!) as GuardOk).state;

  /// `failCount` trên đĩa (file phải đọc được).
  int diskFailCount() => diskState().failCount;

  void writeGuard(int failCount) => File(paths.guardFile)
      .writeAsBytesSync(GuardCodec.encode(GuardState(failCount: failCount)));

  AccountService service({
    required AtomicFileWriter writer,
    required FileSyncPort fileSync,
    RandomSource? random,
    Future<SecureKey?> Function(Uint8List, Uint8List, KdfParams)? derive,
    LockoutGuard? guard,
    SettingsStore? settings,
  }) {
    final lockout =
        guard ??
        LockoutGuard(
          sodium: sodium,
          writer: writer,
          path: paths.guardFile,
          clock: clock,
        );
    return AccountService(
      sodium: sodium,
      random: random ?? CountingRandom(),
      writer: writer,
      fileSync: fileSync,
      paths: paths,
      guard: lockout,
      wipe: WipeCoordinator(
        paths: paths,
        guard: lockout,
        settings: settings ?? SettingsStore.inMemory(),
        fileSync: fileSync,
        onStep: wipeSteps.add,
      ),
      deriveKek:
          derive ??
          (_, _, _) async {
            final kek = _TrackedKey(sodium.secureCopy(_kekBytes()));
            keks.add(kek);
            return kek;
          },
      // Mỗi lần KDF "mất" 1000 ms: hiệu chỉnh nhận ngay lần đầu.
      nowMs: kdfClock(),
    );
  }

  group('bootstrap', () {
    test('fr01_ad07_no_header_means_no_account', () async {
      final sync = RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);

      expect(await s.bootstrap(), isA<BootstrapNoAccount>());

      // Cài mới: không xóa gì, không ghi gì.
      expect(sync.calls, isEmpty);
      expect(guardBytes(), isNull);
      expect(Directory(paths.vaultDir).existsSync(), isFalse);
    });

    test('fr01_ad07_header_means_has_account', () async {
      final sync = RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);
      Directory(paths.vaultDir).createSync();
      File(paths.headerFile).writeAsBytesSync([9]);

      expect(await s.bootstrap(), isA<BootstrapHasAccount>());
      expect(File(paths.headerFile).readAsBytesSync(), [9]);
    });

    test('ad08_header_without_guard_recreates_guard_at_zero', () async {
      final sync = RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);
      Directory(paths.vaultDir).createSync();
      File(paths.headerFile).writeAsBytesSync([9]);

      expect(await s.bootstrap(), isA<BootstrapHasAccount>());
      expect(guardBytes(), GuardCodec.encode(GuardState.initial));
      expect(s.attemptsLeft, 10);
      expect(sync.calls, [paths.pakDir]);
    });

    test('ad08_header_with_unreadable_guard_recreates_guard_at_zero', () async {
      final sync = RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);
      Directory(paths.vaultDir).createSync();
      File(paths.headerFile).writeAsBytesSync([9]);
      File(paths.guardFile).writeAsBytesSync(utf8.encode('{"v":1}'));

      expect(await s.bootstrap(), isA<BootstrapHasAccount>());
      expect(guardBytes(), GuardCodec.encode(GuardState.initial));
      expect(s.attemptsLeft, 10);
    });

    test('ad08_guard_recreate_failure_keeps_zero_in_ram', () async {
      final sync = RecordingFileSync(failAlways: true);
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);
      Directory(paths.vaultDir).createSync();
      File(paths.headerFile).writeAsBytesSync([9]);
      File(paths.guardFile).writeAsBytesSync([0xff]);

      expect(await s.bootstrap(), isA<BootstrapHasAccount>());
      expect(s.attemptsLeft, 10);
    });

    test('fr04_fr06_bootstrap_loads_saved_count', () async {
      final sync = RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);
      Directory(paths.vaultDir).createSync();
      File(paths.headerFile).writeAsBytesSync([9]);
      writeGuard(3);
      final before = guardBytes();

      expect(await s.bootstrap(), isA<BootstrapHasAccount>());
      expect(s.attemptsLeft, 7);
      expect(guardBytes(), before);
      expect(sync.calls, isEmpty);
    });

    test('ad26_fr12_wiping_flag_returns_wiping_without_deleting', () async {
      final sync = RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);
      // Tắt giữa xóa: `header` đã mất, còn một phần file.
      Directory(paths.vaultDir).createSync();
      File(paths.cardsFile).writeAsBytesSync([1, 2, 3]);
      File(paths.draftFile).writeAsBytesSync([4]);
      File(paths.guardFile).writeAsBytesSync(
        GuardCodec.encode(const GuardState(failCount: 4, wiping: true)),
      );
      final before = guardBytes();

      expect(await s.bootstrap(), isA<BootstrapWiping>());

      // Chưa xóa gì, chưa ghi gì: S5 mới chạy `wipe()`.
      expect(vaultNames(), ['cards', 'draft']);
      expect(guardBytes(), before);
      expect(sync.calls, isEmpty);
    });

    test('ad26_fr04_exhausted_count_returns_bootstrap_wiping', () async {
      final sync = RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);
      // Tắt app lúc kiểm lần 10: còn đủ file, có `header`.
      Directory(paths.vaultDir).createSync();
      File(paths.headerFile).writeAsBytesSync([9]);
      File(paths.cardsFile).writeAsBytesSync([1]);
      writeGuard(10);
      final before = guardBytes();

      expect(await s.bootstrap(), isA<BootstrapWiping>());

      expect(vaultNames(), ['cards', 'header']);
      expect(guardBytes(), before);
      expect(sync.calls, isEmpty);

      // Xóa nốt rồi mở lại: về S1.
      expect(await s.wipe(), isA<WipeDone>());
      expect(vaultNames(), isEmpty);
      expect(await s.bootstrap(), isA<BootstrapNoAccount>());
    });

    test('ad26_fr12_no_header_with_leftover_files_cleans_silently', () async {
      final sync = RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);
      // Mất `header`, còn `cards`/`recent`/`draft`.
      Directory(paths.vaultDir).createSync();
      File(paths.cardsFile).writeAsBytesSync([1, 2, 3]);
      File(paths.recentFile).writeAsBytesSync([4, 5, 6]);
      File(paths.draftFile).writeAsBytesSync([7]);

      expect(await s.bootstrap(), isA<BootstrapNoAccount>());

      expect(Directory(paths.vaultDir).existsSync(), isFalse);
      expect(diskState(), GuardState.initial);
      expect(s.attemptsLeft, 10);
    });

    test('ad08_ad26_no_header_with_stale_guard_resets_guard', () async {
      final sync = RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);
      writeGuard(6);

      expect(await s.bootstrap(), isA<BootstrapNoAccount>());

      expect(diskState(), GuardState.initial);
      expect(s.attemptsLeft, 10);
      expect(await s.lockoutRemaining(), Duration.zero);
    });

    test('ad26_cleanup_failure_is_bootstrap_unavailable', () async {
      final sync = RecordingFileSync(failAlways: true);
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);
      Directory(paths.vaultDir).createSync();
      File(paths.cardsFile).writeAsBytesSync([1]);

      // `markWiping` không ghi được `guard` nên chưa xóa gì.
      expect(await s.bootstrap(), isA<BootstrapUnavailable>());
      expect(vaultNames(), ['cards']);
    });
  });

  group('create', () {
    test('ad07_create_commits_cards_then_recent_then_header_last', () async {
      final sync = RecordingFileSync();
      final commits = <String>[];
      final random = CountingRandom();
      final s = service(
        writer: recordingWriter(sync, commits),
        fileSync: sync,
        random: random,
      );

      final result = await s.create(_password);

      expect(result, isA<CreateSuccess>());
      expect(commits, ['cards', 'recent', 'header']);
      // KEK chỉ dùng để bọc DEK: hủy ngay cả khi thành công.
      expectKeksDisposed();
      expect(vaultNames(), ['cards', 'header', 'recent']);
      // fsync `pak/` sau khi tạo `vault/`, rồi `vault/` sau mỗi lần ghi.
      expect(sync.calls, [
        paths.pakDir,
        paths.vaultDir,
        paths.vaultDir,
        paths.vaultDir,
      ]);
      // salt → DEK → nonce bọc DEK → nonce `cards` → nonce `recent`.
      expect(random.requested, [16, 32, 24, 24, 24]);

      // Header đọc lại được, khóa đúng KEK, mở bọc ra DEK mở được hai file.
      final codec = HeaderCodec(sodium);
      final decoded = codec.decode(File(paths.headerFile).readAsBytesSync());
      expect(decoded, isA<HeaderOk>());
      final header = (decoded as HeaderOk).header;
      expect(header.kdf, KdfParams.start);
      final kek = sodium.secureCopy(_kekBytes());
      addTearDown(kek.dispose);
      expect(codec.kcvMatches(header, kek), isTrue);
      final dek = codec.unwrapDek(header, kek)!;
      addTearDown(dek.dispose);
      final files = VaultFileCodec(sodium, random);
      expect(
        files.decodeCards(File(paths.cardsFile).readAsBytesSync(), dek),
        isA<VaultFileOk<List<Object?>>>().having(
          (r) => r.value,
          'value',
          isEmpty,
        ),
      );
      expect(
        files.decodeRecent(File(paths.recentFile).readAsBytesSync(), dek),
        isA<VaultFileOk<List<Object?>>>().having(
          (r) => r.value,
          'value',
          isEmpty,
        ),
      );

      final session = (result as CreateSuccess).session;
      expect(session.isLocked, isFalse);
      expect((session.readCards() as SessionOk).value, isEmpty);
      expect((session.readRecent() as SessionOk).value, isEmpty);
      session.lock();
      expect(await s.bootstrap(), isA<BootstrapHasAccount>());
    });

    test('ad07_create_cleans_partial_vault_first', () async {
      Directory('${paths.vaultDir}${Platform.pathSeparator}junk')
          .createSync(recursive: true);
      File(paths.cardsFile).writeAsBytesSync([1]);
      File(paths.recentFile).writeAsBytesSync([2]);
      File(paths.draftFile).writeAsBytesSync([3]);
      final sync = RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);

      final result = await s.create(_password);

      expect(result, isA<CreateSuccess>());
      expect(vaultNames(), ['cards', 'header', 'recent']);
      expect(File(paths.cardsFile).readAsBytesSync(), isNot([1]));
      (result as CreateSuccess).session.lock();
    });

    // Mỗi trường hợp một sandbox mới: tạo hai lần trong cùng thư mục thì
    // lần hai phải xóa `vault/` vừa ghi, dễ vấp lỗi khóa file trên Windows.
    for (final existing in [null, 4]) {
      test(
        'ad08_create_never_reads_or_writes_guard_${existing ?? 'none'}',
        () async {
          if (existing != null) {
            writeGuard(existing);
          }
          final before = guardBytes();
          final sync = RecordingFileSync();
          final s = service(writer: AtomicFileWriter(sync), fileSync: sync);

          final result = await s.create(_password);

          expect(result, isA<CreateSuccess>());
          expect(guardBytes(), before);
          // `create` không nạp `guard`: RAM vẫn là trạng thái ban đầu.
          expect(s.attemptsLeft, 10);
          (result as CreateSuccess).session.lock();
        },
      );
    }

    test('ad07_create_refuses_when_header_exists', () async {
      Directory(paths.vaultDir).createSync();
      File(paths.headerFile).writeAsBytesSync([7, 7]);
      File(paths.cardsFile).writeAsBytesSync([8]);
      final sync = RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);

      expect(await s.create(_password), isA<CreateFailure>());
      // KDF chạy trước bước kiểm `header`: KEK đã sinh thì phải bị hủy.
      expectKeksDisposed();
      // Tài khoản đã commit: không xóa, không ghi gì.
      expect(File(paths.headerFile).readAsBytesSync(), [7, 7]);
      expect(File(paths.cardsFile).readAsBytesSync(), [8]);
      expect(sync.calls, isEmpty);
    });

    test('ad07_kdf_failure_creates_nothing', () async {
      final sync = RecordingFileSync();
      final s = service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        derive: (_, _, _) async => null,
      );

      expect(await s.create(_password), isA<CreateFailure>());
      expect(Directory(paths.vaultDir).existsSync(), isFalse);
      expect(sync.calls, isEmpty);
    });

    for (final failFile in ['cards', 'recent', 'header']) {
      test(
        'ad07_nfr11_write_failure_on_${failFile}_leaves_no_header',
        () async {
          final sync = RecordingFileSync();
          final commits = <String>[];
          final s = service(
            writer: recordingWriter(sync, commits, failFile: failFile),
            fileSync: sync,
          );

          expect(await s.create(_password), isA<CreateFailure>());
          expectKeksDisposed();
          expect(File(paths.headerFile).existsSync(), isFalse);
          expect(commits, isNot(contains('header')));
          expect(vaultNames().where((n) => n.endsWith('.tmp')), isEmpty);
          expect(await s.bootstrap(), isA<BootstrapNoAccount>());
        },
      );
    }

    test('ad07_fsync_failure_after_header_rename_removes_header', () async {
      // Lần fsync thứ 4 là `vault/` sau khi rename `header`.
      final sync = RecordingFileSync(failAt: 4);
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);

      expect(await s.create(_password), isA<CreateFailure>());
      expect(File(paths.headerFile).existsSync(), isFalse);
      expectKeksDisposed();
      // Sau khi xóa `header`, fsync `vault/` lần nữa để lần xóa bền.
      expect(sync.calls, hasLength(5));
      expect(sync.calls.last, paths.vaultDir);
      expect(await s.bootstrap(), isA<BootstrapNoAccount>());
    });

    test('ad07_missing_pak_dir_is_a_failure_not_a_throw', () async {
      Directory(paths.pakDir).deleteSync(recursive: true);
      final sync = RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);

      expect(await s.create(_password), isA<CreateFailure>());
      // Không tạo thư mục cha `pak/`.
      expect(Directory(paths.pakDir).existsSync(), isFalse);
    });

    test('ad22_password_bytes_are_wiped_on_success_and_failure', () async {
      for (final ok in [true, false]) {
        Uint8List? seen;
        final sync = RecordingFileSync();
        final s = service(
          writer: AtomicFileWriter(sync),
          fileSync: sync,
          derive: (password, _, _) async {
            seen = password;
            expect(password, isNot(everyElement(0)));
            return ok ? sodium.secureCopy(_kekBytes()) : null;
          },
        );

        final result = await s.create(_password);

        expect(result, ok ? isA<CreateSuccess>() : isA<CreateFailure>());
        expect(seen, hasLength(_password.length));
        expect(seen, everyElement(0));
        if (result is CreateSuccess) {
          result.session.lock();
        }
        if (Directory(paths.vaultDir).existsSync()) {
          Directory(paths.vaultDir).deleteSync(recursive: true);
        }
      }
    });

    test('ux_dr10_concurrent_create_runs_once', () async {
      final gate = Completer<void>();
      var derives = 0;
      final sync = RecordingFileSync();
      final s = service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        derive: (_, _, _) async {
          derives++;
          await gate.future;
          return sodium.secureCopy(_kekBytes());
        },
      );

      final first = s.create(_password);
      final second = await s.create(_password);
      gate.complete();

      expect(second, isA<CreateFailure>());
      final result = await first;
      expect(result, isA<CreateSuccess>());
      expect(derives, 1);
      (result as CreateSuccess).session.lock();
    });
  });

  group('unlock', () {
    const fixturePw = 'fixture-only correct horse 42';
    const wrongPw = 'fixture-only wrong horse 42!';
    const otherWrongPw = 'fixture-only other horse 42?';

    /// Chép fixture v1 thật vào `vault/`; [overrides] thay nội dung từng file
    /// (`null` = bỏ file đó).
    void installVault([Map<String, Uint8List?> overrides = const {}]) {
      Directory(paths.vaultDir).createSync();
      final targets = {
        'header': paths.headerFile,
        'cards': paths.cardsFile,
        'recent': paths.recentFile,
      };
      for (final MapEntry(key: name, value: path) in targets.entries) {
        final bytes = overrides.containsKey(name)
            ? overrides[name]
            : vaultFixture(name);
        if (bytes != null) {
          File(path).writeAsBytesSync(bytes);
        }
      }
    }

    /// Ảnh chụp mọi file dưới `pak/` (đường dẫn → byte), trừ chính file
    /// `guard` (kiểm riêng bằng `guardBytes()`).
    Map<String, List<int>> snapshot() => {
      for (final e in Directory(paths.pakDir).listSync(recursive: true))
        if (e is File && e.path != paths.guardFile) e.path: e.readAsBytesSync(),
    };

    var derives = 0;

    /// Service với KDF thật (Argon2id) bọc [_TrackedKey]; đếm số lần chạy.
    /// [onDerive] chạy ngay khi KDF bắt đầu (để đọc `guard` lúc đó);
    /// [hold] khác `null` thì KDF chờ nó xong mới trả.
    AccountService realService({
      void Function()? onDerive,
      Future<void>? hold,
      LockoutGuard? guard,
    }) {
      derives = 0;
      final sync = RecordingFileSync();
      final real = kekDeriver(sodium);
      return service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        guard: guard,
        derive: (pw, salt, params) async {
          derives++;
          onDerive?.call();
          final kek = await real(pw, salt, params);
          if (hold != null) {
            await hold;
          }
          if (kek == null) {
            return null;
          }
          final tracked = _TrackedKey(kek);
          keks.add(tracked);
          return tracked;
        },
      );
    }

    /// Header fixture với [mutate] áp lên byte rồi tính lại checksum (để
    /// qua `decode` và hỏng ở bước sau).
    Uint8List headerWith(void Function(Uint8List) mutate) {
      final bytes = vaultFixture('header');
      mutate(bytes);
      bytes.setAll(
        123,
        sodium.crypto.genericHash(
          message: Uint8List.sublistView(bytes, 0, 123),
          outLen: 32,
        ),
      );
      return bytes;
    }

    /// File `cards`/`recent` hợp lệ về mã hóa (DEK và AD của fixture) với bản
    /// rõ [json] tùy ý.
    Uint8List encryptedData(String json, String kind) {
      final nonce = seq(0x60, 24);
      final dek = sodium.secureCopy(fixtureDek());
      try {
        final ct = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
          message: utf8.encode(json),
          nonce: nonce,
          key: dek,
          additionalData: ascii.encode('PAK-VAULT/$kind/v1'),
        );
        return Uint8List.fromList([...nonce, ...ct]);
      } finally {
        dek.dispose();
      }
    }

    /// Số ký tự `x` cần thêm vào JSON dài [baseLength] (ASCII) để file mã hóa
    /// (`nonce[24] + bản rõ + tag[16]`) dài đúng `maxDataFileBytes + 1`.
    int oversizeFiller(int baseLength) =>
        AccountService.maxDataFileBytes + 1 - 24 - 16 - baseLength;

    /// JSON `cards` hợp lệ với một card có `note` dài [note] ký tự.
    String cardsJson({required int note}) =>
        '{"v":1,"cards":[{"id":"3f2b8c1e-5d4a-4e6f-9a7b-1c2d3e4f5a6b",'
        '"title":"t","username":"u","password":"p",'
        '"note":"${'x' * note}","createdAt":1}]}';

    /// JSON `recent` hợp lệ với một mục có `password` dài [password] ký tự.
    String recentJson({required int password}) =>
        '{"v":1,"items":[{"password":"${'x' * password}","recordedAt":1}]}';

    test('fr03_ad05_correct_password_unlocks_with_decrypted_data', () async {
      installVault();
      final before = snapshot();
      final s = realService();
      await s.bootstrap();

      final result = await s.unlock(fixturePw);

      expect(result, isA<UnlockSuccess>());
      final session = (result as UnlockSuccess).session;
      expect((session.readCards() as SessionOk).value, fixtureCards);
      expect((session.readRecent() as SessionOk).value, fixtureRecent);
      expect(derives, 1);
      expectKeksDisposed();
      expect(snapshot(), before);
      expect(diskFailCount(), 0);
      expect(s.attemptsLeft, 10);
      session.lock();
    });

    // Retro Epic 1, mục 8: máy không cấp nổi 64 MiB lúc hiệu chỉnh nên tạo
    // tài khoản ở sàn; mở khóa sau đó dùng đúng tham số trong header, bằng
    // Argon2id thật. (Lần 2/3 lỗi rồi lùi về sàn: `kdf_calibration_test`.)
    test('ad05_fr03_account_created_at_floor_unlocks_with_real_kdf', () async {
      final sync = RecordingFileSync();
      final real = kekDeriver(sodium);
      final creator = service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        derive: (pw, salt, params) async =>
            params == KdfParams.start ? null : real(pw, salt, params),
      );

      final created = await creator.create(_password);
      expect(created, isA<CreateSuccess>());
      (created as CreateSuccess).session.lock();

      final decoded = HeaderCodec(sodium)
          .decode(File(paths.headerFile).readAsBytesSync());
      expect((decoded as HeaderOk).header.kdf, KdfParams.floor);

      final s = realService();
      await s.bootstrap();
      final result = await s.unlock(_password);

      expect(result, isA<UnlockSuccess>());
      (result as UnlockSuccess).session.lock();
      expect(derives, 1);
      expectKeksDisposed();
    });

    test('fr03_ad05_wrong_password_is_wrong_not_corrupt', () async {
      installVault();
      final before = snapshot();
      final s = realService();

      expect(await s.unlock(wrongPw), isA<UnlockWrongPassword>());
      expect(derives, 1);
      expectKeksDisposed();
      expect(snapshot(), before);
    });

    test('fr04_ad08_first_wrong_is_on_disk_before_kdf', () async {
      installVault();
      int? seenAtKdf;
      final s = realService(onDerive: () => seenAtKdf = diskFailCount());
      await s.bootstrap();
      expect(s.attemptsLeft, 10);

      expect(await s.unlock(wrongPw), isA<UnlockWrongPassword>());

      expect(seenAtKdf, 1);
      expect(diskFailCount(), 1);
      expect(s.attemptsLeft, 9);
    });

    test('fr05_same_wrong_string_not_counted', () async {
      installVault();
      final s = realService();
      await s.bootstrap();
      expect(await s.unlock(wrongPw), isA<UnlockWrongPassword>());
      final afterFirst = guardBytes();

      // Nhập lại đúng chuỗi sai: báo sai ngay, không KDF, file không đổi.
      expect(await s.unlock(wrongPw), isA<UnlockWrongPassword>());
      expect(derives, 1);
      expect(guardBytes(), afterFirst);
      expect(s.attemptsLeft, 9);

      // Chuỗi sai khác thì đếm, và chỉ nhớ chuỗi sai ngay trước.
      expect(await s.unlock(otherWrongPw), isA<UnlockWrongPassword>());
      expect(derives, 2);
      expect(s.attemptsLeft, 8);
      expect(await s.unlock(wrongPw), isA<UnlockWrongPassword>());
      expect(derives, 3);
      expect(s.attemptsLeft, 7);
      expect(diskFailCount(), 3);
    });

    test('fr05_ad08_correct_after_wrong_resets_count', () async {
      installVault();
      writeGuard(3);
      final s = realService();
      await s.bootstrap();
      expect(s.attemptsLeft, 7);

      final result = await s.unlock(fixturePw);

      expect(result, isA<UnlockSuccess>());
      expect(diskFailCount(), 0);
      expect(s.attemptsLeft, 10);
      (result as UnlockSuccess).session.lock();

      // Chuỗi sai cũ bị quên: lần sau lại đếm như thường.
      expect(await s.unlock(wrongPw), isA<UnlockWrongPassword>());
      expect(s.attemptsLeft, 9);
    });

    test('fr06_ad08_app_killed_during_kdf_counts_on_restart', () async {
      installVault();
      final never = Completer<void>();
      final started = Completer<void>();
      final s = realService(hold: never.future, onDerive: started.complete);
      await s.bootstrap();

      // KDF treo như app bị tắt giữa lần kiểm tra.
      final pending = s.unlock(fixturePw);
      await started.future;
      expect(derives, 1);

      final restarted = realService();
      expect(await restarted.bootstrap(), isA<BootstrapHasAccount>());
      expect(restarted.attemptsLeft, 9);

      never.complete();
      final result = await pending;
      if (result is UnlockSuccess) {
        result.session.lock();
      }
    });

    for (final step in AtomicWriteStep.values) {
      test('ad08_pre_write_failure_at_${step.name}_skips_kdf', () async {
        installVault();
        final sync = RecordingFileSync();
        AtomicWriteStep? failAt;
        final guard = LockoutGuard(
          sodium: sodium,
          writer: AtomicFileWriter(
            sync,
            onStep: (at) {
              if (at == failAt) {
                throw SimulatedCrash();
              }
            },
          ),
          path: paths.guardFile,
          clock: clock,
        );
        final s = realService(guard: guard);
        await s.bootstrap();
        final before = guardBytes();

        failAt = step;
        expect(await s.unlock(fixturePw), isA<UnlockUnavailable>());

        expect(derives, 0);
        expect(s.attemptsLeft, 10);
        if (step != AtomicWriteStep.fsyncDirectory) {
          expect(guardBytes(), before);
        }
      });
    }

    test('fr04_ad08_exhausted_is_locked_out_without_write_or_kdf', () async {
      installVault();
      writeGuard(10);
      // Đếm lần ghi qua writer: ghi lại `failCount: 10` cho ra đúng byte cũ,
      // nên chỉ so nội dung file thì không bắt được một lần ghi thừa.
      var guardWrites = 0;
      final guard = LockoutGuard(
        sodium: sodium,
        writer: AtomicFileWriter(
          RecordingFileSync(),
          onStep: (step) {
            if (step == AtomicWriteStep.createTmp) {
              guardWrites++;
            }
          },
        ),
        path: paths.guardFile,
        clock: clock,
      );
      final s = realService(guard: guard);
      await s.bootstrap();
      final before = guardBytes();
      expect(s.attemptsLeft, 0);

      expect(await s.unlock(fixturePw), isA<UnlockLockedOut>());

      expect(derives, 0);
      expect(guardWrites, 0);
      expect(guardBytes(), before);
      expect(s.attemptsLeft, 0);
    });

    test('fr04_ad21_tenth_wrong_on_disk_before_kdf_deletes_nothing', () async {
      installVault();
      writeGuard(9);
      int? seenAtKdf;
      final s = realService(onDerive: () => seenAtKdf = diskFailCount());
      await s.bootstrap();
      clock.advance(waitDuration);
      final before = snapshot();

      expect(await s.unlock(wrongPw), isA<UnlockWipeRequired>());

      expect(seenAtKdf, 10);
      expect(diskFailCount(), 10);
      expect(derives, 1);
      expectKeksDisposed();
      // `unlock` không xóa gì; chạy xóa là việc của S5 qua `wipe()`.
      expect(snapshot(), before);
      expect(diskState().wiping, isFalse);
    });

    test('fr04_ad08_tenth_correct_password_logs_in_normally', () async {
      installVault();
      writeGuard(9);
      final s = realService();
      await s.bootstrap();
      clock.advance(waitDuration);

      final result = await s.unlock(fixturePw);

      expect(result, isA<UnlockSuccess>());
      expect(diskFailCount(), 0);
      expect(s.attemptsLeft, 10);
      (result as UnlockSuccess).session.lock();
    });

    test('fr04_ad08_tenth_correct_with_failed_reset_is_unavailable', () async {
      installVault();
      writeGuard(9);
      // Lần ghi thứ nhất (trước KDF, `failCount` 10) xong, lần thứ hai
      // (`recordSuccess`) lỗi.
      var guardWrites = 0;
      final guard = LockoutGuard(
        sodium: sodium,
        writer: AtomicFileWriter(
          RecordingFileSync(),
          onStep: (step) {
            if (step == AtomicWriteStep.createTmp) {
              guardWrites++;
              if (guardWrites == 2) {
                throw SimulatedCrash();
              }
            }
          },
        ),
        path: paths.guardFile,
        clock: clock,
      );
      final s = realService(guard: guard);
      await s.bootstrap();
      clock.advance(waitDuration);
      guardWrites = 0;
      final before = snapshot();

      // Không mở phiên: người vừa nhập đúng không bị xóa dữ liệu ngay.
      expect(await s.unlock(fixturePw), isA<UnlockUnavailable>());

      expect(guardWrites, 2);
      expectKeksDisposed();
      expect(snapshot(), before);
      // Đĩa còn 10: lần mở sau xóa nốt; RAM đã về 0 như cũ.
      expect(diskFailCount(), 10);
      expect(s.attemptsLeft, 10);
      expect(await realService().bootstrap(), isA<BootstrapWiping>());
    });

    test(
      'fr07_tc06_tenth_attempt_with_kdf_failure_is_retry_not_wipe',
      () async {
        installVault();
        writeGuard(9);
        final sync = RecordingFileSync();
        final s = service(
          writer: AtomicFileWriter(sync),
          fileSync: sync,
          derive: (_, _, _) async => null,
        );
        await s.bootstrap();
        clock.advance(waitDuration);
        final before = snapshot();
        final saved = diskState();
        expect(saved.failCount, 9);

        expect(await s.unlock(fixturePw), isA<UnlockRetry>());

        // Lần thử đã hoàn: đĩa và RAM về đúng trạng thái trước (cả mốc chờ).
        expect(diskState(), saved);
        expect(s.attemptsLeft, 1);
        expect(snapshot(), before);
        expect(wipeSteps, isEmpty);
        // Mở app lại: không xóa, vẫn còn đúng 1 lần thử.
        final restarted = service(
          writer: AtomicFileWriter(sync),
          fileSync: sync,
        );
        expect(await restarted.bootstrap(), isA<BootstrapHasAccount>());
        expect(restarted.attemptsLeft, 1);
        expect(diskState().wiping, isFalse);
        expect(wipeSteps, isEmpty);
      },
    );

    test('fr12_ad21_wipe_after_tenth_wrong_leaves_clean_slate', () async {
      installVault();
      writeGuard(9);
      final s = realService();
      await s.bootstrap();
      clock.advance(waitDuration);
      expect(await s.unlock(wrongPw), isA<UnlockWipeRequired>());

      expect(await s.wipe(), isA<WipeDone>());

      expect(Directory(paths.vaultDir).existsSync(), isFalse);
      expect(diskState(), GuardState.initial);
      expect(s.attemptsLeft, 10);
      expect(await s.bootstrap(), isA<BootstrapNoAccount>());
    });

    test('fr05_ad22_wrong_string_forgotten_after_wipe', () async {
      installVault();
      writeGuard(9);
      final s = realService();
      await s.bootstrap();
      clock.advance(waitDuration);
      expect(await s.unlock(wrongPw), isA<UnlockWipeRequired>());
      expect(await s.wipe(), isA<WipeDone>());

      // Tài khoản mới: cùng chuỗi sai cũ không bị coi là lặp, KDF chạy lại.
      installVault();
      expect(await s.unlock(wrongPw), isA<UnlockWrongPassword>());
      expect(derives, 2);
    });

    test('fr05_ad08_only_kcv_mismatch_remembers_wrong_string', () async {
      installVault();
      // Lần ghi trước KDF lỗi: không nhớ digest, thử lại đúng chuỗi đó vẫn
      // chạy KDF.
      var failWrites = true;
      final guard = LockoutGuard(
        sodium: sodium,
        writer: AtomicFileWriter(
          RecordingFileSync(),
          onStep: (step) {
            if (failWrites && step == AtomicWriteStep.createTmp) {
              throw SimulatedCrash();
            }
          },
        ),
        path: paths.guardFile,
        clock: clock,
      );
      final s = realService(guard: guard);
      await s.bootstrap();
      expect(await s.unlock(fixturePw), isA<UnlockUnavailable>());
      expect(derives, 0);

      failWrites = false;
      final afterUnavailable = await s.unlock(fixturePw);
      expect(afterUnavailable, isA<UnlockSuccess>());
      expect(derives, 1);
      (afterUnavailable as UnlockSuccess).session.lock();

      // KDF lỗi (`null` rồi ném): không nhớ digest, lần sau KDF chạy lại.
      final real = kekDeriver(sodium);
      final failures = <Future<SecureKey?> Function()>[
        () async => null,
        () async => throw StateError('KDF giả lỗi'),
      ];
      var kdfRuns = 0;
      final sync = RecordingFileSync();
      final flaky = service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        derive: (pw, salt, params) {
          final run = kdfRuns++;
          return run < failures.length
              ? failures[run]()
              : real(pw, salt, params);
        },
      );
      await flaky.bootstrap();
      expect(await flaky.unlock(fixturePw), isA<UnlockRetry>());
      expect(await flaky.unlock(fixturePw), isA<UnlockRetry>());
      final afterKdfFailure = await flaky.unlock(fixturePw);
      expect(afterKdfFailure, isA<UnlockSuccess>());
      expect(kdfRuns, 3);
      (afterKdfFailure as UnlockSuccess).session.lock();
    });

    test('fr05_ad08_reset_write_failure_still_unlocks', () async {
      installVault();
      writeGuard(3);
      // Lần ghi thứ nhất (trước KDF) thành công, lần thứ hai (`recordSuccess`)
      // lỗi.
      var guardWrites = 0;
      final guard = LockoutGuard(
        sodium: sodium,
        writer: AtomicFileWriter(
          RecordingFileSync(),
          onStep: (step) {
            if (step == AtomicWriteStep.createTmp && ++guardWrites == 2) {
              throw SimulatedCrash();
            }
          },
        ),
        path: paths.guardFile,
        clock: clock,
      );
      final s = realService(guard: guard);
      await s.bootstrap();

      final result = await s.unlock(fixturePw);

      expect(result, isA<UnlockSuccess>());
      expect(guardWrites, 2);
      final session = (result as UnlockSuccess).session;
      expect((session.readCards() as SessionOk).value, fixtureCards);
      expect(s.attemptsLeft, 10);
      // Đĩa còn số đã tăng trước KDF (DW-2.1-3).
      expect(diskFailCount(), 4);
      session.lock();
    });

    test('fr04_ad08_tenth_wrong_exhausts_attempts', () async {
      installVault();
      writeGuard(9);
      final s = realService();
      await s.bootstrap();
      // Lần sai thứ 9 vẫn bắt chờ: chỉ thử được khi hết giờ.
      expect(await s.lockoutRemaining(), waitDuration);
      clock.advance(waitDuration);
      final readsBefore = clock.reads;
      final bootReadsBefore = clock.bootReads;

      expect(await s.unlock(wrongPw), isA<UnlockWipeRequired>());
      expect(diskFailCount(), 10);
      expect(s.attemptsLeft, 0);
      // Chỉ lần kiểm chờ đọc đồng hồ; lần ghi `failCount: 10` thì không.
      expect(clock.reads, readsBefore + 1);
      expect(clock.bootReads, bootReadsBefore + 1);
      expect(await s.lockoutRemaining(), Duration.zero);

      // Mật khẩu đúng cũng không được thử nữa; `unlock` chưa xóa gì (S5 gọi
      // `wipe()`).
      expect(await s.unlock(fixturePw), isA<UnlockLockedOut>());
      expect(derives, 1);
    });

    test('fr04_ad08_fifth_wrong_writes_mark_before_kdf', () async {
      installVault();
      writeGuard(4);
      GuardState? seenAtKdf;
      final s = realService(onDerive: () => seenAtKdf = diskState());
      await s.bootstrap();
      expect(await s.lockoutRemaining(), Duration.zero);

      expect(await s.unlock(wrongPw), isA<UnlockWrongPassword>());

      final marked = GuardState(
        failCount: 5,
        waitBootId: clock.boot,
        waitStartMono: clock.ms,
      );
      expect(seenAtKdf, marked);
      expect(diskState(), marked);
      expect(s.attemptsLeft, 5);
      expect(await s.lockoutRemaining(), waitDuration);
    });

    test('fr04_ad09_clock_failure_on_fifth_is_unavailable', () async {
      installVault();
      writeGuard(4);
      final s = realService();
      await s.bootstrap();
      final before = guardBytes();
      clock.error = StateError('đồng hồ giả lỗi');

      expect(await s.unlock(wrongPw), isA<UnlockUnavailable>());

      expect(derives, 0);
      expect(guardBytes(), before);
      expect(s.attemptsLeft, 6);
    });

    test('fr04_ad08_waiting_is_locked_out_without_write_or_kdf', () async {
      installVault();
      writeGuard(4);
      var renames = 0;
      final guard = LockoutGuard(
        sodium: sodium,
        writer: AtomicFileWriter(
          RecordingFileSync(),
          onStep: (step) {
            if (step == AtomicWriteStep.rename) {
              renames++;
            }
          },
        ),
        path: paths.guardFile,
        clock: clock,
      );
      final s = realService(guard: guard);
      await s.bootstrap();
      expect(await s.unlock(wrongPw), isA<UnlockWrongPassword>());
      expect(derives, 1);
      final before = guardBytes();
      renames = 0;

      clock.advance(const Duration(minutes: 10));
      // Kể cả mật khẩu đúng cũng không được thử khi đang chờ.
      expect(await s.unlock(fixturePw), isA<UnlockLockedOut>());
      expect(await s.unlock(otherWrongPw), isA<UnlockLockedOut>());

      expect(derives, 1);
      expect(renames, 0);
      expect(guardBytes(), before);
      expect(s.attemptsLeft, 5);
      expect(await s.lockoutRemaining(), const Duration(minutes: 20));
    });

    test('fr04_ad08_after_wait_next_wrong_counts_and_sets_new_mark', () async {
      installVault();
      writeGuard(4);
      final s = realService();
      await s.bootstrap();
      expect(await s.unlock(wrongPw), isA<UnlockWrongPassword>());

      clock.advance(waitDuration);
      expect(await s.lockoutRemaining(), Duration.zero);
      expect(await s.unlock(otherWrongPw), isA<UnlockWrongPassword>());

      expect(derives, 2);
      expect(
        diskState(),
        GuardState(
          failCount: 6,
          waitBootId: clock.boot,
          waitStartMono: clock.ms,
        ),
      );
      expect(await s.lockoutRemaining(), waitDuration);
    });

    test('fr05_ad08_correct_after_wait_clears_mark', () async {
      installVault();
      writeGuard(4);
      final s = realService();
      await s.bootstrap();
      expect(await s.unlock(wrongPw), isA<UnlockWrongPassword>());
      clock.advance(waitDuration);

      final result = await s.unlock(fixturePw);

      expect(result, isA<UnlockSuccess>());
      expect(diskState(), GuardState.initial);
      expect(s.attemptsLeft, 10);
      expect(await s.lockoutRemaining(), Duration.zero);
      (result as UnlockSuccess).session.lock();
    });

    test('ad09_clock_failure_while_waiting_is_locked_out', () async {
      installVault();
      writeGuard(6);
      final s = realService();
      await s.bootstrap();
      clock.advance(waitDuration);
      clock.error = StateError('đồng hồ giả lỗi');

      expect(await s.lockoutRemaining(), waitDuration);
      expect(await s.unlock(fixturePw), isA<UnlockLockedOut>());
      expect(derives, 0);
      expect(s.attemptsLeft, 4);
    });

    test('fr06_ad08_restart_same_boot_keeps_remaining_without_write', () async {
      installVault();
      writeGuard(4);
      final s = realService();
      await s.bootstrap();
      expect(await s.unlock(wrongPw), isA<UnlockWrongPassword>());
      final saved = guardBytes();

      clock.advance(const Duration(minutes: 12));
      final sync = RecordingFileSync();
      final restarted = service(writer: AtomicFileWriter(sync), fileSync: sync);
      expect(await restarted.bootstrap(), isA<BootstrapHasAccount>());

      expect(sync.calls, isEmpty);
      expect(guardBytes(), saved);
      expect(await restarted.lockoutRemaining(), const Duration(minutes: 18));
    });

    test('tc03_ad08_reboot_bootstrap_writes_new_mark_first', () async {
      installVault();
      writeGuard(4);
      final s = realService();
      await s.bootstrap();
      expect(await s.unlock(wrongPw), isA<UnlockWrongPassword>());

      // Khởi động lại máy sau 20 phút: `bootId` khác, đồng hồ đơn điệu lùi.
      clock
        ..boot = 'fake-boot-2'
        ..ms = 5000;
      final restarted = realService();
      expect(await restarted.bootstrap(), isA<BootstrapHasAccount>());

      // Mốc mới đã nằm trên đĩa khi `bootstrap` trả.
      expect(
        diskState(),
        const GuardState(
          failCount: 5,
          waitBootId: 'fake-boot-2',
          waitStartMono: 5000,
        ),
      );
      expect(await restarted.lockoutRemaining(), waitDuration);

      // Ghi lỗi: RAM vẫn chờ lại từ 30:00.
      clock
        ..boot = 'fake-boot-3'
        ..ms = 7000;
      final failing = RecordingFileSync(failAlways: true);
      final broken = service(
        writer: AtomicFileWriter(failing),
        fileSync: failing,
      );
      expect(await broken.bootstrap(), isA<BootstrapHasAccount>());
      expect(await broken.lockoutRemaining(), waitDuration);
    });

    final corruptHeaders = <String, Uint8List? Function()>{
      'missing': () => null,
      'truncated': () => Uint8List.sublistView(vaultFixture('header'), 0, 154),
      'bad_magic': () => vaultFixture('header')..[0] ^= 0xff,
      'bad_checksum': () => vaultFixture('header')..[154] ^= 0x01,
      'kdf_out_of_range': () => headerWith(
        (b) => ByteData.sublistView(b).setUint32(7, 11, Endian.little),
      ),
      'oversize_by_one': () =>
          Uint8List.fromList([...vaultFixture('header'), 0]),
      'oversize_huge': () => Uint8List.fromList([
        ...vaultFixture('header'),
        ...Uint8List(1024 * 1024),
      ]),
      // Version mới hơn app hỗ trợ, checksum đúng (AD-25).
      'version_newer': () => headerWith(
        (b) => ByteData.sublistView(b).setUint16(4, 2, Endian.little),
      ),
    };
    for (final MapEntry(key: name, value: header) in corruptHeaders.entries) {
      test(
        'fr07_ad05_ad08_ad25_tc06_corrupt_header_skips_guard_and_kdf_$name',
        () async {
          installVault({'header': header()});
          writeGuard(2);
          final s = realService();
          await s.bootstrap();
          // Thiếu `header` thì bootstrap dọn `vault/` (AD-26): không tính.
          wipeSteps.clear();
          final before = snapshot();
          final guardBefore = guardBytes();

          expect(await s.unlock(fixturePw), isA<UnlockCorrupt>());
          expect(derives, 0);
          expect(snapshot(), before);
          expect(guardBytes(), guardBefore);
          // Thiếu `header` thì bootstrap đã dọn `guard` sót (AD-26).
          expect(s.attemptsLeft, name == 'missing' ? 10 : 8);
          expect(wipeSteps, isEmpty);
          if (name != 'missing') {
            expect(diskState().wiping, isFalse);
          }
        },
      );
    }

    final corruptData = <String, Map<String, Uint8List?> Function()>{
      'cards_tampered': () => {'cards': vaultFixture('cards')..[30] ^= 0x01},
      'recent_tampered': () => {'recent': vaultFixture('recent')..[30] ^= 0x01},
      'cards_missing': () => {'cards': null},
      'recent_missing': () => {'recent': null},
      'cards_garbage': () => {'cards': Uint8List(3)},
      'wrapped_dek_tampered': () => {
        'header': headerWith((b) => b[59] ^= 0x01),
      },
      // Payload AEAD hợp lệ, file dài đúng `maxDataFileBytes + 1` byte: giải
      // mã không lỗi, nên chỉ trần kích thước mới làm nó `corrupt` (không có
      // trần thì `unlock` thành công).
      'cards_oversize': () => {
        'cards': encryptedData(
          cardsJson(note: oversizeFiller(cardsJson(note: 0).length)),
          'cards',
        ),
      },
      'recent_oversize': () => {
        'recent': encryptedData(
          recentJson(password: oversizeFiller(recentJson(password: 0).length)),
          'recent',
        ),
      },
      // `v` mới hơn app hỗ trợ, mã hóa đúng bằng DEK của fixture (AD-25).
      'cards_version_newer': () => {
        'cards': encryptedData('{"v":2,"cards":[]}', 'cards'),
      },
      'recent_version_newer': () => {
        'recent': encryptedData('{"v":2,"items":[]}', 'recent'),
      },
    };
    for (final MapEntry(key: name, value: files) in corruptData.entries) {
      test(
        'fr07_ad08_ad25_tc06_correct_password_bad_data_is_corrupt_and_resets_$name',
        () async {
          installVault(files());
          writeGuard(3);
          final s = realService();
          await s.bootstrap();
          final before = snapshot();

          expect(await s.unlock(fixturePw), isA<UnlockCorrupt>());
          expect(derives, 1);
          expectKeksDisposed();
          expect(snapshot(), before);
          // `kcv` khớp: bộ đếm về 0 trước khi mở bọc DEK/giải mã (AD-4).
          expect(diskFailCount(), 0);
          expect(s.attemptsLeft, 10);
          expect(wipeSteps, isEmpty);
          expect(diskState().wiping, isFalse);
        },
      );
    }

    test('fr07_tc06_valid_large_data_under_cap_unlocks', () async {
      // Cùng dạng payload với `*_oversize` nhưng nhỏ hơn trần: mở được, nên
      // `*_oversize` hỏng thật sự là do kích thước chứ không do giải mã.
      installVault({
        'cards': encryptedData(cardsJson(note: 1024 * 1024), 'cards'),
        'recent': encryptedData(recentJson(password: 1024 * 1024), 'recent'),
      });
      final s = realService();
      await s.bootstrap();

      final result = await s.unlock(fixturePw);

      expect(result, isA<UnlockSuccess>());
      expect(diskFailCount(), 0);
      expect(wipeSteps, isEmpty);
      (result as UnlockSuccess).session.lock();
    });

    test('fr07_tc06_data_exactly_at_cap_unlocks', () async {
      // Ghim biên: file dài đúng `maxDataFileBytes` vẫn mở được (trần là
      // `>`, không phải `>=`); `*_oversize` dài hơn đúng một byte.
      final cards = encryptedData(
        cardsJson(note: oversizeFiller(cardsJson(note: 0).length) - 1),
        'cards',
      );
      final recent = encryptedData(
        recentJson(
          password: oversizeFiller(recentJson(password: 0).length) - 1,
        ),
        'recent',
      );
      expect(cards.length, AccountService.maxDataFileBytes);
      expect(recent.length, AccountService.maxDataFileBytes);
      installVault({'cards': cards, 'recent': recent});
      final s = realService();
      await s.bootstrap();

      final result = await s.unlock(fixturePw);

      expect(result, isA<UnlockSuccess>());
      expect(diskFailCount(), 0);
      expect(wipeSteps, isEmpty);
      (result as UnlockSuccess).session.lock();
    });

    final kdfFailures =
        <String, Future<SecureKey?> Function(Uint8List, Uint8List, KdfParams)>{
          'null': (_, _, _) async => null,
          'throws': (_, _, _) async => throw StateError('KDF giả lỗi'),
        };
    for (final MapEntry(key: name, value: derive) in kdfFailures.entries) {
      test('fr07_tc06_kdf_failure_${name}_is_retry_and_not_counted', () async {
        installVault();
        final sync = RecordingFileSync();
        final s = service(
          writer: AtomicFileWriter(sync),
          fileSync: sync,
          derive: derive,
        );
        await s.bootstrap();
        final before = snapshot();

        expect(await s.unlock(fixturePw), isA<UnlockRetry>());

        expect(diskState(), GuardState.initial);
        expect(s.attemptsLeft, 10);
        expect(snapshot(), before);
        expect(wipeSteps, isEmpty);

        // Bấm lại ngay vẫn chạy KDF (không bị coi là chuỗi sai lặp lại).
        expect(await s.unlock(fixturePw), isA<UnlockRetry>());
        expect(diskState(), GuardState.initial);
        expect(s.attemptsLeft, 10);
      });
    }

    test('fr07_tc06_kdf_failure_restores_count_and_wait_mark', () async {
      installVault();
      writeGuard(6);
      final sync = RecordingFileSync();
      var fail = true;
      final real = kekDeriver(sodium);
      final s = service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        derive: (pw, salt, params) async =>
            fail ? null : real(pw, salt, params),
      );
      await s.bootstrap();
      clock.advance(waitDuration);
      final saved = diskState();
      expect(saved.failCount, 6);
      expect(saved.waitStartMono, isNotNull);

      expect(await s.unlock(fixturePw), isA<UnlockRetry>());

      expect(diskState(), saved);
      expect(s.attemptsLeft, 4);
      expect(await s.lockoutRemaining(), Duration.zero);

      // KDF chạy lại được: đăng nhập đúng bình thường, bộ đếm về 0.
      fail = false;
      final ok = await s.unlock(fixturePw);
      expect(ok, isA<UnlockSuccess>());
      expect(diskFailCount(), 0);
      (ok as UnlockSuccess).session.lock();
    });

    test('fr07_tc06_kdf_failure_at_fifth_attempt_leaves_no_wait', () async {
      installVault();
      writeGuard(4);
      final sync = RecordingFileSync();
      final s = service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        derive: (_, _, _) async => null,
      );
      await s.bootstrap();

      // Lần thử 5 ghi mốc chờ mới rồi KDF lỗi: hoàn cả mốc, không bị chờ.
      expect(await s.unlock(fixturePw), isA<UnlockRetry>());

      expect(diskState(), const GuardState(failCount: 4));
      expect(await s.lockoutRemaining(), Duration.zero);
      expect(s.attemptsLeft, 6);
    });

    test('fr07_tc06_kdf_failure_with_failed_revert_keeps_attempt', () async {
      installVault();
      var guardWrites = 0;
      final sync = RecordingFileSync();
      final guard = LockoutGuard(
        sodium: sodium,
        writer: AtomicFileWriter(
          sync,
          onStep: (step) {
            if (step == AtomicWriteStep.createTmp) {
              guardWrites++;
              // Lần ghi thứ hai (hoàn lượt) lỗi.
              if (guardWrites == 2) {
                throw SimulatedCrash();
              }
            }
          },
        ),
        path: paths.guardFile,
        clock: clock,
      );
      final s = service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        guard: guard,
        derive: (_, _, _) async => null,
      );
      await s.bootstrap();
      guardWrites = 0;

      // Không ném; lần thử vẫn tính (fail closed).
      expect(await s.unlock(fixturePw), isA<UnlockRetry>());

      expect(guardWrites, 2);
      expect(diskFailCount(), 1);
      expect(s.attemptsLeft, 9);
      expect(wipeSteps, isEmpty);
    });

    test('fr06_tc06_app_killed_before_revert_still_counts', () async {
      installVault();
      final never = Completer<void>();
      final started = Completer<void>();
      final sync = RecordingFileSync();
      final s = service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        derive: (_, _, _) async {
          started.complete();
          await never.future;
          return null;
        },
      );
      await s.bootstrap();

      // KDF treo như app bị tắt trước khi kịp hoàn lượt: vẫn tính là sai.
      final pending = s.unlock(fixturePw);
      await started.future;
      final restarted = service(writer: AtomicFileWriter(sync), fileSync: sync);
      expect(await restarted.bootstrap(), isA<BootstrapHasAccount>());
      expect(restarted.attemptsLeft, 9);

      never.complete();
      expect(await pending, isA<UnlockRetry>());
    });

    test('ad22_unlock_wipes_password_bytes', () async {
      installVault();
      final seen = <Uint8List>[];
      final sync = RecordingFileSync();
      final real = kekDeriver(sodium);
      final s = service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        derive: (pw, salt, params) {
          seen.add(pw);
          return real(pw, salt, params);
        },
      );

      final ok = await s.unlock(fixturePw);
      expect(await s.unlock(wrongPw), isA<UnlockWrongPassword>());
      expect(seen, hasLength(2));
      for (final pw in seen) {
        expect(pw, everyElement(0));
      }
      (ok as UnlockSuccess).session.lock();
    });

    test(
      'ux_dr42_concurrent_unlock_is_busy_and_never_shares_session',
      () async {
        installVault();
        final gate = Completer<void>();
        var guardWrites = 0;
        final sync = RecordingFileSync();
        final guard = LockoutGuard(
          sodium: sodium,
          writer: AtomicFileWriter(
            sync,
            onStep: (step) {
              if (step == AtomicWriteStep.rename) {
                guardWrites++;
              }
            },
          ),
          path: paths.guardFile,
          clock: clock,
        );
        final s = realService(hold: gate.future, guard: guard);
        await s.bootstrap();
        guardWrites = 0;

        final first = s.unlock(fixturePw);
        // Lần hai (kể cả cùng mật khẩu đúng) không nhận phiên của lần một.
        final second = await s.unlock(fixturePw);
        final third = await s.unlock(wrongPw);
        expect(second, isA<UnlockBusy>());
        expect(third, isA<UnlockBusy>());
        gate.complete();
        final a = await first;

        expect(a, isA<UnlockSuccess>());
        expect(derives, 1);
        // Một lần ghi trước KDF và một lần `recordSuccess`.
        expect(guardWrites, 2);
        expect(s.attemptsLeft, 10);
        (a as UnlockSuccess).session.lock();

        // Xong rồi thì lần sau chạy lại bình thường.
        final again = await s.unlock(fixturePw);
        expect(derives, 2);
        (again as UnlockSuccess).session.lock();
      },
    );
  });
}
