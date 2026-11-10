import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/policy/password_policy.dart';

import 'policy_test_support.dart';

void main() {
  // Filter rỗng: không gì "phổ biến", để thử các luật còn lại độc lập.
  final policy = PasswordPolicy(emptyFilter());
  // Filter đầy: mọi chuỗi ASCII đều "phổ biến", để thử thứ tự ưu tiên.
  final everythingCommon = PasswordPolicy(fullFilter());

  group('hợp lệ (FR-2)', () {
    test('fr02_lowercase_and_spaces_only_is_ok', () {
      expect(policy.check('correct horse battery staple'), isA<PasswordOk>());
    });

    test('fr02_no_composition_rules', () {
      // Không bắt buộc chữ hoa, số hay ký hiệu.
      expect(policy.check('justlowercaseletters'), isA<PasswordOk>());
      expect(policy.check('ALL UPPER CASE WORDS'), isA<PasswordOk>());
      expect(policy.check('~!@#\$%^&*()_+{}|:"<>?'), isA<PasswordOk>());
    });

    test('fr52_export_password_uses_same_rules', () {
      expect(policy.check('export pass phrase 2026'), isA<PasswordOk>());
      expect(policy.check('short'), isA<PasswordTooShort>());
    });
  });

  group('không ASCII (AD-15, ưu tiên trước độ dài)', () {
    test('fr02_non_ascii_rejected_even_when_too_short', () {
      expect(policy.check('mậtkhẩu'), isA<PasswordNonAscii>());
      expect(policy.check('aé'), isA<PasswordNonAscii>());
    });

    test('fr02_control_char_is_non_ascii', () {
      expect(policy.check('\t${'a' * 20}'), isA<PasswordNonAscii>());
      expect(policy.check('${'b' * 20}\x7F'), isA<PasswordNonAscii>());
      expect(policy.check('${'c' * 20}\n'), isA<PasswordNonAscii>());
    });

    test('ad15_non_ascii_checked_before_length_and_blocklist', () {
      expect(everythingCommon.check('é' * 200), isA<PasswordNonAscii>());
      expect(everythingCommon.check('${'x' * 20}😀'), isA<PasswordNonAscii>());
    });
  });

  group('độ dài', () {
    test('fr02_length_boundaries', () {
      final r14 = policy.check('qwmnzxbvplkjhgf'.substring(0, 14));
      expect(r14, isA<PasswordTooShort>());
      expect((r14 as PasswordTooShort).length, 14);
      expect(policy.check('qwmnzxbvplkjhgf'), isA<PasswordOk>());
      final s128 = List.generate(128, (i) => 'qwmn zx'[i % 7]).join();
      expect(policy.check(s128), isA<PasswordOk>());
      expect(policy.check('${s128}q'), isA<PasswordTooLong>());
    });

    test('fr02_empty_is_too_short_zero', () {
      final r = policy.check('');
      expect(r, isA<PasswordTooShort>());
      expect((r as PasswordTooShort).length, 0);
    });

    test('ad15_length_checked_before_blocklist', () {
      final r = everythingCommon.check('a' * 14);
      expect((r as PasswordTooShort).length, 14);
      expect(everythingCommon.check('a' * 129), isA<PasswordTooLong>());
    });

    test('fr02_min_max_constants', () {
      expect(PasswordPolicy.minLength, 15);
      expect(PasswordPolicy.maxLength, 128);
    });
  });

  group('phổ biến (blocklist)', () {
    test('ad15_common_checked_before_pattern', () {
      expect(everythingCommon.check('a' * 15), isA<PasswordCommon>());
      expect(everythingCommon.check('123456789012345'), isA<PasswordCommon>());
    });

    test('fr02_every_sample_line_is_common_in_any_case', () {
      final real = PasswordPolicy(assetFilter());
      final sample = blocklistSample();
      expect(sample, hasLength(500));
      for (final line in sample) {
        expect(real.check(line), isA<PasswordCommon>(), reason: line);
        expect(
          real.check(line.toUpperCase()),
          isA<PasswordCommon>(),
          reason: line.toUpperCase(),
        );
        expect(
          real.check(_alternateCase(line)),
          isA<PasswordCommon>(),
          reason: _alternateCase(line),
        );
      }
    });

    test('ad15_blocklist_asset_within_2_mib', () {
      expect(File(blocklistAssetPath).lengthSync(), lessThanOrEqualTo(2097152));
    });
  });

  group('lặp / tuần tự (cả chuỗi)', () {
    test('fr02_repeated_char_rejected', () {
      expect(policy.check('aaaaaaaaaaaaaaa'), isA<PasswordPattern>());
      expect(policy.check('aAaAaAaAaAaAaAa'), isA<PasswordPattern>());
      expect(policy.check(' ' * 15), isA<PasswordPattern>());
      expect(policy.check('!' * 128), isA<PasswordPattern>());
    });

    test('fr02_sequential_rejected_with_wraparound', () {
      expect(policy.check('123456789012345'), isA<PasswordPattern>());
      expect(policy.check('987654321098765'), isA<PasswordPattern>());
      expect(policy.check('abcdefghijklmno'), isA<PasswordPattern>());
      expect(policy.check('XYZABCDEFGHIJKL'), isA<PasswordPattern>());
      expect(
        policy.check('zyxwvutsrqponmlkjihgfedcbazyx'),
        isA<PasswordPattern>(),
      );
      expect(policy.check('aBcDeFgHiJkLmNoP'), isA<PasswordPattern>());
    });

    test('fr02_not_whole_string_sequence_is_not_pattern', () {
      for (final s in [
        '1234567890123456 x',
        'abcabcabcabcabc',
        '13579135791357 9',
        'aaaaaaaaaaaaaab',
        'abcdefghijklmnp',
        '0123456789abcdef',
        'abcdefg hijklmno',
      ]) {
        expect(policy.check(s), isNot(isA<PasswordPattern>()), reason: s);
      }
    });
  });

  group('cổng đăng nhập (S3/S25)', () {
    test('ad15_login_gate_requires_15_printable_ascii', () {
      expect(PasswordPolicy.meetsLoginGate('a' * 14), isFalse);
      expect(PasswordPolicy.meetsLoginGate('a' * 15), isTrue);
      expect(PasswordPolicy.meetsLoginGate(''), isFalse);
      expect(PasswordPolicy.meetsLoginGate('mậtkhẩu dài đủ mười lăm'), isFalse);
      expect(PasswordPolicy.meetsLoginGate('${'a' * 20}\t'), isFalse);
      // Cổng không xét blocklist, mẫu lặp hay trần độ dài.
      expect(PasswordPolicy.meetsLoginGate('a' * 200), isTrue);
    });
  });
}

String _alternateCase(String s) => String.fromCharCodes([
  for (var i = 0; i < s.length; i++)
    i.isEven ? s.toUpperCase().codeUnitAt(i) : s.toLowerCase().codeUnitAt(i),
]);
