import 'dart:async';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import 'wipe.dart';

/// 1 MiB tính bằng byte.
const int mib = 1024 * 1024;

/// Độ dài KEK (byte) do Argon2id sinh ra.
const int kekBytes = 32;

/// Độ dài salt Argon2id (byte), bằng `crypto_pwhash_SALTBYTES`.
const int kdfSaltBytes = 16;

/// Tham số Argon2id13 lưu trong header (AD-4, AD-20). Bất biến.
final class KdfParams {
  const KdfParams(this.opsLimit, this.memLimitBytes);

  /// Khoảng cho phép (AD-4). Header có tham số ngoài khoảng là `corrupt`.
  static const int opsMin = 2;
  static const int opsMax = 10;
  static const int memMinBytes = 19 * mib;
  static const int memMaxBytes = 128 * mib;

  /// Điểm khởi đầu hiệu chỉnh (t=3, m=64 MiB).
  static const KdfParams start = KdfParams(3, 64 * mib);

  /// Sàn hiệu chỉnh (t=2, m=19 MiB).
  static const KdfParams floor = KdfParams(opsMin, memMinBytes);

  /// `opslimit` của Argon2id (số lượt).
  final int opsLimit;

  /// `memlimit` của Argon2id, tính bằng byte.
  final int memLimitBytes;

  /// `true` khi cả hai tham số nằm trong khoảng cho phép.
  bool get isAllowed =>
      opsLimit >= opsMin &&
      opsLimit <= opsMax &&
      memLimitBytes >= memMinBytes &&
      memLimitBytes <= memMaxBytes;

  @override
  bool operator ==(Object other) =>
      other is KdfParams &&
      other.opsLimit == opsLimit &&
      other.memLimitBytes == memLimitBytes;

  @override
  int get hashCode => Object.hash(opsLimit, memLimitBytes);

  @override
  String toString() =>
      'KdfParams(ops: $opsLimit, mem: ${memLimitBytes / mib} MiB)';
}

/// KEK = Argon2id13(password, salt, params), 32 byte, p=1 (AD-4).
///
/// Chạy trong isolate phụ qua `Sodium.runIsolated` để không chặn UI. Trả
/// `null` (không chạy KDF) khi [params] ngoài khoảng hoặc [salt] không đủ
/// 16 byte; trả `null` khi KDF lỗi. Không bao giờ ném.
///
/// [password] là bản mã hóa ASCII của mật khẩu chính; caller tự wipe bản
/// của mình, còn bản sao gửi sang isolate được wipe ở đó.
///
/// [debugInIsolate] chỉ dành cho test: chạy trong isolate KDF, trước KDF.
Future<SecureKey?> deriveKek(
  SodiumSumo sodium,
  Uint8List password,
  Uint8List salt,
  KdfParams params, {
  void Function()? debugInIsolate,
}) async {
  if (!params.isAllowed || salt.length != kdfSaltBytes) {
    return null;
  }
  final SecureKey kek;
  try {
    // Không sao chép [password] trên isolate này: closure được sao sang
    // isolate KDF, bản sao đó bị wipe trong callback.
    kek = await sodium.runIsolated(
      _kdfCallback(
        sodium,
        password,
        salt,
        params.opsLimit,
        params.memLimitBytes,
        debugInIsolate,
      ),
    );
  } on Object {
    return null;
  }
  if (kek.length != kekBytes) {
    // Khóa rỗng = callback đã bắt lỗi (xem [_kdfCallback]).
    kek.dispose();
    return null;
  }
  return kek;
}

/// Tách riêng để closure gửi sang isolate chỉ mang các giá trị cần thiết.
///
/// `runIsolated` chỉ trả được khóa khi kiểu kết quả đúng là `SecureKey`
/// (không nhận `SecureKey?`), nên lỗi được báo bằng một khóa rỗng thay cho
/// `null`.
SodiumIsolateCallback<SecureKey> _kdfCallback(
  SodiumSumo sodium,
  Uint8List password,
  Uint8List salt,
  int opsLimit,
  int memLimit,
  void Function()? debugInIsolate,
) =>
    (_, _) => runZoned(() {
      // Isolate phụ không thừa hưởng chính sách lỗi release của isolate chính
      // (AD-18): nuốt `print` bằng zone và bắt mọi lỗi tại đây.
      try {
        debugInIsolate?.call();
        return sodium.crypto.pwhash.callRaw(
          outLen: kekBytes,
          password: password.buffer.asInt8List(
            password.offsetInBytes,
            password.length,
          ),
          salt: salt,
          opsLimit: opsLimit,
          memLimit: memLimit,
          alg: CryptoPwhashAlgorithm.argon2id13,
        );
      } on Object {
        return sodium.secureAlloc(0);
      } finally {
        wipe(password);
      }
    }, zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}));
