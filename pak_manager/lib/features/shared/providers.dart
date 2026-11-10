import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/policy/password_policy.dart';
import '../../core/policy/strength_estimator.dart';
import '../../services/account_service.dart';

// Provider gốc của app (Riverpod viết tay, không codegen). `main.dart` nối
// giá trị thật bằng `overrideWithValue`. Giá trị mặc định là fail closed: khi
// không override, app coi như dữ liệu không dùng được.

/// Dịch vụ tài khoản; `null` khi lưu trữ hoặc Sodium không dùng được.
final accountServiceProvider = Provider<AccountService?>((ref) => null);

/// Luật mật khẩu chính; `null` khi `assets/blocklist.bloom` không đọc được
/// (không bao giờ âm thầm bỏ luật "phổ biến").
final passwordPolicyProvider = Provider<PasswordPolicy?>((ref) => null);

/// Ước lượng độ mạnh. `main.dart` dựng sớm để làm nóng từ điển `zxcvbnm`.
final strengthEstimatorProvider = Provider<StrengthEstimator>(
  (ref) => StrengthEstimator(),
);

/// Trạng thái tài khoản lúc khởi động, tính trước `runApp`.
final bootstrapResultProvider = Provider<BootstrapResult>(
  (ref) => const BootstrapUnavailable(),
);
