import 'blocklist_filter.dart';

/// Kết quả kiểm tra mật khẩu chính/mật khẩu export (FR-2, FR-52, AD-15).
///
/// Không kết quả nào giữ chuỗi mật khẩu; [PasswordTooShort] chỉ mang độ dài.
sealed class PasswordCheck {
  const PasswordCheck();
}

/// Mật khẩu đạt mọi luật.
final class PasswordOk extends PasswordCheck {
  const PasswordOk();
}

/// Có ký tự ngoài ASCII in được (0x20–0x7E).
final class PasswordNonAscii extends PasswordCheck {
  const PasswordNonAscii();
}

/// Ngắn hơn [PasswordPolicy.minLength]; [length] là độ dài hiện tại.
final class PasswordTooShort extends PasswordCheck {
  const PasswordTooShort(this.length);

  final int length;
}

/// Dài hơn [PasswordPolicy.maxLength].
final class PasswordTooLong extends PasswordCheck {
  const PasswordTooLong();
}

/// Có trong blocklist mật khẩu phổ biến (so trên bản chữ thường).
final class PasswordCommon extends PasswordCheck {
  const PasswordCommon();
}

/// Cả chuỗi là một ký tự lặp lại hoặc một dãy tuần tự.
final class PasswordPattern extends PasswordCheck {
  const PasswordPattern();
}

/// Nơi duy nhất kiểm tra mật khẩu theo AD-15. Thứ tự lỗi: không ASCII → độ dài
/// → phổ biến → lặp/tuần tự. Không có luật thành phần (chữ hoa/số/ký hiệu).
/// Không ném exception.
final class PasswordPolicy {
  const PasswordPolicy(this._blocklist);

  /// Độ dài tối thiểu (ký tự ASCII).
  static const int minLength = 15;

  /// Độ dài tối đa (ký tự ASCII).
  static const int maxLength = 128;

  final BlocklistFilter _blocklist;

  /// Kiểm [password] theo thứ tự AD-15.
  PasswordCheck check(String password) {
    if (!_isPrintableAscii(password)) {
      return const PasswordNonAscii();
    }
    final length = password.length;
    if (length < minLength) {
      return PasswordTooShort(length);
    }
    if (length > maxLength) {
      return const PasswordTooLong();
    }
    final lower = _toLowerAscii(password);
    if (_blocklist.contains(lower)) {
      return const PasswordCommon();
    }
    if (_isRepeated(lower) || _isSequential(lower)) {
      return const PasswordPattern();
    }
    return const PasswordOk();
  }

  /// Cổng bật nút "Đăng nhập" (S3) và nút mở file import (S25): chỉ ASCII in
  /// được và dài ít nhất [minLength]. Chuỗi không qua cổng thì không bao giờ
  /// được gửi đi kiểm tra.
  static bool meetsLoginGate(String password) =>
      password.length >= minLength && _isPrintableAscii(password);

  /// `true` khi [password] chỉ có ASCII in được (0x20–0x7E). S3 dùng để
  /// hiện `pw.nonAscii` mà không chạy cả luật (không blocklist ở S3).
  static bool isPrintableAscii(String password) => _isPrintableAscii(password);
}

bool _isPrintableAscii(String s) {
  for (final c in s.codeUnits) {
    if (c < 0x20 || c > 0x7E) {
      return false;
    }
  }
  return true;
}

/// Chuyển `A`–`Z` sang chữ thường; giả định [s] là ASCII.
String _toLowerAscii(String s) {
  final units = s.codeUnits;
  return String.fromCharCodes([
    for (final c in units) (c >= 0x41 && c <= 0x5A) ? c + 0x20 : c,
  ]);
}

/// Cả chuỗi (đã chữ thường) là một ký tự lặp lại.
bool _isRepeated(String lower) {
  final units = lower.codeUnits;
  for (var i = 1; i < units.length; i++) {
    if (units[i] != units[0]) {
      return false;
    }
  }
  return true;
}

/// Cả chuỗi (đã chữ thường) toàn chữ số hoặc toàn chữ cái, mỗi bước cùng +1
/// hoặc cùng −1, vòng quanh (`9→0`, `z→a`).
bool _isSequential(String lower) {
  final units = lower.codeUnits;
  if (units.length < 2) {
    return false;
  }
  final int base;
  final int size;
  if (_allInRange(units, 0x30, 0x39)) {
    base = 0x30;
    size = 10;
  } else if (_allInRange(units, 0x61, 0x7A)) {
    base = 0x61;
    size = 26;
  } else {
    return false;
  }
  bool stepsBy(int step) {
    for (var i = 1; i < units.length; i++) {
      final prev = units[i - 1] - base;
      if (units[i] - base != (prev + step) % size) {
        return false;
      }
    }
    return true;
  }

  return stepsBy(1) || stepsBy(size - 1);
}

bool _allInRange(List<int> units, int lo, int hi) {
  for (final c in units) {
    if (c < lo || c > hi) {
      return false;
    }
  }
  return true;
}
