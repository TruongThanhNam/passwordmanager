import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/features/shared/orientation.dart';

const _all = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Ghi lại mọi lời gọi `SystemChrome.setPreferredOrientations`.
List<List<Object?>> _recordOrientationCalls(
  WidgetTester tester, {
  bool fail = false,
}) {
  final calls = <List<Object?>>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'SystemChrome.setPreferredOrientations') {
      calls.add(call.arguments as List<Object?>);
      if (fail) {
        throw PlatformException(code: 'unavailable');
      }
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}

void _setDisplay(WidgetTester tester, Size physical, double ratio) {
  tester.view.display
    ..devicePixelRatio = ratio
    ..size = physical;
  addTearDown(tester.view.display.reset);
}

void main() {
  group('preferredOrientationsFor', () {
    test('ad01_phone_is_portrait_only', () {
      expect(preferredOrientationsFor(const Size(390, 844)), [
        DeviceOrientation.portraitUp,
      ]);
      // Điện thoại đang nằm ngang vẫn là điện thoại.
      expect(preferredOrientationsFor(const Size(844, 390)), [
        DeviceOrientation.portraitUp,
      ]);
      expect(preferredOrientationsFor(const Size(599.9, 960)), [
        DeviceOrientation.portraitUp,
      ]);
    });

    test('ad01_tablet_allows_every_orientation', () {
      expect(preferredOrientationsFor(const Size(600, 960)), _all);
      expect(preferredOrientationsFor(const Size(1366, 1024)), _all);
    });

    test('ad01_empty_size_is_not_locked_yet', () {
      expect(preferredOrientationsFor(Size.zero), isNull);
      expect(preferredOrientationsFor(const Size(0, 800)), isNull);
      expect(preferredOrientationsFor(const Size(390, 0)), isNull);
      expect(preferredOrientationsFor(Size.infinite), isNull);
    });
  });

  group('applyOrientationPolicy', () {
    testWidgets('ad01_policy_uses_logical_display_size', (tester) async {
      final calls = _recordOrientationCalls(tester);

      // 1170×2532 @3x = 390×844: điện thoại.
      _setDisplay(tester, const Size(1170, 2532), 3);
      applyOrientationPolicy(tester.view);
      // 2048×2732 @2x = 1024×1366: tablet.
      _setDisplay(tester, const Size(2048, 2732), 2);
      applyOrientationPolicy(tester.view);
      await tester.pump();

      expect(calls, [
        ['DeviceOrientation.portraitUp'],
        [
          'DeviceOrientation.portraitUp',
          'DeviceOrientation.portraitDown',
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight',
        ],
      ]);
    });

    testWidgets('ad01_policy_follows_display_not_window', (tester) async {
      final calls = _recordOrientationCalls(tester);
      // Tablet chạy split-screen: cửa sổ hẹp nhưng màn hình vẫn là tablet.
      _setDisplay(tester, const Size(2048, 2732), 2);
      tester.view
        ..devicePixelRatio = 2
        ..physicalSize = const Size(640, 2732);
      addTearDown(tester.view.reset);

      applyOrientationPolicy(tester.view);
      await tester.pump();

      expect(calls.single, hasLength(4));
    });

    testWidgets('ad01_zero_display_size_waits_for_metrics', (tester) async {
      final calls = _recordOrientationCalls(tester);
      _setDisplay(tester, Size.zero, 3);

      applyOrientationPolicy(tester.view);
      await tester.pump();

      expect(calls, isEmpty);
    });

    testWidgets('ad01_system_chrome_errors_are_swallowed', (tester) async {
      final calls = _recordOrientationCalls(tester, fail: true);
      _setDisplay(tester, const Size(1170, 2532), 3);

      applyOrientationPolicy(tester.view);
      await tester.pump();

      expect(calls, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  });
}
