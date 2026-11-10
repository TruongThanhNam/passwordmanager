// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appName => 'PAK Manager';

  @override
  String get tabCards => 'Quản lý mật khẩu';

  @override
  String get tabGenerator => 'Tạo mật khẩu';

  @override
  String get generatorTitle => 'Tạo mật khẩu';

  @override
  String get tabSettings => 'Cài đặt';

  @override
  String get loginCreate => 'Tạo tài khoản';

  @override
  String get loginSubmit => 'Đăng nhập';

  @override
  String get loginWrong => 'Sai mật khẩu.';

  @override
  String get loginCorrupt =>
      'Dữ liệu bị hỏng — Mật khẩu đúng nhưng không đọc được dữ liệu. Bạn có thể dùng \"Xóa & Tạo tài khoản mới\" rồi import lại từ file export.';

  @override
  String get createWarning =>
      'Không có cách khôi phục mật khẩu chính. Nếu quên, bạn sẽ mất toàn bộ dữ liệu.';

  @override
  String get createFieldMain => 'Mật khẩu chính';

  @override
  String get createFieldConfirm => 'Nhập lại mật khẩu chính';

  @override
  String get pwNonAscii =>
      'Chỉ dùng chữ không dấu, số, ký hiệu và khoảng trắng. Chữ có dấu có thể bị bàn phím ghi khác đi và khiến bạn không đăng nhập được.';

  @override
  String pwStrength(String level) {
    return 'Độ mạnh: $level';
  }

  @override
  String get pwStrengthLow => 'Thấp';

  @override
  String get pwStrengthMedium => 'Trung bình';

  @override
  String get pwStrengthHigh => 'Cao';

  @override
  String pwTooShort(int n) {
    return 'Cần ít nhất 15 ký tự (hiện có $n).';
  }

  @override
  String get pwTooLong => 'Tối đa 128 ký tự.';

  @override
  String get pwCommon =>
      'Mật khẩu này quá phổ biến hoặc đã bị lộ. Hãy chọn mật khẩu khác.';

  @override
  String get pwPattern =>
      'Không dùng một ký tự lặp lại hoặc một dãy liên tiếp.';

  @override
  String get pwMismatch => 'Hai mật khẩu không khớp.';

  @override
  String get createUnavailable =>
      'Không mở được dữ liệu của app. Hãy khởi động lại app.';

  @override
  String get createFailed => 'Không tạo được tài khoản. Hãy thử lại.';

  @override
  String get pwReveal => 'Hiện mật khẩu';

  @override
  String get pwHide => 'Ẩn mật khẩu';
}
