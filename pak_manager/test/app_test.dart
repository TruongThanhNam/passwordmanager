import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/main.dart' as app;

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

    app.main();
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
}
