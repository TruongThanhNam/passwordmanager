import 'dart:async';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/format/settings_codec.dart';
import 'package:pak_manager/core/model/settings.dart';
import 'package:pak_manager/core/ports/app_directory_port.dart';
import 'package:pak_manager/core/ports/backup_port.dart';
import 'package:pak_manager/core/ports/file_sync_port.dart';
import 'package:pak_manager/features/shared/content_column.dart';
import 'package:pak_manager/features/shared/pak_app.dart';
import 'package:pak_manager/main.dart' as app;
import 'package:pak_manager/platform/platform_api.g.dart';
import 'package:pak_manager/services/settings_store.dart';
import 'package:pak_manager/services/storage_bootstrap.dart';

void main() {
  testWidgets('pak_app_builds_cupertino_app', (tester) async {
    await tester.pumpWidget(PakApp(settings: SettingsStore.inMemory()));

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
    app.runPakApp(
      _unavailableStorage(),
      fileSync: _RecordingFileSync(),
      releaseMode: kReleaseMode,
    );
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
    // `settings` có sẵn, khác mặc định ở ngôn ngữ (vi) và giao diện (dark).
    final settingsFile = File('$pak${sep}settings')
      ..writeAsBytesSync(
        File('test/fixtures/settings/v1/custom.json').readAsBytesSync(),
      );
    final settingsBytes = settingsFile.readAsBytesSync();

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
    expect(pigeonCalls.first.$1, 'excludeFromBackup');
    expect(pigeonCalls.first.$2, [pak]);
    expect(Directory(pak).existsSync(), isTrue);
    expect(staleTmp.existsSync(), isFalse);

    // main() nạp `settings` từ `pak/` đã bootstrap và áp vào app; chỉ nạp
    // thì không ghi lại file.
    final inside = tester.element(find.byType(ContentColumn));
    expect(Localizations.localeOf(inside).languageCode, 'vi');
    expect(CupertinoTheme.brightnessOf(inside), Brightness.dark);
    expect(pigeonCalls.map((c) => c.$1), isNot(contains('fsyncDirectory')));
    expect(settingsFile.readAsBytesSync(), settingsBytes);

    // Đổi cài đặt rồi cho app ẩn: store ghi ngay qua `fileSync` của main(),
    // tức chính PigeonPlatformPorts (fsync thư mục `pak/`).
    final store = tester.widget<PakApp>(find.byType(PakApp)).settings;
    expect(
      store.update((s) => s.copyWith(appearance: Appearance.light)),
      isTrue,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    for (var i = 0; i < 100 && store.dirty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(store.dirty, isFalse);
    expect(
      pigeonCalls.where((c) => c.$1 == 'fsyncDirectory').map((c) => c.$2),
      anyElement(equals([pak])),
    );
    expect(SettingsCodec.decode(settingsFile.readAsBytesSync()), store.current);
    expect(store.current.appearance, Appearance.light);
  });

  testWidgets('ad1_run_app_enables_edge_to_edge_without_blocking', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      // Lỗi của lời gọi edge-to-edge không được chặn khởi động.
      if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
        throw PlatformException(code: 'unavailable');
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    app.runPakApp(
      _unavailableStorage(),
      fileSync: _RecordingFileSync(),
      releaseMode: false,
    );
    await tester.pump();

    expect(
      calls.where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode'),
      [
        isA<MethodCall>().having(
          (c) => c.arguments,
          'arguments',
          'SystemUiMode.edgeToEdge',
        ),
      ],
    );
    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nfr8_run_app_waits_for_storage_bootstrap', (tester) async {
    final directories = _PendingDirectory();
    final backup = _RecordingBackup();
    final fileSync = _RecordingFileSync();

    app.runPakApp(
      StorageBootstrap(directories: directories, backup: backup),
      fileSync: fileSync,
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
    // Lưu trữ lỗi: settings chỉ ở RAM, không đọc/ghi file.
    expect(fileSync.calls, isEmpty);
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

class _RecordingFileSync implements FileSyncPort {
  final calls = <String>[];

  @override
  Future<void> fsyncDirectory(String path) async => calls.add(path);
}

class _RecordingBackup implements BackupPort {
  final calls = <String>[];

  @override
  Future<void> excludeFromBackup(String dirPath) async => calls.add(dirPath);
}
