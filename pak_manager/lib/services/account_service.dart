import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import '../core/crypto/kdf.dart';
import '../core/crypto/kdf_calibration.dart';
import '../core/crypto/random_source.dart';
import '../core/crypto/wipe.dart';
import '../core/format/header_codec.dart';
import '../core/format/vault_file_codec.dart';
import '../core/io/atomic_file_writer.dart';
import '../core/io/pak_paths.dart';
import '../core/model/recent_entry.dart';
import '../core/model/vault_card.dart';
import '../core/ports/file_sync_port.dart';
import 'vault_session.dart';

/// Kết quả [AccountService.bootstrap].
sealed class BootstrapResult {
  const BootstrapResult();
}

/// Chưa có tài khoản đã commit (không có `vault/header`): hiện S1.
final class BootstrapNoAccount extends BootstrapResult {
  const BootstrapNoAccount();

  @override
  String toString() => 'BootstrapNoAccount()';
}

/// Có `vault/header`: hiện S3.
final class BootstrapHasAccount extends BootstrapResult {
  const BootstrapHasAccount();

  @override
  String toString() => 'BootstrapHasAccount()';
}

/// Lưu trữ, Sodium hoặc blocklist không dùng được (fail closed): không đọc/ghi
/// vault, không cho tạo tài khoản.
final class BootstrapUnavailable extends BootstrapResult {
  const BootstrapUnavailable();

  @override
  String toString() => 'BootstrapUnavailable()';
}

/// Kết quả [AccountService.create].
sealed class CreateResult {
  const CreateResult();
}

/// Tài khoản đã commit (`header` đã ghi); [session] là phiên mới, người gọi
/// sở hữu và phải `dispose`.
final class CreateSuccess extends CreateResult {
  const CreateSuccess(this.session);

  final VaultSession session;

  @override
  String toString() => 'CreateSuccess($session)';
}

/// Không tạo được tài khoản; không để lại `header`. Không kèm lý do (UI chỉ
/// hiện `create.failed`).
final class CreateFailure extends CreateResult {
  const CreateFailure();

  @override
  String toString() => 'CreateFailure()';
}

/// Kết quả [AccountService.unlock] (AD-5). UI ánh xạ sang microcopy.
sealed class UnlockResult {
  const UnlockResult();
}

/// Đúng mật khẩu, dữ liệu giải mã được; [session] là phiên mới, người gọi
/// sở hữu và phải `dispose`.
final class UnlockSuccess extends UnlockResult {
  const UnlockSuccess(this.session);

  final VaultSession session;

  @override
  String toString() => 'UnlockSuccess($session)';
}

/// `kcv` lệch: sai mật khẩu (`login.wrong`).
final class UnlockWrongPassword extends UnlockResult {
  const UnlockWrongPassword();

  @override
  String toString() => 'UnlockWrongPassword()';
}

/// Header hỏng/không đọc được, hoặc mật khẩu đúng nhưng dữ liệu không giải
/// mã được (`login.corrupt`). Không file nào bị xóa.
// Epic 2 thêm lớp con `lockedOut` (LockoutGuard).
final class UnlockCorrupt extends UnlockResult {
  const UnlockCorrupt();

  @override
  String toString() => 'UnlockCorrupt()';
}

/// Lối vào duy nhất cho vòng đời tài khoản (AD-6): [bootstrap], [create],
/// [unlock]. `verify()` thêm ở story đổi mật khẩu/export.
///
/// Không method nào ném qua ranh giới lớp: mọi lỗi thành kết quả sealed.
class AccountService {
  AccountService({
    required SodiumSumo sodium,
    required this._random,
    required this._writer,
    required this._fileSync,
    required this._paths,
    KekDeriver? deriveKek,
    this._nowMs,
  }) : _sodium = sodium,
       _deriveKek = deriveKek ?? kekDeriver(sodium);

  final SodiumSumo _sodium;
  final RandomSource _random;
  final AtomicFileWriter _writer;
  final FileSyncPort _fileSync;
  final PakPaths _paths;
  final KekDeriver _deriveKek;

  /// Đồng hồ của hiệu chỉnh KDF; `null` = `Stopwatch` mặc định.
  final int Function()? _nowMs;

  bool _creating = false;

  /// Lần [unlock] đang chạy; gọi chồng thì trả lại chính `Future` này.
  Future<UnlockResult>? _unlocking;

