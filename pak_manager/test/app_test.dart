import 'dart:async';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/ports/app_directory_port.dart';
import 'package:pak_manager/core/ports/backup_port.dart';
import 'package:pak_manager/main.dart' as app;
import 'package:pak_manager/platform/platform_api.g.dart';
import 'package:pak_manager/services/storage_bootstrap.dart';

void main() {
  testWidgets('pak_app_builds_cupertino_app', (tester) async {
    await tester.pumpWidget(const app.PakApp());

    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.byType(CupertinoPageScaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ad18_main_keeps_handlers_outside_release_mode', (tester) async {
    final savedDebugPrint = debugPrint;
    final savedFlutterOnError = FlutterError.onError;
    final savedPlatformOnError = PlatformDispatcher.instance.onError;

    // Cùng đường chạy với main() nhưng port giả, để test không chạm plugin
    // hay hệ thống file thật.
    app.runPakApp(_unavailableStorage(), releaseMode: kReleaseMode);
    await tester.pump();

    // Ghi nhận rồi khôi phục handler trước khi assert: nếu main() lỡ cài chính
    // sách release, handler nuốt lỗi sẽ nuốt luôn lỗi assert và test bị treo.
    final kept = (
      identical(debugPrint, savedDebugPrint),
      identical(FlutterError.onError, savedFlutterOnError),
      identical(PlatformDispatcher.instance.onError, savedPlatformOnError),
    );
    debugPrint = savedDebugPrint;
    FlutterError.onError = savedFlutterOnError;
    PlatformDispatcher.instance.onError = savedPlatformOnError;

    // `flutter test` không chạy ở release mode: main() phải giữ nguyên handler.
    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(kept, (true, true, true));
  });

  testWidgets('ad18_nfr8_real_main_bootstraps_storage_then_builds_app', (
    tester,
  ) async {
    final savedDebugPrint = debugPrint;
    final savedFlutterOnError = FlutterError.onError;
    final savedPlatformOnError = PlatformDispatcher.instance.onError;
    final sep = Platform.pathSeparator;

    // ApplicationSupport giả: kênh path_provider trả về thư mục tạm, để main()
    // chạy hết bootstrap mà không chạm thư mục dữ liệu thật của máy.
    final sandbox = Directory.systemTemp.createTempSync('pak_main_');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final pak = '${sandbox.path}${sep}pak';
    Directory('$pak${sep}vault').createSync(recursive: true);
    final staleTmp = File('$pak${sep}vault${sep}cards.tmp')
      ..writeAsBytesSync([1]);

    final messenger = tester.binding.defaultBinaryMessenger;
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    messenger.setMockMethodCallHandler(pathProvider, (call) async {
      if (call.method == 'getApplicationSupportDirectory') {
        return sandbox.path;
      }
      throw MissingPluginException(call.method);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(pathProvider, null));

    // Ghi lại mọi lời gọi Pigeon kèm tham số; trả lời thành công (`[null]`).
    final pigeonCalls = <(String, Object?)>[];
    const prefix = 'dev.flutter.pigeon.pak_manager.PlatformApi.';
    const methods = [
      'bootId',
      'monotonicMs',
      'excludeFromBackup',
      'fsyncDirectory',
    ];
    for (final method in methods) {
      final channel = BasicMessageChannel<Object?>(
        '$prefix$method',
        PlatformApi.pigeonChannelCodec,
      );
      messenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
        pigeonCalls.add((method, message));
        return [null];
      });
      addTearDown(
        () => messenger.setMockDecodedMessageHandler<Object?>(channel, null),
      );
    }

    app.main();
    // Bootstrap xen kẽ I/O thật (tạo `pak/`, dọn tmp) với phản hồi của kênh
    // giả trong FakeAsync: chờ async thật rồi pump, lặp tới khi có app.
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(CupertinoApp).evaluate().isNotEmpty) {
        break;
      }
    }

    final kept = (
      identical(debugPrint, savedDebugPrint),
      identical(FlutterError.onError, savedFlutterOnError),
      identical(PlatformDispatcher.instance.onError, savedPlatformOnError),
    );
    debugPrint = savedDebugPrint;
    FlutterError.onError = savedFlutterOnError;
    PlatformDispatcher.instance.onError = savedPlatformOnError;

    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(kept, (true, true, true));
    // main() nối adapter Pigeon thật vào bootstrap: cờ backup được đặt trên
    // `pak/`, rồi `*.tmp` sót bị dọn bằng sweeper mặc định.
    expect(pigeonCalls.map((c) => c.$1), ['excludeFromBackup']);
    expect(pigeonCalls.single.$2, [pak]);
    expect(Directory(pak).existsSync(), isTrue);
    expect(staleTmp.existsSync(), isFalse);
  });

  testWidgets('nfr8_run_app_waits_for_storage_bootstrap', (tester) async {
    final directories = _PendingDirectory();
    final backup = _RecordingBackup();

    app.runPakApp(
      StorageBootstrap(directories: directories, backup: backup),
      releaseMode: false,
    );
    await tester.pump();
    // Bootstrap chưa xong: chưa runApp.
    expect(find.byType(CupertinoApp), findsNothing);
    expect(directories.calls, 1);

    // Khởi động lỗi vẫn runApp (fail-closed ở tầng dữ liệu, không ở UI).
    directories.completer.completeError(StateError('không có thư mục'));
    await tester.pump();
    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(backup.calls, isEmpty);
  });
}

StorageBootstrap _unavailableStorage() => StorageBootstrap(
  directories: _FailingDirectory(),
  backup: _RecordingBackup(),
);

class _FailingDirectory implements AppDirectoryPort {
  @override
  Future<String> applicationSupportPath() async =>
      throw StateError('không có thư mục');
}

class _PendingDirectory implements AppDirectoryPort {
  final completer = Completer<String>();
  var calls = 0;

  @override
  Future<String> applicationSupportPath() {
    calls++;
    return completer.future;
  }
}

class _RecordingBackup implements BackupPort {
  final calls = <String>[];

  @override
  Future<void> excludeFromBackup(String dirPath) async => calls.add(dirPath);
}
