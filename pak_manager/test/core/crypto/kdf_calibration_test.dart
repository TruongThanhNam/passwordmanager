import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/crypto/kdf.dart';
import 'package:pak_manager/core/crypto/kdf_calibration.dart';
import 'package:pak_manager/core/format/header_codec.dart';
import 'package:sodium/sodium_sumo.dart';

import '../vault_fixture.dart';

/// KEK giả, chỉ ghi nhận `dispose`.
final class _FakeKey implements SecureKey {
  _FakeKey(this.run);

  final int run;
  bool disposed = false;

  @override
  int get length => kekBytes;

  @override
  void dispose() => disposed = true;

  @override
  T runUnlockedSync<T>(SecureCallbackFn<T> callback, {bool writable = false}) =>
      callback(Uint8List(kekBytes));

  @override
  FutureOr<T> runUnlockedAsync<T>(
    SecureCallbackFn<FutureOr<T>> callback, {
    bool writable = false,
  }) => callback(Uint8List(kekBytes));

  @override
  Uint8List extractBytes() => Uint8List(kekBytes);

  @override
  SecureKey copy() => _FakeKey(run);
}

/// `derive` giả trên đồng hồ giả: lần chạy thứ i tốn `durations[i]` ms.
/// `null` trong [durations] = KDF lỗi; [_throw] trong [durations] = `derive`
/// ném.
final class _Harness {
  _Harness(this.durations);

  static const int _throw = -1;

  final List<int?> durations;
  final List<KdfParams> calls = [];
  final List<_FakeKey> keys = [];
  int _now = 0;

  int nowMs() => _now;

  Future<SecureKey?> derive(
    Uint8List password,
    Uint8List salt,
    KdfParams params,
  ) async {
    expect(password, fixturePassword());
    expect(salt, fixtureSalt());
    calls.add(params);
    final cost = durations[calls.length - 1];
    if (cost == null) {
      return null;
    }
    if (cost == _throw) {
      throw StateError('derive lỗi');
    }
    _now += cost;
    final key = _FakeKey(calls.length);
    keys.add(key);
    return key;
  }

  Future<CalibratedKek?> run() => calibrateVaultKdf(
    password: fixturePassword(),
    salt: fixtureSalt(),
    derive: derive,
    nowMs: nowMs,
  );

  /// Chỉ KEK được trả về còn sống; mọi KEK khác đã dispose.
  void expectOnlyReturnedAlive(CalibratedKek? result) {
    for (final key in keys) {
      expect(
        key.disposed,
        !identical(key, result?.kek),
        reason: 'KEK lần ${key.run}',
      );
    }
  }
}

