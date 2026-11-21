import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/format/guard_codec.dart';
import 'package:pak_manager/core/guard/guard_state.dart';

const _fixtures = 'test/fixtures/guard/v1';

List<int> _golden(String name) => File('$_fixtures/$name').readAsBytesSync();

/// Bản v1 hợp lệ có mốc chờ, để thấy rõ trường nào bị thay.
Map<String, Object?> _waiting() =>
    jsonDecode(utf8.decode(_golden('waiting.json'))) as Map<String, Object?>;

const _waitingState = GuardState(
  failCount: 7,
  waitBootId: 'fake-boot-1',
  waitStartMono: 1800000,
);

GuardDecodeResult _decodeJson(Object? json) =>
    GuardCodec.decode(utf8.encode(jsonEncode(json)));

GuardDecodeResult _withField(String key, Object? value) =>
    _decodeJson(_waiting()..[key] = value);

void main() {
  group('golden', () {
    test('ad20_initial_golden_round_trips_byte_for_byte', () {
      final golden = _golden('initial.json');

      expect(GuardCodec.decode(golden), isA<GuardOk>());
      expect((GuardCodec.decode(golden) as GuardOk).state, GuardState.initial);
      expect(GuardCodec.encode(GuardState.initial), golden);
    });

    test('ad20_waiting_golden_reads_every_field_and_round_trips', () {
      final golden = _golden('waiting.json');

      final decoded = GuardCodec.decode(golden);
      expect(decoded, isA<GuardOk>());
      expect((decoded as GuardOk).state, _waitingState);
      expect(GuardCodec.encode(_waitingState), golden);
      expect(GuardCodec.encode(decoded.state), golden);
    });

    test('ad20_encode_uses_key_order_without_whitespace', () {
      final text = utf8.decode(
        GuardCodec.encode(const GuardState(failCount: 3, wiping: true)),
      );

      expect(text, isNot(contains(' ')));
      expect(text, isNot(contains('\n')));
      final keys = RegExp(r'"(\w+)":').allMatches(text).map((m) => m[1]);
      expect(keys, ['v', 'failCount', 'waitBootId', 'waitStartMono', 'wiping']);
    });

    test('ad20_failcount_bounds_are_readable', () {
      for (final n in [0, maxAttempts]) {
        final result = _withField('failCount', n);
        expect(result, isA<GuardOk>(), reason: '$n');
        expect((result as GuardOk).state.failCount, n);
      }
    });

    test('ad20_unknown_keys_are_ignored', () {
      final result = _decodeJson(_waiting()..['extra'] = 1);
      expect(result, isA<GuardOk>());
      expect((result as GuardOk).state, _waitingState);
    });
  });

  group('unreadable', () {
    final raw = <String, List<int>>{
      'empty': [],
      'not_utf8': [0xff, 0xfe, 0x00],
      'not_json': utf8.encode('{"v":1,'),
      'array': utf8.encode('[1]'),
      'string': utf8.encode('"guard"'),
      'null': utf8.encode('null'),
    };
    for (final MapEntry(key: name, value: bytes) in raw.entries) {
      test('ad08_ad20_unreadable_$name', () {
        expect(GuardCodec.decode(bytes), isA<GuardUnreadable>());
      });
    }

    for (final key in [
      'v',
      'failCount',
      'waitBootId',
      'waitStartMono',
      'wiping',
    ]) {
      test('ad08_ad20_missing_${key}_is_unreadable', () {
        expect(_decodeJson(_waiting()..remove(key)), isA<GuardUnreadable>());
      });
    }

    final badFields = <String, (String, Object?)>{
      'v_2': ('v', 2),
      'v_0': ('v', 0),
      'v_string': ('v', '1'),
      'v_null': ('v', null),
      'v_double': ('v', 1.5),
      'failcount_negative': ('failCount', -1),
      'failcount_over_max': ('failCount', maxAttempts + 1),
      'failcount_double': ('failCount', 2.5),
      'failcount_string': ('failCount', '3'),
      'failcount_null': ('failCount', null),
      'failcount_bool': ('failCount', true),
      'waitbootid_int': ('waitBootId', 7),
      'waitbootid_bool': ('waitBootId', false),
      'waitbootid_list': ('waitBootId', <Object?>[]),
      'waitstartmono_negative': ('waitStartMono', -1),
      'waitstartmono_string': ('waitStartMono', '1'),
      'waitstartmono_double': ('waitStartMono', 1.5),
      'wiping_null': ('wiping', null),
      'wiping_int': ('wiping', 0),
      'wiping_string': ('wiping', 'true'),
    };
    for (final MapEntry(key: name, value: (field, value))
        in badFields.entries) {
      test('ad08_ad20_bad_field_is_unreadable_$name', () {
        expect(_withField(field, value), isA<GuardUnreadable>());
      });
    }
  });
}
