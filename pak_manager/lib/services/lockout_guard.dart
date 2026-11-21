import 'dart:io';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import '../core/format/guard_codec.dart';
import '../core/guard/guard_state.dart';
import '../core/io/atomic_file_writer.dart';
import '../core/ports/clock_port.dart';

/// Chủ duy nhất của file `guard` (AD-8): bộ đếm lần nhập sai bền vững và mốc
/// chờ 30 phút.
///
/// Phạm vi **app**, sống lâu hơn phiên. Bản trong RAM ([state]) là nguồn số
/// lần thử còn lại và thời gian chờ; nó chỉ đổi sau khi ghi đĩa thành công,
/// trừ [recordSuccess], [normalize] và lần neo lại mốc trong [waitRemaining]
/// (ghi lỗi vẫn đổi RAM, xem từng method).
///
/// Mọi phép đo thời gian dùng `ClockPort.monotonicMs` kết hợp
/// `ClockPort.bootId` (AD-9), không dùng đồng hồ tường.
///
/// Chuỗi sai ngay trước chỉ giữ trong RAM dưới dạng digest BLAKE2b 16 byte,
/// khóa ngẫu nhiên 32 byte sinh khi dựng service và không bao giờ rời RAM
/// (AD-22). Không ghi mật khẩu hay digest xuống đĩa, không ghi Keychain/
/// Keystore.
///
/// Không method nào ném. Các method bất đồng bộ chạy tuần tự theo thứ tự
/// gọi (hàng đợi nội bộ): UI hỏi [waitRemaining] trong lúc `unlock` đang ghi
/// thì hai lần đọc-sửa-ghi không xen nhau.
final class LockoutGuard {
  LockoutGuard({
    required SodiumSumo sodium,
    required this._writer,
    required this._path,
    required this._clock,
  }) : _sodium = sodium,
       _digestKey = sodium.crypto.genericHash.keygen();

  /// File lớn hơn mức này bị coi là không đọc được.
  static const maxFileBytes = 4 * 1024;

  /// Độ dài digest của chuỗi sai ngay trước.
  static const digestBytes = 16;

  final SodiumSumo _sodium;
  final AtomicFileWriter _writer;
  final String _path;
  final ClockPort _clock;
  final SecureKey _digestKey;

  GuardState _state = GuardState.initial;
  Uint8List? _lastWrong;

  /// Đuôi hàng đợi của các method bất đồng bộ (xem [_serial]).
  Future<void> _tail = Future<void>.value();

  /// Trạng thái hiện hành trong RAM.
  GuardState get state => _state;

  /// Nạp `guard` lúc khởi động (`AccountService.bootstrap`).
  ///
  /// - [hasAccount] `false` (không có `header`): chỉ đọc, không ghi, không
  ///   đọc đồng hồ. File thiếu hoặc không đọc được thì RAM là
  ///   [GuardState.initial].
  /// - [hasAccount] `true`: file thiếu hoặc không đọc được → ghi lại
  ///   [GuardState.initial]; ghi lỗi thì RAM vẫn là [GuardState.initial].
  ///   File đọc được mà `failCount` 5–9 với mốc chờ thiếu, nửa vời, khác
  ///   `bootId` hiện tại hoặc lớn hơn `monotonicMs` hiện tại → neo mốc =
  ///   bây giờ (`GuardState.reanchored`, AD-8 bước (2) rồi (3)) và ghi xuống
  ///   đĩa trước khi trả; ghi lỗi thì RAM vẫn mang mốc mới (chỉ kéo dài thời
  ///   gian chờ). Đọc đồng hồ lỗi thì giữ nguyên mốc; [waitRemaining] neo
  ///   lại sau.
  ///
  /// Story 2.3 thêm nhánh xóa dở dang.
  Future<void> normalize({required bool hasAccount}) => _serial(() async {
    final bytes = await _readCapped(_path);
    final decoded = bytes == null
        ? const GuardUnreadable()
        : GuardCodec.decode(bytes);
    switch (decoded) {
      case GuardOk(:final state):
        _state = state;
        if (hasAccount && state.inWaitRange) {
          await _reanchorIfNeeded();
        }
      case GuardUnreadable():
        _state = GuardState.initial;
        if (hasAccount) {
          await _write(GuardState.initial);
        }
    }
  });

