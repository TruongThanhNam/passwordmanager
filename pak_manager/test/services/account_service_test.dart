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
import 'package:pak_manager/services/vault_session.dart';
import 'package:sodium/sodium_sumo.dart';

import '../core/vault_fixture.dart';
import '../support/port_fakes.dart';

/// Mật khẩu giả (đã qua `PasswordPolicy` trong UI).
const _password = 'fake purple lantern 42 drift';

/// KEK giả cố định mà `derive` giả trả về (không chạy Argon2id thật).
Uint8List _kekBytes() => seq(0xA0, kekBytes);

/// [RandomSource] tất định: mỗi lần gọi trả một dãy byte mới.
final class _CountingRandom implements RandomSource {
  int _next = 1;
  final List<int> requested = [];

  @override
  Uint8List bytes(int length) {
    requested.add(length);
    return seq((_next++) * 7, length);
  }
}

final class _SimulatedCrash implements Exception {}

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
        throw _SimulatedCrash();
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

  /// `failCount` trên đĩa (file phải đọc được).
  int diskFailCount() =>
      (GuardCodec.decode(guardBytes()!) as GuardOk).state.failCount;

  void writeGuard(int failCount) => File(paths.guardFile)
      .writeAsBytesSync(GuardCodec.encode(GuardState(failCount: failCount)));

  AccountService service({
    required AtomicFileWriter writer,
    required FileSyncPort fileSync,
    RandomSource? random,
    Future<SecureKey?> Function(Uint8List, Uint8List, KdfParams)? derive,
    LockoutGuard? guard,
  }) {
    var clock = 0;
    return AccountService(
      sodium: sodium,
      random: random ?? _CountingRandom(),
      writer: writer,
      fileSync: fileSync,
      paths: paths,
      guard:
          guard ??
          LockoutGuard(sodium: sodium, writer: writer, path: paths.guardFile),
      deriveKek:
          derive ??
          (_, _, _) async {
            final kek = _TrackedKey(sodium.secureCopy(_kekBytes()));
            keks.add(kek);
            return kek;
          },
      // Mỗi lần KDF "mất" 1000 ms: hiệu chỉnh nhận ngay lần đầu.
      nowMs: () {
        final now = clock;
        clock += 1000;
        return now;
      },
    );
  }

  group('bootstrap', () {
    test('fr01_ad07_no_header_means_no_account', () async {
      final sync = RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);

      expect(await s.bootstrap(), isA<BootstrapNoAccount>());

      // Tắt giữa chừng: còn `cards`/`recent` nhưng chưa có `header`.
      Directory(paths.vaultDir).createSync();
      File(paths.cardsFile).writeAsBytesSync([1, 2, 3]);
      File(paths.recentFile).writeAsBytesSync([4, 5, 6]);
      expect(await s.bootstrap(), isA<BootstrapNoAccount>());
      // Bootstrap không dọn gì; không có `header` thì không ghi `guard`.
      expect(vaultNames(), ['cards', 'recent']);
      expect(sync.calls, isEmpty);
      expect(guardBytes(), isNull);
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
  });

  group('create', () {
    test('ad07_create_commits_cards_then_recent_then_header_last', () async {
      final sync = RecordingFileSync();
      final commits = <String>[];
      final random = _CountingRandom();
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
                throw _SimulatedCrash();
              }
            },
          ),
          path: paths.guardFile,
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
      final s = realService();
      await s.bootstrap();
      final before = guardBytes();
      expect(s.attemptsLeft, 0);

      expect(await s.unlock(fixturePw), isA<UnlockLockedOut>());

      expect(derives, 0);
      expect(guardBytes(), before);
      expect(s.attemptsLeft, 0);
    });

    test('fr04_ad08_tenth_wrong_exhausts_attempts', () async {
      installVault();
      writeGuard(9);
      final s = realService();
      await s.bootstrap();

      expect(await s.unlock(wrongPw), isA<UnlockWrongPassword>());
      expect(diskFailCount(), 10);
      expect(s.attemptsLeft, 0);

      // Mật khẩu đúng cũng không được thử nữa (chưa xóa: story 2.3).
      expect(await s.unlock(fixturePw), isA<UnlockLockedOut>());
      expect(derives, 1);
    });

    final corruptHeaders = <String, Uint8List? Function()>{
      'missing': () => null,
      'truncated': () => Uint8List.sublistView(vaultFixture('header'), 0, 154),
      'bad_magic': () => vaultFixture('header')..[0] ^= 0xff,
      'bad_checksum': () => vaultFixture('header')..[154] ^= 0x01,
      'kdf_out_of_range': () => headerWith(
        (b) => ByteData.sublistView(b).setUint32(7, 11, Endian.little),
      ),
    };
    for (final MapEntry(key: name, value: header) in corruptHeaders.entries) {
      test('fr07_ad05_ad08_corrupt_header_skips_guard_and_kdf_$name', () async {
        installVault({'header': header()});
        writeGuard(2);
        final s = realService();
        await s.bootstrap();
        final before = snapshot();
        final guardBefore = guardBytes();

        expect(await s.unlock(fixturePw), isA<UnlockCorrupt>());
        expect(derives, 0);
        expect(snapshot(), before);
        expect(guardBytes(), guardBefore);
        expect(s.attemptsLeft, 8);
      });
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
    };
    for (final MapEntry(key: name, value: files) in corruptData.entries) {
      test(
        'fr07_ad08_correct_password_bad_data_is_corrupt_and_resets_$name',
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
        },
      );
    }

    test('fr07_kdf_failure_is_corrupt_not_a_throw_and_still_counts', () async {
      installVault();
      final sync = RecordingFileSync();
      final s = service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        derive: (_, _, _) async => null,
      );
      await s.bootstrap();
      expect(await s.unlock(fixturePw), isA<UnlockCorrupt>());
      // Đã ghi trước KDF: lần thử vẫn tính (story 2.5 tách riêng).
      expect(diskFailCount(), 1);
      expect(s.attemptsLeft, 9);

      final throwing = service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        derive: (_, _, _) async => throw StateError('KDF giả lỗi'),
      );
      await throwing.bootstrap();
      expect(await throwing.unlock(fixturePw), isA<UnlockCorrupt>());
      expect(diskFailCount(), 2);
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
