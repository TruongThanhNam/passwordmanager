import 'package:zxcvbnm/languages/en.dart' as en;
import 'package:zxcvbnm/matchers.dart' show BaseMatcher;
import 'package:zxcvbnm/options.dart';
import 'package:zxcvbnm/zxcvbnm.dart';

/// Mức độ mạnh hiển thị khi gõ mật khẩu chính (AD-15). Tách biệt với độ mạnh
/// theo entropy của generator (FR-34).
enum PasswordStrength { low, medium, high }

/// Ánh xạ điểm `zxcvbnm` sang [PasswordStrength]: 0–2 → low, 3 → medium,
/// 4 → high. Điểm ngoài khoảng được kẹp về biên gần nhất.
PasswordStrength strengthForScore(int score) {
  if (score >= 4) {
    return PasswordStrength.high;
  }
  if (score == 3) {
    return PasswordStrength.medium;
  }
  return PasswordStrength.low;
}

/// Đánh giá độ mạnh bằng `zxcvbnm` với từ điển `en` (đã gồm `common`).
///
/// Dùng lại một instance [Zxcvbnm]; từ điển xếp hạng được dựng một lần ở lần
/// gọi đầu rồi giữ trong cache (xem [_ReusableOptions]). Không giữ chuỗi mật
/// khẩu sau khi trả kết quả.
final class StrengthEstimator {
  StrengthEstimator() : _zxcvbnm = Zxcvbnm(options: _ReusableOptions());

  final Zxcvbnm _zxcvbnm;

  /// Độ mạnh của [password].
  PasswordStrength estimate(String password) =>
      strengthForScore(_zxcvbnm(password).score);
}

/// `Zxcvbnm.call` luôn gọi `options.copyWith(userInputs: …)`; bản gốc tạo
/// `Options` mới nên dựng lại từ điển xếp hạng ở mỗi lần gọi. Khi mọi tham số
/// là `null` (không có userInputs), trả chính instance này để giữ cache
/// `rankedDictionaries`.
final class _ReusableOptions extends Options {
  _ReusableOptions() : super(dictionaries: en.dictionaries);

  @override
  Options copyWith({
    List<BaseMatcher>? matchers,
    Set<Dictionaries>? dictionaries,
    List<String>? userInputs,
    L33tTable? l33tTable,
    Graph? graph,
    bool? useLevenshteinDistance,
    int? levenshteinThreshold,
    int? l33tMaxSubstitutions,
    int? maxLength,
  }) {
    if (matchers == null &&
        dictionaries == null &&
        userInputs == null &&
        l33tTable == null &&
        graph == null &&
        useLevenshteinDistance == null &&
        levenshteinThreshold == null &&
        l33tMaxSubstitutions == null &&
        maxLength == null) {
      return this;
    }
    return super.copyWith(
      matchers: matchers,
      dictionaries: dictionaries,
      userInputs: userInputs,
      l33tTable: l33tTable,
      graph: graph,
      useLevenshteinDistance: useLevenshteinDistance,
      levenshteinThreshold: levenshteinThreshold,
      l33tMaxSubstitutions: l33tMaxSubstitutions,
      maxLength: maxLength,
    );
  }
}
