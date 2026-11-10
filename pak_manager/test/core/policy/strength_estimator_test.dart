import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/policy/strength_estimator.dart';
import 'package:zxcvbnm/languages/en.dart' as en;
import 'package:zxcvbnm/options.dart';

void main() {
  test('ad15_score_mapping_0_2_low_3_medium_4_high', () {
    expect(strengthForScore(0), PasswordStrength.low);
    expect(strengthForScore(1), PasswordStrength.low);
    expect(strengthForScore(2), PasswordStrength.low);
    expect(strengthForScore(3), PasswordStrength.medium);
    expect(strengthForScore(4), PasswordStrength.high);
    // Ngoài khoảng: kẹp về biên.
    expect(strengthForScore(-1), PasswordStrength.low);
    expect(strengthForScore(5), PasswordStrength.high);
  });

  group('StrengthEstimator', () {
    final estimator = StrengthEstimator();

    test('ad15_empty_and_common_are_low', () {
      expect(estimator.estimate(''), PasswordStrength.low);
      expect(estimator.estimate('password'), PasswordStrength.low);
    });

    test('ad15_long_random_passphrase_is_high', () {
      expect(
        estimator.estimate('vortex lunar pickle magnet 7 drizzle'),
        PasswordStrength.high,
      );
    });

    test('ad15_dictionaries_not_rebuilt_on_second_call', () {
      final fresh = StrengthEstimator();
      final input = ('vortex lunar pickle magnet 7 drizzle ' * 4).substring(
        0,
        128,
      );
      // Hai lần liên tiếp với chuỗi 128 ký tự (từ điển đã dựng trong
      // constructor).
      expect(fresh.estimate(input), PasswordStrength.high);
      expect(fresh.estimate(input), PasswordStrength.high);

      // Thời gian khớp mẫu của zxcvbnm phụ thuộc chuỗi nên không so tuyệt đối.
      // Thay vào đó cô lập chi phí dựng từ điển: một lần gọi (chuỗi ngắn) sau
      // khi đã có cache phải rẻ hơn hẳn một lần dựng từ điển `en`. Cả hai đo
      // trên cùng máy, lấy min nhiều lần để giảm nhiễu.
      final cachedCall = _minMicros(5, () => fresh.estimate('short probe 1'));
      final rebuild = _rebuildMicros();
      expect(
        cachedCall,
        lessThan(rebuild ~/ 4),
        reason: 'gọi có cache: $cachedCall µs, dựng từ điển: $rebuild µs',
      );
    });

    test('ad15_constructor_warms_dictionaries', () {
      // Lần gọi ĐẦU TIÊN sau khi dựng instance cũng phải rẻ: từ điển xếp hạng
      // đã được dựng trong constructor, không để dồn vào lần gõ phím đầu.
      final firstCall = _minMicrosEach(3, () {
        final warmed = StrengthEstimator();
        return () => warmed.estimate('short probe 2');
      });
      final rebuild = _rebuildMicros();
      expect(
        firstCall,
        lessThan(rebuild ~/ 4),
        reason: 'lần gọi đầu: $firstCall µs, dựng từ điển: $rebuild µs',
      );
    });
  });
}

/// Thời gian nhỏ nhất (µs) qua [runs] lần; mỗi lần gọi [prepare] (không tính
/// giờ) để lấy phần thân cần đo.
int _minMicrosEach(int runs, void Function() Function() prepare) {
  var best = 1 << 62;
  for (var i = 0; i < runs; i++) {
    final body = prepare();
    final sw = Stopwatch()..start();
    body();
    sw.stop();
    if (sw.elapsedMicroseconds < best) {
      best = sw.elapsedMicroseconds;
    }
  }
  return best;
}

int _minMicros(int runs, void Function() body) =>
    _minMicrosEach(runs, () => body);

/// Chi phí dựng từ điển xếp hạng `en` trên một `Options` mới.
int _rebuildMicros() => _minMicros(
  3,
  () => Options(dictionaries: en.dictionaries).rankedDictionaries,
);
