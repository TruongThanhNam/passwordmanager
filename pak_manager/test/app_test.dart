import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/format/settings_codec.dart';
import 'package:pak_manager/core/model/settings.dart';
import 'package:pak_manager/core/ports/app_directory_port.dart';
import 'package:pak_manager/core/ports/backup_port.dart';
import 'package:pak_manager/core/ports/file_sync_port.dart';
import 'package:pak_manager/core/ports/system_info_port.dart';
import 'package:pak_manager/features/auth/login_screen.dart';
import 'package:pak_manager/features/shared/content_column.dart';
import 'package:pak_manager/features/shared/pak_app.dart';
import 'package:pak_manager/main.dart' as app;
import 'package:pak_manager/platform/platform_api.g.dart';
import 'package:pak_manager/services/settings_store.dart';
import 'package:pak_manager/services/storage_bootstrap.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  testWidgets('pak_app_builds_cupertino_app', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: PakApp(settings: SettingsStore.inMemory(), androidSdkInt: 35),
      ),
    );

    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.byType(CupertinoPageScaffold), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
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
      systemInfo: _FakeSystemInfo(35),
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

    // Ghi lại mọi lời gọi Pigeon kèm tham số; trả lời thành công.
    final pigeonCalls = <(String, Object?)>[];
    const prefix = 'dev.flutter.pigeon.pak_manager.PlatformApi.';
    const replies = <String, Object?>{
      'bootId': '',
      'monotonicMs': 0,
      'excludeFromBackup': null,
      'fsyncDirectory': null,
      'androidSdkInt': 28,
    };
    for (final MapEntry(key: method, value: reply) in replies.entries) {
      final channel = BasicMessageChannel<Object?>(
        '$prefix$method',
        PlatformApi.pigeonChannelCodec,
      );
      messenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
        pigeonCalls.add((method, message));
        return [reply];
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
    // `pak/`, rồi `*.tmp` sót bị dọn bằng sweeper mặc định. Khởi động chỉ
    // gọi Pigeon đúng hai lần: cờ backup, rồi đọc API Android. Nạp
    // `settings` không ghi nên không có `fsyncDirectory`.
    expect(pigeonCalls.map((c) => c.$1), [
      'excludeFromBackup',
      'androidSdkInt',
    ]);
    expect(pigeonCalls.first.$2, [pak]);
    expect(Directory(pak).existsSync(), isTrue);
    expect(staleTmp.existsSync(), isFalse);

    // main() nạp `settings` từ `pak/` đã bootstrap và áp vào app; chỉ nạp
    // thì không ghi lại file. API Android đi qua cùng PigeonPlatformPorts.
    final inside = tester.element(find.byType(ContentColumn));
    expect(Localizations.localeOf(inside).languageCode, 'vi');
    expect(CupertinoTheme.brightnessOf(inside), Brightness.dark);
    expect(settingsFile.readAsBytesSync(), settingsBytes);
    final pakApp = tester.widget<PakApp>(find.byType(PakApp));
    expect(pakApp.androidSdkInt, 28);

    // FR-1: máy mới (không có `vault/header`) → S1, khung đầu không màn chờ.
    // Bootstrap chỉ kiểm `header`: không ghi gì, không gọi Pigeon thêm. Máy
    // dev thiếu libsodium thì gate nhận `BootstrapUnavailable` (fail closed),
    // vẫn là S1.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      tester.widget<LoginScreen>(find.byType(LoginScreen)).hasAccount,
      isFalse,
    );
    expect(find.text('PAK Manager'), findsOneWidget);
    expect(find.text('Tạo tài khoản'), findsOneWidget);
    expect(Directory('$pak${sep}vault').listSync(), isEmpty);
    // Có libsodium (CI): main() nạp được blocklist từ asset và nối dịch vụ,
    // nên nút bật. Chỉ khi Sodium không khởi tạo được mới fail closed.
    expect(
      tester.widget<LoginScreen>(find.byType(LoginScreen)).unavailable,
      !_sodiumAvailable(),
    );

    // Đổi cài đặt rồi cho app ẩn: store ghi ngay qua `fileSync` của main(),
    // tức chính PigeonPlatformPorts (fsync thư mục `pak/`).
    final store = pakApp.settings;
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

  // Blocklist hỏng hoặc không nạp được → fail closed (AD-15, deferred 1.5):
  // S1 nút vô hiệu, không đọc/ghi vault. Máy thiếu libsodium thì Sodium lỗi
  // trước, kết quả vẫn phải là unavailable.
  final blocklistFailures = <String, ByteData? Function()>{
    'garbage_bytes': () =>
        ByteData.sublistView(Uint8List.fromList(List<int>.filled(64, 0x5A))),
    'load_fails': () => null,
  };
  blocklistFailures.forEach((name, reply) {
    testWidgets('ad15_ad11_broken_blocklist_fails_closed_$name', (
      tester,
    ) async {
      final savedDebugPrint = debugPrint;
      final savedFlutterOnError = FlutterError.onError;
      final savedPlatformOnError = PlatformDispatcher.instance.onError;
      final sep = Platform.pathSeparator;

      final sandbox = Directory.systemTemp.createTempSync('pak_blocklist_');
      addTearDown(() => sandbox.deleteSync(recursive: true));
      final vault = '${sandbox.path}${sep}pak${sep}vault';

      final messenger = tester.binding.defaultBinaryMessenger;
      const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
      messenger.setMockMethodCallHandler(pathProvider, (call) async {
        if (call.method == 'getApplicationSupportDirectory') {
          return sandbox.path;
        }
        throw MissingPluginException(call.method);
      });
      addTearDown(() => messenger.setMockMethodCallHandler(pathProvider, null));

      // Chỉ chặn asset blocklist; asset khác không được nạp lúc khởi động.
      final assetKeys = <String>[];
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(Uint8List.sublistView(message!));
        assetKeys.add(key);
        return key == app.blocklistAsset ? reply() : null;
      });
      addTearDown(
        () => messenger.setMockMessageHandler('flutter/assets', null),
      );

      const prefix = 'dev.flutter.pigeon.pak_manager.PlatformApi.';
      const replies = <String, Object?>{
        'bootId': '',
        'monotonicMs': 0,
        'excludeFromBackup': null,
        'fsyncDirectory': null,
        'androidSdkInt': 28,
      };
      for (final MapEntry(key: method, value: value) in replies.entries) {
        final channel = BasicMessageChannel<Object?>(
          '$prefix$method',
          PlatformApi.pigeonChannelCodec,
        );
        messenger.setMockDecodedMessageHandler<Object?>(
          channel,
          (message) async => [value],
        );
        addTearDown(
          () => messenger.setMockDecodedMessageHandler<Object?>(channel, null),
        );
      }

      app.main();
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        if (find.byType(CupertinoApp).evaluate().isNotEmpty) {
          break;
        }
      }

      debugPrint = savedDebugPrint;
      FlutterError.onError = savedFlutterOnError;
      PlatformDispatcher.instance.onError = savedPlatformOnError;

      if (_sodiumAvailable()) {
        // Có libsodium: lỗi đến từ đúng bước nạp blocklist.
        expect(assetKeys, contains(app.blocklistAsset));
      }
      final login = tester.widget<LoginScreen>(find.byType(LoginScreen));
      expect(login.hasAccount, isFalse);
      expect(login.unavailable, isTrue);
      expect(
        find.text("Can't open app data. Restart the app."),
        findsOneWidget,
      );
      expect(Directory(vault).existsSync(), isFalse);
    });
  });

  testWidgets('ad01_run_app_enables_edge_to_edge_without_blocking', (
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
      systemInfo: _FakeSystemInfo(35),
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
    final orientations = <Object?>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        orientations.add(call.arguments);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    // Màn hình điện thoại (390 × 844 logic).
    tester.view.display
      ..devicePixelRatio = 3
      ..size = const Size(1170, 2532);
    addTearDown(tester.view.display.reset);

    app.runPakApp(
      StorageBootstrap(directories: directories, backup: backup),
      fileSync: fileSync,
      systemInfo: _FakeSystemInfo(35),
      releaseMode: false,
    );
    await tester.pump();
    // Bootstrap chưa xong: chưa runApp, nhưng điện thoại đã khóa dọc (AD-1).
    expect(find.byType(CupertinoApp), findsNothing);
    expect(directories.calls, 1);
    expect(orientations, [
      ['DeviceOrientation.portraitUp'],
    ]);

    // Khởi động lỗi vẫn runApp (fail-closed ở tầng dữ liệu, không ở UI).
    directories.completer.completeError(StateError('không có thư mục'));
    await tester.pump();
    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(backup.calls, isEmpty);
    // Lưu trữ lỗi: settings chỉ ở RAM, không đọc/ghi file.
    expect(fileSync.calls, isEmpty);
    // Fail closed (story 1.2 → 1.6): S1 với nút vô hiệu và
    // `create.unavailable`; không có dịch vụ tài khoản để đọc/ghi vault.
    final login = tester.widget<LoginScreen>(find.byType(LoginScreen));
    expect(login.hasAccount, isFalse);
    expect(login.unavailable, isTrue);
    expect(find.text("Can't open app data. Restart the app."), findsOneWidget);
  });

  testWidgets('nfr13_run_app_passes_android_sdk_and_falls_back_to_0', (
    tester,
  ) async {
    app.runPakApp(
      _unavailableStorage(),
      fileSync: _RecordingFileSync(),
      systemInfo: _FakeSystemInfo(27),
      releaseMode: false,
    );
    await tester.pump();
    expect(tester.widget<PakApp>(find.byType(PakApp)).androidSdkInt, 27);

    // Đọc lỗi không chặn khởi động; `0` cho style an toàn nhất.
    app.runPakApp(
      _unavailableStorage(),
      fileSync: _RecordingFileSync(),
      systemInfo: _FakeSystemInfo(null),
      releaseMode: false,
    );
    await tester.pump();
    expect(tester.widget<PakApp>(find.byType(PakApp)).androidSdkInt, 0);
    expect(tester.takeException(), isNull);
  });
}

/// `true` khi libsodium nạp được trong môi trường test (CI có build hook;
/// máy dev Windows thiếu VS Build Tools thì không).
bool _sodiumAvailable() {
  try {
    SodiumSumoInit.init();
    return true;
  } on Object {
    return false;
  }
}

/// API Android giả; `null` thì ném như kênh Pigeon lỗi.
class _FakeSystemInfo implements SystemInfoPort {
  _FakeSystemInfo(this.sdkInt);

  final int? sdkInt;

  @override
  Future<int> androidSdkInt() async =>
      sdkInt ?? (throw PlatformException(code: 'unavailable'));
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
