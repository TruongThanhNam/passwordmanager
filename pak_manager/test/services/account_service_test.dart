import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/crypto/kdf.dart';
import 'package:pak_manager/core/crypto/kdf_calibration.dart';
import 'package:pak_manager/core/crypto/random_source.dart';
import 'package:pak_manager/core/format/header_codec.dart';
import 'package:pak_manager/core/format/vault_file_codec.dart';
import 'package:pak_manager/core/io/atomic_file_writer.dart';
import 'package:pak_manager/core/io/pak_paths.dart';
import 'package:pak_manager/core/ports/file_sync_port.dart';
import 'package:pak_manager/services/account_service.dart';
import 'package:pak_manager/services/vault_session.dart';
import 'package:sodium/sodium_sumo.dart';

import '../core/vault_fixture.dart';

/// Mật khẩu giả (đã qua `PasswordPolicy` trong UI).
const _password = 'fake purple lantern 42 drift';

/// KEK giả cố định mà `derive` giả trả về (không chạy Argon2id thật).
Uint8List _kekBytes() => seq(0xA0, kekBytes);

/// fsync giả: ghi lại đường dẫn; ném ở lần gọi thứ [failAt] (đếm từ 1).
final class _RecordingFileSync implements FileSyncPort {
  _RecordingFileSync({this.failAt});

  final int? failAt;
  final List<String> calls = [];

  @override
  Future<void> fsyncDirectory(String path) async {
    calls.add(path);
    if (calls.length == failAt) {
      throw const FileSystemException('fsync giả lỗi');
    }
  }
}

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

  AccountService service({
    required AtomicFileWriter writer,
    required FileSyncPort fileSync,
    RandomSource? random,
    Future<SecureKey?> Function(Uint8List, Uint8List, KdfParams)? derive,
  }) {
    var clock = 0;
    return AccountService(
      sodium: sodium,
      random: random ?? _CountingRandom(),
      writer: writer,
      fileSync: fileSync,
      paths: paths,
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
      final sync = _RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);

      expect(await s.bootstrap(), isA<BootstrapNoAccount>());

      // Tắt giữa chừng: còn `cards`/`recent` nhưng chưa có `header`.
      Directory(paths.vaultDir).createSync();
      File(paths.cardsFile).writeAsBytesSync([1, 2, 3]);
      File(paths.recentFile).writeAsBytesSync([4, 5, 6]);
      expect(await s.bootstrap(), isA<BootstrapNoAccount>());
      // Bootstrap không dọn gì.
      expect(vaultNames(), ['cards', 'recent']);
      expect(sync.calls, isEmpty);
    });

    test('fr01_ad07_header_means_has_account', () async {
      final sync = _RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);
      Directory(paths.vaultDir).createSync();
      File(paths.headerFile).writeAsBytesSync([9]);

      expect(await s.bootstrap(), isA<BootstrapHasAccount>());
      expect(File(paths.headerFile).readAsBytesSync(), [9]);
    });
  });

  group('create', () {
    test('ad07_create_commits_cards_then_recent_then_header_last', () async {
      final sync = _RecordingFileSync();
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
      final sync = _RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);

      final result = await s.create(_password);

      expect(result, isA<CreateSuccess>());
      expect(vaultNames(), ['cards', 'header', 'recent']);
      expect(File(paths.cardsFile).readAsBytesSync(), isNot([1]));
      (result as CreateSuccess).session.lock();
    });

    test('ad07_create_refuses_when_header_exists', () async {
      Directory(paths.vaultDir).createSync();
      File(paths.headerFile).writeAsBytesSync([7, 7]);
      File(paths.cardsFile).writeAsBytesSync([8]);
      final sync = _RecordingFileSync();
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
      final sync = _RecordingFileSync();
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
          final sync = _RecordingFileSync();
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
      final sync = _RecordingFileSync(failAt: 4);
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
      final sync = _RecordingFileSync();
      final s = service(writer: AtomicFileWriter(sync), fileSync: sync);

      expect(await s.create(_password), isA<CreateFailure>());
      // Không tạo thư mục cha `pak/`.
      expect(Directory(paths.pakDir).existsSync(), isFalse);
    });

    test('ad22_password_bytes_are_wiped_on_success_and_failure', () async {
      for (final ok in [true, false]) {
        Uint8List? seen;
        final sync = _RecordingFileSync();
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
      final sync = _RecordingFileSync();
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

    /// Ảnh chụp mọi file dưới `pak/` (đường dẫn → byte).
    Map<String, List<int>> snapshot() => {
      for (final e in Directory(paths.pakDir).listSync(recursive: true))
        if (e is File) e.path: e.readAsBytesSync(),
    };

    var derives = 0;

    /// Service với KDF thật (Argon2id) bọc [_TrackedKey]; đếm số lần chạy.
    AccountService realService() {
      derives = 0;
      final sync = _RecordingFileSync();
      final real = kekDeriver(sodium);
      return service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        derive: (pw, salt, params) async {
          derives++;
          final kek = await real(pw, salt, params);
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

      final result = await s.unlock(fixturePw);

      expect(result, isA<UnlockSuccess>());
      final session = (result as UnlockSuccess).session;
      expect((session.readCards() as SessionOk).value, fixtureCards);
      expect((session.readRecent() as SessionOk).value, fixtureRecent);
      expect(derives, 1);
      expectKeksDisposed();
      expect(snapshot(), before);
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
      test('fr07_ad05_corrupt_header_skips_kdf_$name', () async {
        installVault({'header': header()});
        final before = snapshot();
        final s = realService();

        expect(await s.unlock(fixturePw), isA<UnlockCorrupt>());
        expect(derives, 0);
        expect(snapshot(), before);
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
      test('fr07_ad05_correct_password_bad_data_is_corrupt_$name', () async {
        installVault(files());
        final before = snapshot();
        final s = realService();

        expect(await s.unlock(fixturePw), isA<UnlockCorrupt>());
        expect(derives, 1);
        expectKeksDisposed();
        expect(snapshot(), before);
      });
    }

    test('fr07_kdf_failure_is_corrupt_not_a_throw', () async {
      installVault();
      final sync = _RecordingFileSync();
      final s = service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        derive: (_, _, _) async => null,
      );
      expect(await s.unlock(fixturePw), isA<UnlockCorrupt>());

      final throwing = service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        derive: (_, _, _) async => throw StateError('KDF giả lỗi'),
      );
      expect(await throwing.unlock(fixturePw), isA<UnlockCorrupt>());
    });

    test('ad22_unlock_wipes_password_bytes', () async {
      installVault();
      final seen = <Uint8List>[];
      final sync = _RecordingFileSync();
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

    test('ux_dr42_concurrent_unlock_returns_running_result', () async {
      installVault();
      final gate = Completer<void>();
      var count = 0;
      final sync = _RecordingFileSync();
      final real = kekDeriver(sodium);
      final s = service(
        writer: AtomicFileWriter(sync),
        fileSync: sync,
        derive: (pw, salt, params) async {
          count++;
          final kek = await real(pw, salt, params);
          await gate.future;
          return kek;
        },
      );

      final first = s.unlock(fixturePw);
      final second = s.unlock(fixturePw);
      gate.complete();
      final a = await first;
      final b = await second;

      expect(count, 1);
      expect(a, isA<UnlockSuccess>());
      expect(b, same(a));
      (a as UnlockSuccess).session.lock();

      // Xong rồi thì lần sau chạy lại bình thường.
      final third = await s.unlock(fixturePw);
      expect(count, 2);
      (third as UnlockSuccess).session.lock();
    });
  });
}