  /// Thời gian chờ còn lại (FR-4, FR-6), luôn trong `[0, waitDuration]`.
  ///
  /// - `failCount` ngoài 5–9 → `Duration.zero`, không đọc đồng hồ.
  /// - Đọc đồng hồ lỗi → [waitDuration] (fail closed).
  /// - Mốc cần neo lại (khởi động lại máy, đồng hồ đơn điệu lùi, mốc thiếu)
  ///   → RAM nhận mốc mới, ghi xuống đĩa (bỏ qua lỗi), rồi mới tính.
  Future<Duration> waitRemaining() => _serial(() async {
    if (!_state.inWaitRange) {
      return Duration.zero;
    }
    final now = await _reanchorIfNeeded();
    if (now == null) {
      return waitDuration;
    }
    return _state.waitRemaining(now.mono);
  });

  /// [password] trùng chuỗi sai ngay trước (so digest hằng thời gian).
  bool isRepeatOfLastWrong(Uint8List password) {
    final last = _lastWrong;
    if (last == null) {
      return false;
    }
    final digest = _digest(password);
    if (digest == null) {
      return false;
    }
    try {
      return _sodium.memcmp(digest, last);
    } on Object {
      return false;
    }
  }

  /// Nhớ digest của [password] vừa sai (`kcv` lệch).
  void rememberWrong(Uint8List password) => _lastWrong = _digest(password);

  /// Ghi trước KDF: `failCount + 1` (chặn ở [maxAttempts]); nếu giá trị mới
  /// nằm trong 5–9 thì **cùng lần ghi đó** đặt mốc chờ = `(bootId,
  /// monotonicMs)` hiện tại (AD-8). `failCount` mới 1–4 hoặc 10 thì không đọc
  /// đồng hồ.
  ///
  /// `true` khi đã ghi xuống đĩa và RAM đã cập nhật; `false` (đọc đồng hồ
  /// lỗi hoặc ghi lỗi) thì RAM giữ nguyên và người gọi không được chạy KDF.
  Future<bool> recordAttempt() => _serial(() async {
    var next = _state.afterAttempt();
    if (next.inWaitRange) {
      final now = await _now();
      if (now == null) {
        return false;
      }
      next = next.withWaitMark(now.boot, now.mono);
    }
    if (!await _write(next)) {
      return false;
    }
    _state = next;
    return true;
  });

  /// Mật khẩu đúng: bỏ digest ngay; `failCount = 0` và xóa mốc chờ trong RAM
  /// khi tới lượt trong hàng đợi, rồi ghi xuống đĩa. Ghi lỗi thì bỏ qua (RAM
  /// vẫn đổi), lần ghi trước KDF kế tiếp ghi lại trạng thái đúng.
  Future<void> recordSuccess() {
    _lastWrong = null;
    return _serial(() async {
      _state = _state.afterSuccess();
      await _write(_state);
    });
  }

  /// Đọc đồng hồ rồi neo lại mốc chờ của RAM nếu cần (ghi xuống đĩa, bỏ qua
  /// lỗi; RAM vẫn mang mốc mới). Trả thời điểm vừa đọc, hoặc `null` khi đọc
  /// đồng hồ lỗi (không đổi gì).
  Future<({String boot, int mono})?> _reanchorIfNeeded() async {
    final now = await _now();
    if (now == null) {
      return null;
    }
    final next = _state.reanchored(now.boot, now.mono);
    if (next != null) {
      _state = next;
      await _write(next);
    }
    return now;
  }

  /// `(bootId, monotonicMs)` hiện tại, hoặc `null` khi đọc lỗi.
  Future<({String boot, int mono})?> _now() async {
    try {
      final boot = await _clock.bootId();
      final mono = await _clock.monotonicMs();
      return (boot: boot, mono: mono);
    } on Object {
      return null;
    }
  }

  /// Chạy [op] sau khi mọi lời gọi trước đó xong. [op] không ném; hàng đợi
  /// vẫn chạy tiếp nếu có lỗi lọt ra.
  Future<T> _serial<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Uint8List? _digest(Uint8List password) {
    try {
      return _sodium.crypto.genericHash(
        message: password,
        outLen: digestBytes,
        key: _digestKey,
      );
    } on Object {
      return null;
    }
  }

  Future<bool> _write(GuardState state) async {
    try {
      return await _writer.write(_path, GuardCodec.encode(state))
          is AtomicWriteSuccess;
    } on Object {
      return false;
    }
  }
}

/// Bytes của file, hoặc `null` khi không có file, không phải file thường,
/// lớn hơn [LockoutGuard.maxFileBytes] hay đọc lỗi.
Future<List<int>?> _readCapped(String path) async {
  try {
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.file) {
      return null;
    }
    final raf = await File(path).open();
    try {
      // Đọc dư một byte để phát hiện file vượt ngưỡng.
      final bytes = await raf.read(LockoutGuard.maxFileBytes + 1);
      return bytes.length > LockoutGuard.maxFileBytes ? null : bytes;
    } finally {
      await raf.close();
    }
  } on Object {
    return null;
  }
}