  /// Trạng thái tài khoản lúc khởi động, chạy trước `runApp` (không có màn
  /// chờ, UX-DR30). Chỉ kiểm `vault/header` có tồn tại hay không; không đọc,
  /// không ghi, không xóa gì.
  ///
  /// Thiếu `header` nghĩa là chưa có tài khoản đã commit (AD-7), kể cả khi
  /// `vault/` còn `cards`/`recent` từ lần tạo bị tắt giữa chừng: phần đó được
  /// [create] dọn.
  Future<BootstrapResult> bootstrap() async {
    // Epic 2 chèn các bước của mình vào đây, trước khi kiểm `header`:
    // - đọc `guard` (LockoutGuard): đếm số lần sai, đang khóa tạm hay không;
    // - phát hiện lần xóa bị gián đoạn (WipeCoordinator) → làm tiếp rồi về S1.
    // Kết quả mới (vd lockout, đang xóa) thêm thành lớp con của
    // [BootstrapResult].
    try {
      final type = await FileSystemEntity.type(
        _paths.headerFile,
        followLinks: false,
      );
      return type == FileSystemEntityType.notFound
          ? const BootstrapNoAccount()
          : const BootstrapHasAccount();
    } on Object {
      return const BootstrapUnavailable();
    }
  }

  /// Tạo tài khoản với mật khẩu chính [password] (đã qua `PasswordPolicy`,
  /// AD-7):
  ///
  /// `ascii.encode` → salt 16 byte → hiệu chỉnh KDF (KEK của lần chạy cuối
  /// dùng thẳng) → DEK 32 byte → header → xóa `vault/` cũ → tạo `vault/` →
  /// fsync `pak/` → ghi `cards` rỗng → ghi `recent` rỗng → ghi `header`
  /// **cuối cùng** (điểm commit).
  ///
  /// Lỗi ở bất kỳ bước nào → [CreateFailure], không để lại `header`. Có
  /// `header` sẵn (tài khoản đã commit) thì từ chối, không xóa gì. Bản
  /// `Uint8List` của mật khẩu luôn bị wipe; KEK luôn bị hủy; DEK bị hủy trừ
  /// khi đã chuyển cho [VaultSession].
  Future<CreateResult> create(String password) async {
    if (_creating) {
      return const CreateFailure();
    }
    _creating = true;
    Uint8List? pw;
    SecureKey? kek;
    SecureKey? dek;
    try {
      pw = ascii.encode(password);
      final salt = _random.bytes(kdfSaltBytes);
      if (salt.length != kdfSaltBytes) {
        return const CreateFailure();
      }
      final calibrated = await calibrateVaultKdf(
        password: pw,
        salt: salt,
        derive: _deriveKek,
        nowMs: _nowMs,
      );
      if (calibrated == null) {
        return const CreateFailure();
      }
      kek = calibrated.kek;
      dek = _newDek();

      final header = HeaderCodec(_sodium).create(
        kek: kek,
        dek: dek,
        salt: salt,
        params: calibrated.params,
        random: _random,
      );
      if (header == null) {
        return const CreateFailure();
      }
      final headerBytes = HeaderCodec(_sodium).encode(header);
      final files = VaultFileCodec(_sodium, _random);
      final cards = files.encodeCards(const [], dek);
      final recent = files.encodeRecent(const [], dek);
      if (cards == null || recent == null) {
        return const CreateFailure();
      }

      if (!await _prepareVaultDir()) {
        return const CreateFailure();
      }
      if (await _writer.write(_paths.cardsFile, cards) is! AtomicWriteSuccess ||
          await _writer.write(_paths.recentFile, recent)
              is! AtomicWriteSuccess) {
        return const CreateFailure();
      }
      if (await _writer.write(_paths.headerFile, headerBytes)
          is! AtomicWriteSuccess) {
        // Lỗi sau rename (fsync thư mục) để lại `header` mới mà độ bền chưa
        // chắc: xóa để kết quả khớp với [CreateFailure], rồi fsync `vault/`
        // để lần xóa cũng bền (best-effort).
        await _deleteQuietly(_paths.headerFile);
        try {
          await _fileSync.fsyncDirectory(_paths.vaultDir);
        } on Object {
          // Lần tạo sau dọn cả `vault/`.
        }
        return const CreateFailure();
      }

      final session = VaultSession(dek: dek, cards: const [], recent: const []);
      dek = null; // Đã chuyển quyền sở hữu cho phiên.
      return CreateSuccess(session);
    } on Object {
      return const CreateFailure();
    } finally {
      if (pw != null) {
        wipe(pw);
      }
      _disposeQuietly(kek);
      _disposeQuietly(dek);
      _creating = false;
    }
  }

