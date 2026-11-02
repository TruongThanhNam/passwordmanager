import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/core/ports/app_directory_port.dart';
import 'package:pak_manager/core/ports/backup_port.dart';
import 'package:pak_manager/main.dart' as app;
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
