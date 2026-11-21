import 'dart:io';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import '../core/format/guard_codec.dart';
import '../core/guard/guard_state.dart';
import '../core/io/atomic_file_writer.dart';

/// Chủ duy nhất của file `guard` (AD-8): bộ đếm lần nhập sai bền vững.
///
/// Phạm vi **app**, sống lâu hơn phiên. Bản trong RAM ([state]) là nguồn số
/// lần thử còn lại; nó chỉ đổi sau khi ghi đĩa thành công, trừ
/// [recordSuccess] và [normalize] (ghi lỗi vẫn đổi RAM, xem từng method).
///
/// Chuỗi sai ngay trước chỉ giữ trong RAM dưới dạng digest BLAKE2b 16 byte,
/// khóa ngẫu nhiên 32 byte sinh khi dựng service và không bao giờ rời RAM
/// (AD-22). Không ghi mật khẩu hay digest xuống đĩa, không ghi Keychain/
/// Keystore.
///
/// Không method nào ném. Không an toàn khi gọi chồng: `AccountService` chỉ
/// cho một lần kiểm tra mỗi lúc, nên các lần ghi luôn tuần tự.
final class LockoutGuard {
  LockoutGuard({
    required SodiumSumo sodium,
    required this._writer,
    required this._path,
  }) : _sodium = sodium,
       _digestKey = sodium.crypto.genericHash.keygen();

  /// File lớn hơn mức này bị coi là không đọc được.
  static const maxFileBytes = 4 * 1024;

  /// Độ dài digest của chuỗi sai ngay trước.
  static const digestBytes = 16;

  final SodiumSumo _sodium;
  final AtomicFileWriter _writer;
  final String _path;
  final SecureKey _digestKey;

  GuardState _state = GuardState.initial;
  Uint8List? _lastWrong;

  /// Trạng thái hiện hành trong RAM.
  GuardState get state => _state;

  /// Nạp `guard` lúc khởi động (`AccountService.bootstrap`).
  ///
  /// - [hasAccount] `false` (không có `header`): chỉ đọc, không ghi. File
  ///   thiếu hoặc không đọc được thì RAM là [GuardState.initial].
  /// - [hasAccount] `true`: file thiếu hoặc không đọc được → ghi lại
  ///   [GuardState.initial]; ghi lỗi thì RAM vẫn là [GuardState.initial].
  ///
  /// Story 2.2 thêm bước đặt lại mốc chờ theo `bootId`/monotonic, 2.3 thêm
  /// nhánh xóa dở dang.
  Future<void> normalize({required bool hasAccount}) async {
    final bytes = await _readCapped(_path);
    final decoded = bytes == null
        ? const GuardUnreadable()
        : GuardCodec.decode(bytes);
    switch (decoded) {
      case GuardOk(:final state):
        _state = state;
      case GuardUnreadable():
        _state = GuardState.initial;
        if (hasAccount) {
          await _write(GuardState.initial);
        }
    }
  }

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

  /// Ghi trước KDF: `failCount + 1` (chặn ở [maxAttempts]). `true` khi đã ghi
  /// xuống đĩa và RAM đã cập nhật; `false` thì RAM giữ nguyên và người gọi
  /// không được chạy KDF.
  Future<bool> recordAttempt() async {
    final next = _state.afterAttempt();
    if (!await _write(next)) {
      return false;
    }
    _state = next;
    return true;
  }

  /// Mật khẩu đúng: bỏ digest, `failCount = 0`, xóa mốc chờ. RAM đổi ngay;
  /// ghi đĩa lỗi thì bỏ qua, lần ghi trước KDF kế tiếp ghi lại trạng thái
  /// đúng.
  Future<void> recordSuccess() async {
    _lastWrong = null;
    _state = _state.afterSuccess();
    await _write(_state);
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