void main() {
  test('ad05_probe_1000ms_accepts_start_params_after_one_run', () async {
    final h = _Harness([1000]);

    final result = await h.run();

    expect(result!.params, const KdfParams(3, 64 * mib));
    expect(h.calls, [KdfParams.start]);
    expect(identical(result.kek, h.keys.single), isTrue);
    h.expectOnlyReturnedAlive(result);
  });

  test('ad05_probe_inside_500_to_1500ms_is_accepted', () async {
    for (final ms in [500, 1500]) {
      final h = _Harness([ms]);

      final result = await h.run();

      expect(result!.params, KdfParams.start, reason: '$ms ms');
      expect(h.calls, hasLength(1));
    }
  });

  test('ad05_probe_300ms_raises_ops_to_10_keeping_64_mib', () async {
    final h = _Harness([300, 1000]);

    final result = await h.run();

    expect(result!.params, const KdfParams(10, 64 * mib));
    expect(h.calls, [KdfParams.start, const KdfParams(10, 64 * mib)]);
    expect(identical(result.kek, h.keys.last), isTrue);
    h.expectOnlyReturnedAlive(result);
  });

  test('ad05_probe_499ms_scales_ops_by_round_3f', () async {
    final h = _Harness([499, 1000]);

    final result = await h.run();

    // f = 1000/499 ≈ 2,004 → t = round(6,01) = 6.
    expect(result!.params, const KdfParams(6, 64 * mib));
  });

  test('ad05_zero_duration_probe_uses_max_ops', () async {
    final h = _Harness([0, 1000]);

    final result = await h.run();

    expect(result!.params, const KdfParams(10, 64 * mib));
  });

  test('ad05_probe_6000ms_still_slow_stops_at_floor', () async {
    final h = _Harness([6000, 2500, 2500]);

    final result = await h.run();

    final params = result!.params;
    expect(params.opsLimit, greaterThanOrEqualTo(KdfParams.opsMin));
    expect(params.memLimitBytes, greaterThanOrEqualTo(KdfParams.memMinBytes));
    expect(params, KdfParams.floor);
    // 3f = 0,5 → t = 2, m = max(19, floor(64·0,5/2)) = 19 MiB = sàn → nhận.
    expect(h.calls, [KdfParams.start, KdfParams.floor]);
    expect(h.calls.length, lessThanOrEqualTo(3));
    h.expectOnlyReturnedAlive(result);
  });

  test('ad05_second_run_over_2000ms_reduces_once_more_then_accepts', () async {
    final h = _Harness([2000, 2500, 9000]);

    final result = await h.run();

    // Lần 2: f = 0,5, 3f = 1,5 → t = 2, m = floor(64·1,5/2) = 48 MiB.
    // Lần 3: f = 0,4, 2f = 0,8 → t = 2, m = max(19, floor(48·0,8/2)) = 19.
    expect(h.calls, [
      KdfParams.start,
      const KdfParams(2, 48 * mib),
      KdfParams.floor,
    ]);
    expect(result!.params, KdfParams.floor);
    expect(identical(result.kek, h.keys.last), isTrue);
    h.expectOnlyReturnedAlive(result);
  });

  test('ad05_second_run_within_2000ms_is_accepted', () async {
    final h = _Harness([1600, 2000]);

    final result = await h.run();

    // f = 0,625, 3f = 1,875 → t = 2, m = floor(64·1,875/2) = 60 MiB.
    expect(result!.params, const KdfParams(2, 60 * mib));
    expect(h.calls, hasLength(2));
  });

  test('ad05_every_calibrated_params_is_allowed', () async {
    for (final probe in [1, 100, 499, 1501, 1999, 2001, 4000, 100000]) {
      for (final second in [100, 1000, 2001, 50000]) {
        final h = _Harness([probe, second, 50000]);

        final result = await h.run();

        expect(result!.params.isAllowed, isTrue, reason: '$probe/$second');
        expect(h.calls.every((p) => p.isAllowed), isTrue);
        expect(h.calls.length, lessThanOrEqualTo(3));
        h.expectOnlyReturnedAlive(result);
      }
    }
  });

  test('ad05_probe_failure_retries_once_at_floor_and_accepts', () async {
    for (final probe in <int?>[null, _Harness._throw]) {
      // Lần ở sàn chậm 9000 ms vẫn được nhận: không còn gì thấp hơn.
      final h = _Harness([probe, 9000]);

      final result = await h.run();

      expect(h.calls, [KdfParams.start, KdfParams.floor], reason: '$probe');
      expect(result!.params, KdfParams.floor);
      expect(identical(result.kek, h.keys.single), isTrue);
      h.expectOnlyReturnedAlive(result);
    }
  });

  test('ad05_probe_and_floor_both_failing_returns_null', () async {
    for (final durations in [
      <int?>[null, null],
      <int?>[null, _Harness._throw],
      <int?>[_Harness._throw, null],
      <int?>[_Harness._throw, _Harness._throw],
    ]) {
      final h = _Harness(durations);

      final result = await h.run();

      expect(result, isNull, reason: '$durations');
      expect(h.calls, [KdfParams.start, KdfParams.floor]);
      expect(h.keys, isEmpty);
    }
  });

  test(
    'ad05_kdf_failure_after_probe_success_returns_null_and_disposes',
    () async {
      for (final durations in [
        <int?>[300, null],
        <int?>[2000, 2500, null],
      ]) {
        final h = _Harness(durations);

        final result = await h.run();

        expect(result, isNull);
        expect(h.keys.every((k) => k.disposed), isTrue);
        // Lỗi sau probe thành công không lùi về sàn.
        expect(h.calls, hasLength(durations.length), reason: '$durations');
      }
    },
  );

  test('ad05_derive_throwing_after_probe_success_returns_null', () async {
    for (final durations in [
      <int?>[300, _Harness._throw],
      <int?>[2000, 2500, _Harness._throw],
    ]) {
      final h = _Harness(durations);

      final result = await h.run();

      expect(result, isNull, reason: '$durations');
      expect(h.calls, hasLength(durations.length));
      expect(h.keys.every((k) => k.disposed), isTrue, reason: '$durations');
    }
  });

  test('ad05_reduction_after_slow_run_never_raises_memory', () async {
    // (10, 64) chậm 2200 ms → (4, 64), không phải (4, 72);
    // (6, 64) chậm 2100 ms → (2, 64), không phải (2, 91).
    for (final (durations, expected) in [
      ([300, 2200, 9000], const KdfParams(4, 64 * mib)),
      ([499, 2100, 9000], const KdfParams(2, 64 * mib)),
    ]) {
      final h = _Harness(durations);

      final result = await h.run();

      expect(h.calls, hasLength(3), reason: '$durations');
      expect(h.calls.last, expected, reason: '$durations');
      expect(result!.params, expected);
      for (var i = 2; i < h.calls.length; i++) {
        final prev = h.calls[i - 1];
        final next = h.calls[i];
        expect(
          next.memLimitBytes,
          lessThanOrEqualTo(prev.memLimitBytes),
          reason: '$durations lần ${i + 1}',
        );
        expect(
          next.opsLimit * next.memLimitBytes,
          lessThan(prev.opsLimit * prev.memLimitBytes),
          reason: '$durations lần ${i + 1}',
        );
      }
      h.expectOnlyReturnedAlive(result);
    }
  });

  test('ad05_default_clock_measures_real_elapsed_time', () async {
    // Không truyền nowMs: đồng hồ mặc định (Stopwatch) phải đo thời gian
    // thật. 800 ms nằm giữa cửa sổ nhận [500, 1500], chừa dư cho CI chậm.
    final keys = <_FakeKey>[];
    final calls = <KdfParams>[];

    final result = await calibrateVaultKdf(
      password: fixturePassword(),
      salt: fixtureSalt(),
      derive: (password, salt, params) async {
        calls.add(params);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        final key = _FakeKey(calls.length);
        keys.add(key);
        return key;
      },
    );

    expect(calls, [KdfParams.start]);
    expect(result!.params, KdfParams.start);
    expect(identical(result.kek, keys.single), isTrue);
  });

  test('ad05_default_deriver_runs_real_kdf', () async {
    final sodium = await initSodium();
    final kek = await kekDeriver(sodium)(
      fixturePassword(),
      fixtureSalt(),
      fixtureParams,
    );
    addTearDown(() => kek?.dispose());

    expect(kek?.length, kekBytes);
    // Đúng mật khẩu, salt, params → kcv khớp header fixture.
    final codec = HeaderCodec(sodium);
    final header = (codec.decode(vaultFixture('header')) as HeaderOk).header;
    expect(codec.kcvMatches(header, kek!), isTrue);
  });
}
