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
      // Hai lần liên tiếp với chuỗi 128 ký tự (lần đầu dựng từ điển xếp hạng).
      expect(fresh.estimate(input), PasswordStrength.high);
      expect(fresh.estimate(input), PasswordStrength.high);

      // Thời gian khớp mẫu của zxcvbnm phụ thuộc chuỗi nên không so tuyệt đối.
      // Thay vào đó cô lập chi phí dựng từ điển: một lần gọi (chuỗi ngắn) sau
      // khi đã có cache phải rẻ hơn hẳn một lần dựng từ điển `en`. Cả hai đo
      // trên cùng máy, lấy min nhiều lần để giảm nhiễu.
      int minMicros(int runs, void Function() body) {
        var best = 1 << 62;
        for (var i = 0; i < runs; i++) {
          final sw = Stopwatch()..start();
          body();
          sw.stop();
          if (sw.elapsedMicroseconds < best) {
            best = sw.elapsedMicroseconds;
          }
        }
        return best;
      }

      final cachedCall = minMicros(5, () => fresh.estimate('short probe 1'));
      final rebuild = minMicros(
        3,
        () => Options(dictionaries: en.dictionaries).rankedDictionaries,
      );
      expect(
        cachedCall,
        lessThan(rebuild ~/ 4),
        reason: 'gọi có cache: $cachedCall µs, dựng từ điển: $rebuild µs',
      );
    });
  });
}
