import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/platform/pigeon_ports.dart';
import 'package:pak_manager/platform/platform_api.g.dart';

const _prefix = 'dev.flutter.pigeon.pak_manager.PlatformApi.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <BasicMessageChannel<Object?>>[];

  /// Cài handler giả cho kênh [method]; ghi lại tham số nhận được và trả
  /// [reply] (định dạng Pigeon: `[value]` hoặc `[code, message, details]`).
  List<Object?> mock(String method, List<Object?> reply) {
    final received = <Object?>[];
    final channel = BasicMessageChannel<Object?>(
      '$_prefix$method',
      PlatformApi.pigeonChannelCodec,
    );
    channels.add(channel);
    messenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
      received.add(message);
      return reply;
    });
    return received;
  }

  tearDown(() {
    for (final channel in channels) {
      messenger.setMockDecodedMessageHandler<Object?>(channel, null);
    }
    channels.clear();
  });

  test('nfr8_exclude_from_backup_sends_dir_path', () async {
    final received = mock('excludeFromBackup', [null]);

    await PigeonPlatformPorts().excludeFromBackup('/data/pak');

    expect(received, [
      ['/data/pak'],
    ]);
  });

  test('nfr8_exclude_from_backup_error_reply_throws', () async {
    mock('excludeFromBackup', ['backup', 'không đặt được cờ', null]);

    await expectLater(
      PigeonPlatformPorts().excludeFromBackup('/data/pak'),
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'backup')),
    );
  });

  test('nfr11_fsync_directory_sends_path', () async {
    final received = mock('fsyncDirectory', [null]);

    await PigeonPlatformPorts().fsyncDirectory('/data/pak/vault');

    expect(received, [
      ['/data/pak/vault'],
    ]);
  });

  test('nfr11_fsync_directory_error_reply_throws', () async {
    mock('fsyncDirectory', ['io', 'fsync errno 5', null]);

    await expectLater(
      PigeonPlatformPorts().fsyncDirectory('/data/pak/vault'),
      throwsA(isA<PlatformException>()),
    );
  });

  test('ad08_clock_monotonic_ms_returns_host_value', () async {
    final received = mock('monotonicMs', [123456789012]);

    expect(await PigeonPlatformPorts().monotonicMs(), 123456789012);
    expect(received, [null]);
  });

  test('ad08_clock_boot_id_returns_host_value', () async {
    final received = mock('bootId', ['3f1c-boot']);

    expect(await PigeonPlatformPorts().bootId(), '3f1c-boot');
    expect(received, [null]);
  });

  test('nfr13_android_sdk_int_returns_host_value', () async {
    final received = mock('androidSdkInt', [28]);

    expect(await PigeonPlatformPorts().androidSdkInt(), 28);
    expect(received, [null]);
  });
}