  /// Mở khóa bằng mật khẩu chính [password] (AD-5):
  ///
  /// đọc `header` → `HeaderCodec.decode` (hỏng → [UnlockCorrupt], không chạy
  /// KDF) → `ascii.encode` → KDF → so `kcv` (lệch → [UnlockWrongPassword]) →
  /// mở bọc DEK → giải mã `cards`/`recent`. Mọi lỗi khác → [UnlockCorrupt].
  ///
  /// Không ghi, không xóa file nào. Bản `Uint8List` của mật khẩu luôn bị
  /// wipe; KEK luôn bị hủy; DEK bị hủy trừ khi đã chuyển cho [VaultSession].
  /// Gọi chồng khi lần trước chưa xong thì nhận kết quả của lần đang chạy.
  Future<UnlockResult> unlock(String password) {
    final running = _unlocking;
    if (running != null) {
      return running;
    }
    final future = _unlock(password);
    _unlocking = future;
    return future.whenComplete(() => _unlocking = null);
  }

  Future<UnlockResult> _unlock(String password) async {
    Uint8List? pw;
    SecureKey? kek;
    SecureKey? dek;
    try {
      final headerBytes = await File(_paths.headerFile).readAsBytes();
      final codec = HeaderCodec(_sodium);
      final header = switch (codec.decode(headerBytes)) {
        HeaderOk(:final header) => header,
        HeaderCorrupt() => null,
      };
      if (header == null) {
        return const UnlockCorrupt();
      }
      pw = ascii.encode(password);
      // Epic 2: LockoutGuard ghi lần thử vào `guard` TRƯỚC KDF (tắt app giữa
      // chừng vẫn tính); đang khóa tạm thì trả `lockedOut`, không chạy KDF.
      kek = await _deriveKek(pw, header.salt, header.kdf);
      if (kek == null) {
        return const UnlockCorrupt();
      }
      if (!codec.kcvMatches(header, kek)) {
        return const UnlockWrongPassword();
      }
      // Epic 2: `kcv` khớp → LockoutGuard reset bộ đếm.
      dek = codec.unwrapDek(header, kek);
      if (dek == null) {
        return const UnlockCorrupt();
      }
      final files = VaultFileCodec(_sodium, _random);
      final cards = files.decodeCards(
        await File(_paths.cardsFile).readAsBytes(),
        dek,
      );
      final recent = files.decodeRecent(
        await File(_paths.recentFile).readAsBytes(),
        dek,
      );
      if (cards is! VaultFileOk<List<VaultCard>> ||
          recent is! VaultFileOk<List<RecentEntry>>) {
        return const UnlockCorrupt();
      }
      final session = VaultSession(
        dek: dek,
        cards: cards.value,
        recent: recent.value,
      );
      dek = null; // Đã chuyển quyền sở hữu cho phiên.
      return UnlockSuccess(session);
    } on Object {
      return const UnlockCorrupt();
    } finally {
      if (pw != null) {
        wipe(pw);
      }
      _disposeQuietly(kek);
      _disposeQuietly(dek);
    }
  }

  /// DEK 32 byte từ [RandomSource], chép vào `SecureKey`; bản tạm trên heap
  /// Dart bị ghi đè 0 ngay sau đó.
  SecureKey _newDek() {
    final raw = _random.bytes(dekBytes);
    try {
      if (raw.length != dekBytes) {
        throw StateError('DEK sai độ dài');
      }
      return _sodium.secureCopy(raw);
    } finally {
      wipe(raw);
    }
  }

  /// Xóa `vault/` cũ nếu có (không theo symlink), tạo lại thư mục rỗng rồi
  /// fsync `pak/`. Từ chối (`false`) khi đã có `header`. `pak/` do
  /// `StorageBootstrap` tạo; ở đây không tạo thư mục cha.
  Future<bool> _prepareVaultDir() async {
    final headerType = await FileSystemEntity.type(
      _paths.headerFile,
      followLinks: false,
    );
    if (headerType != FileSystemEntityType.notFound) {
      return false;
    }
    final vault = _paths.vaultDir;
    switch (await FileSystemEntity.type(vault, followLinks: false)) {
      case FileSystemEntityType.directory:
        await Directory(vault).delete(recursive: true);
      case FileSystemEntityType.link:
        await Link(vault).delete();
      case FileSystemEntityType.notFound:
        break;
      default:
        await File(vault).delete();
    }
    await Directory(vault).create();
    await _fileSync.fsyncDirectory(_paths.pakDir);
    return true;
  }
}

Future<void> _deleteQuietly(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } on Object {
    // Lần tạo sau dọn cả `vault/`.
  }
}

void _disposeQuietly(SecureKey? key) {
  try {
    key?.dispose();
  } on Object {
    // Khóa đã hủy.
  }
}
