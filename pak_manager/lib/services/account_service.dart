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
import 'lockout_guard.dart';
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
final class UnlockCorrupt extends UnlockResult {
  const UnlockCorrupt();

  @override
  String toString() => 'UnlockCorrupt()';
}

/// Không được thử lúc này (AD-8): đang trong thời gian chờ 30 phút sau lần
/// sai thứ 5–9 (đếm ngược lấy từ [AccountService.lockoutRemaining]), hoặc
/// đã hết lượt (`failCount` = 10). Không ghi lần thử, không chạy KDF (có thể
/// ghi mốc chờ vừa neo lại, AD-8).
final class UnlockLockedOut extends UnlockResult {
  const UnlockLockedOut();

  @override
  String toString() => 'UnlockLockedOut()';
}

/// Không ghi được lần thử xuống `guard` trước KDF (AD-8): lần thử bị hủy,
/// không chạy KDF, số lần thử còn lại không đổi (`create.unavailable`).
final class UnlockUnavailable extends UnlockResult {
  const UnlockUnavailable();

  @override
  String toString() => 'UnlockUnavailable()';
}

/// Một lần [AccountService.unlock] khác đang chạy: lần gọi này không làm gì
/// (không ghi `guard`, không chạy KDF).
final class UnlockBusy extends UnlockResult {
  const UnlockBusy();

  @override
  String toString() => 'UnlockBusy()';
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
    required this._guard,
    KekDeriver? deriveKek,
    this._nowMs,
  }) : _sodium = sodium,
       _deriveKek = deriveKek ?? kekDeriver(sodium);

  final SodiumSumo _sodium;
  final RandomSource _random;
  final AtomicFileWriter _writer;
  final FileSyncPort _fileSync;
  final PakPaths _paths;
  final LockoutGuard _guard;
  final KekDeriver _deriveKek;

  /// Đồng hồ của hiệu chỉnh KDF; `null` = `Stopwatch` mặc định.
  final int Function()? _nowMs;

  bool _creating = false;

  /// Có một lần [unlock] đang chạy; gọi chồng thì trả [UnlockBusy].
  bool _unlocking = false;

  /// Số lần thử còn lại trước khi bị chặn (FR-4), đọc từ RAM của
  /// [LockoutGuard]. Nguồn số {N} của `login.attempts`.
  int get attemptsLeft => _guard.state.attemptsLeft;

  /// Thời gian chờ còn lại trước khi được thử tiếp (FR-4, FR-6), trong
  /// `[0, 30 phút]`; `Duration.zero` = không phải chờ. Nguồn duy nhất của
  /// đếm ngược `login.lockout`. Đo bằng đồng hồ đơn điệu và `bootId` (AD-9);
  /// đọc đồng hồ lỗi thì trả đủ 30 phút (fail closed). Không ném.
  Future<Duration> lockoutRemaining() => _guard.waitRemaining();

  /// Trạng thái tài khoản lúc khởi động, chạy trước `runApp` (không có màn
  /// chờ, UX-DR30): kiểm `vault/header` có tồn tại hay không rồi nạp `guard`
  /// (`LockoutGuard.normalize`). Không đọc vault, không xóa gì; chỉ ghi
  /// `guard` khi có `header` mà `guard` thiếu hoặc không đọc được (AD-8).
  ///
  /// Thiếu `header` nghĩa là chưa có tài khoản đã commit (AD-7), kể cả khi
  /// `vault/` còn `cards`/`recent` từ lần tạo bị tắt giữa chừng: phần đó được
  /// [create] dọn.
  Future<BootstrapResult> bootstrap() async {
    // Story 2.3 chèn `WipeCoordinator.resumeIfNeeded()` trước bước này
    // (AD-26); kết quả mới (vd đang xóa) thêm thành lớp con của
    // [BootstrapResult].
    final bool hasAccount;
    try {
      final type = await FileSystemEntity.type(
        _paths.headerFile,
        followLinks: false,
      );
      hasAccount = type != FileSystemEntityType.notFound;
    } on Object {
      return const BootstrapUnavailable();
    }
    await _guard.normalize(hasAccount: hasAccount);
    return hasAccount
        ? const BootstrapHasAccount()
        : const BootstrapNoAccount();
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

  /// Mở khóa bằng mật khẩu chính [password] (AD-4, AD-5, AD-8):
  ///
  /// đọc `header` → `HeaderCodec.decode` (hỏng → [UnlockCorrupt], không chạm
  /// `guard`, không chạy KDF) → `ascii.encode` → trùng chuỗi sai ngay trước
  /// → [UnlockWrongPassword] (không đếm, không KDF) → hết lượt hoặc đang chờ
  /// ([lockoutRemaining] > 0) → [UnlockLockedOut] (không ghi lần thử, không
  /// KDF; có thể ghi mốc chờ vừa neo lại) →
  /// ghi `failCount + 1` (cùng mốc chờ khi giá trị mới là 5–9) xuống `guard`
  /// (ghi hoặc đọc đồng hồ lỗi → [UnlockUnavailable], không KDF) → KDF → so
  /// `kcv` (lệch → nhớ digest, [UnlockWrongPassword]) → khớp:
  /// `recordSuccess()` → mở bọc DEK → giải mã `cards`/`recent`. Mọi lỗi khác
  /// → [UnlockCorrupt]; KDF lỗi sau khi đã ghi trước thì lần thử vẫn tính
  /// (story 2.5 tách riêng).
  ///
  /// Chỉ ghi `guard`, không ghi hay xóa file vault nào. Bản `Uint8List` của
  /// mật khẩu luôn bị wipe; KEK luôn bị hủy; DEK bị hủy trừ khi đã chuyển cho
  /// [VaultSession]. Gọi chồng khi lần trước chưa xong thì trả [UnlockBusy]
  /// ngay: chỉ người gọi đầu nhận phiên.
  Future<UnlockResult> unlock(String password) async {
    // Kiểm và đặt cờ trước `await` đầu tiên: lần gọi chồng luôn thấy cờ.
    if (_unlocking) {
      return const UnlockBusy();
    }
    _unlocking = true;
    try {
      return await _unlock(password);
    } finally {
      _unlocking = false;
    }
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
      if (_guard.isRepeatOfLastWrong(pw)) {
        return const UnlockWrongPassword();
      }
      if (_guard.state.exhausted) {
        return const UnlockLockedOut();
      }
      // Đang chờ sau lần sai thứ 5–9 (FR-4): từ chối trước khi đếm.
      if (await _guard.waitRemaining() > Duration.zero) {
        return const UnlockLockedOut();
      }
      // Ghi trước KDF: tắt app giữa chừng thì lần thử vẫn tính (FR-5).
      if (!await _guard.recordAttempt()) {
        return const UnlockUnavailable();
      }
      kek = await _deriveKek(pw, header.salt, header.kdf);
      if (kek == null) {
        return const UnlockCorrupt();
      }
      if (!codec.kcvMatches(header, kek)) {
        _guard.rememberWrong(pw);
        return const UnlockWrongPassword();
      }
      // Mật khẩu đúng: đặt lại bộ đếm trước mọi bước sau, kể cả khi dữ liệu
      // hỏng (AD-4).
      await _guard.recordSuccess();
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
