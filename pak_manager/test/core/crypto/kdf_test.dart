import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/crypto/kdf.dart';
import 'package:pak_manager/core/format/header_codec.dart';
import 'package:sodium/sodium_sumo.dart';

import '../vault_fixture.dart';

/// Chỉ isolate test đặt giá trị này; isolate KDF mới tạo thấy giá trị mặc định.
int _isolateMarker = 0;

/// Hook gửi sang isolate KDF. Tạo ở hàm riêng để closure chỉ mang
/// [port] (closure tạo trong `derive` sẽ kéo theo `Completer`, không gửi
/// qua isolate được).
void Function() _hook(SendPort port, {required bool throwInIsolate}) => () {
  port.send(null);
  if (throwInIsolate) {
    throw StateError('boom');
  }
};

void main() {
  late SodiumSumo sodium;
  setUpAll(() async => sodium = await initSodium());

  group('KdfParams', () {
    test('ad05_allowed_range_is_ops_2_to_10_and_mem_19_to_128_mib', () {
      expect(KdfParams.start, const KdfParams(3, 64 * mib));
      expect(KdfParams.floor, const KdfParams(2, 19 * mib));
      expect(mib, 1048576);
      for (final ok in [
        const KdfParams(2, 19 * mib),
        const KdfParams(10, 128 * mib),
        KdfParams.start,
      ]) {
        expect(ok.isAllowed, isTrue, reason: '$ok');
      }
      for (final bad in [
        const KdfParams(1, 64 * mib),
        const KdfParams(11, 64 * mib),
        const KdfParams(3, 19 * mib - 1),
        const KdfParams(3, 128 * mib + 1),
        const KdfParams(-1, 64 * mib),
        const KdfParams(3, -1),
      ]) {
        expect(bad.isAllowed, isFalse, reason: '$bad');
      }
    });
  });

  group('deriveKek', () {
    /// Chạy [deriveKek] với hook đếm số lần callback isolate được gọi.
    ///
    /// [expectRun]: chờ (có timeout) tới khi tin nhắn của hook tới nơi. Khi
    /// tham số/salt sai thì không isolate nào được tạo, nên đếm ngay.
    Future<(Object?, int)> derive(
      KdfParams params, {
      Uint8List? salt,
      bool throwInIsolate = false,
      bool expectRun = true,
    }) async {
      final port = ReceivePort();
      final sendPort = port.sendPort;
      var calls = 0;
      final ran = Completer<void>();
      final sub = port.listen((_) {
        calls++;
        if (!ran.isCompleted) {
          ran.complete();
        }
      });
      final kek = await deriveKek(
        sodium,
        fixturePassword(),
        salt ?? fixtureSalt(),
        params,
        debugInIsolate: _hook(sendPort, throwInIsolate: throwInIsolate),
      );
      if (expectRun) {
        await ran.future.timeout(const Duration(seconds: 30));
      }
      await sub.cancel();
      port.close();
      return (kek, calls);
    }

    test('ad05_out_of_range_params_return_null_without_running_kdf', () async {
      for (final params in [
        const KdfParams(1, 19 * mib),
        const KdfParams(11, 19 * mib),
        const KdfParams(2, 19 * mib - 1),
        const KdfParams(2, 128 * mib + 1),
      ]) {
        final (kek, calls) = await derive(params, expectRun: false);

        expect(kek, isNull, reason: '$params');
        expect(calls, 0, reason: '$params');
      }
    });

    test('ad05_salt_not_16_bytes_returns_null_without_running_kdf', () async {
      for (final salt in [seq(0, 15), seq(0, 17), Uint8List(0)]) {
        final (kek, calls) = await derive(
          fixtureParams,
          salt: salt,
          expectRun: false,
        );

        expect(kek, isNull);
        expect(calls, 0);
      }
    });

    test('ad04_fixture_password_derives_kek_matching_fixture_kcv', () async {
      final password = fixturePassword();
      final kek = await deriveKek(
        sodium,
        password,
        fixtureSalt(),
        fixtureParams,
      );
      addTearDown(() => kek?.dispose());

      expect(kek, isNotNull);
      expect(kek!.length, kekBytes);
      final codec = HeaderCodec(sodium);
      final header = (codec.decode(vaultFixture('header')) as HeaderOk).header;
      expect(codec.kcvMatches(header, kek), isTrue);
      // Bản của caller không bị đổi; caller tự wipe.
      expect(password, fixturePassword());
    });

    test('ad05_kdf_callback_runs_on_another_isolate', () async {
      _isolateMarker = 42;
      final port = ReceivePort();
      final sendPort = port.sendPort;
      final seen = port.first;

      final kek = await deriveKek(
        sodium,
        fixturePassword(),
        fixtureSalt(),
        fixtureParams,
        debugInIsolate: () => sendPort.send(_isolateMarker),
      );
      addTearDown(() => kek?.dispose());

      expect(kek, isNotNull);
      expect(await seen, 0);
      expect(_isolateMarker, 42);
    });

    test('ad05_error_inside_isolate_returns_null', () async {
      final (kek, calls) = await derive(fixtureParams, throwInIsolate: true);

      expect(kek, isNull);
      expect(calls, 1);
    });
  });
}
