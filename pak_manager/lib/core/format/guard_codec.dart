import 'dart:convert';

import '../guard/guard_state.dart';

/// Kết quả [GuardCodec.decode].
sealed class GuardDecodeResult {
  const GuardDecodeResult();
}

/// File đọc được, mọi trường hợp lệ.
final class GuardOk extends GuardDecodeResult {
  const GuardOk(this.state);

  final GuardState state;

  @override
  String toString() => 'GuardOk($state)';
}

/// File không đọc được: không phải UTF-8/JSON, không phải object, `v` ≠ 1,
/// thiếu key hoặc có trường sai kiểu/ngoài miền. Không bao giờ là `corrupt`:
/// `LockoutGuard` tạo lại file theo AD-8.
final class GuardUnreadable extends GuardDecodeResult {
  const GuardUnreadable();

  @override
  String toString() => 'GuardUnreadable()';
}

/// Codec duy nhất của file `guard` (AD-20). Dạng v1:
///
/// ```json
/// {"v":1,"failCount":0–10,"waitBootId":str|null,"waitStartMono":int≥0|null,
///  "wiping":bool}
/// ```
///
/// Khác `settings`, một trường sai là cả file không đọc được
/// ([GuardUnreadable]). Key lạ bị bỏ qua.
abstract final class GuardCodec {
  static const int version = 1;

  /// Không bao giờ ném.
  static GuardDecodeResult decode(List<int> bytes) {
    final Object? root;
    try {
      root = jsonDecode(utf8.decode(bytes));
    } on Object {
      return const GuardUnreadable();
    }
    if (root is! Map<String, Object?>) {
      return const GuardUnreadable();
    }
    const keys = ['v', 'failCount', 'waitBootId', 'waitStartMono', 'wiping'];
    if (!keys.every(root.containsKey)) {
      return const GuardUnreadable();
    }
    final v = root['v'];
    if (v is! int || v != version) {
      return const GuardUnreadable();
    }
    final failCount = root['failCount'];
    if (failCount is! int || failCount < 0 || failCount > maxAttempts) {
      return const GuardUnreadable();
    }
    final waitBootId = root['waitBootId'];
    if (waitBootId != null && waitBootId is! String) {
      return const GuardUnreadable();
    }
    final waitStartMono = root['waitStartMono'];
    if (waitStartMono != null && (waitStartMono is! int || waitStartMono < 0)) {
      return const GuardUnreadable();
    }
    final wiping = root['wiping'];
    if (wiping is! bool) {
      return const GuardUnreadable();
    }
    return GuardOk(
      GuardState(
        failCount: failCount,
        waitBootId: waitBootId as String?,
        waitStartMono: waitStartMono as int?,
        wiping: wiping,
      ),
    );
  }

  /// JSON UTF-8, không khoảng trắng, thứ tự key như AD-20.
  static List<int> encode(GuardState state) => utf8.encode(
    jsonEncode(<String, Object?>{
      'v': version,
      'failCount': state.failCount,
      'waitBootId': state.waitBootId,
      'waitStartMono': state.waitStartMono,
      'wiping': state.wiping,
    }),
  );
}
