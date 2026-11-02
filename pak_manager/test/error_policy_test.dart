import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/error_policy.dart';

void main() {
  test('ad18_release_policy_prints_nothing_and_swallows_errors', () {
    final savedDebugPrint = debugPrint;
    final savedFlutterOnError = FlutterError.onError;
    final savedPlatformOnError = PlatformDispatcher.instance.onError;
    final printed = <String>[];
    try {
      runZoned(
        () {
          // Đối chứng: trước khi cài chính sách, debugPrint có in.
          debugPrint('control');

          installReleaseErrorPolicy();

          debugPrint('không được in');
          FlutterError.onError!(
            FlutterErrorDetails(exception: StateError('lỗi framework')),
          );
          final handled = PlatformDispatcher.instance.onError!(
            StateError('lỗi async chưa bắt'),
            StackTrace.current,
          );
          expect(handled, isTrue);
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );

      expect(printed, ['control']);
      expect(debugPrint, isNot(same(savedDebugPrint)));
      expect(FlutterError.onError, isNot(same(savedFlutterOnError)));
    } finally {
      debugPrint = savedDebugPrint;
      FlutterError.onError = savedFlutterOnError;
      PlatformDispatcher.instance.onError = savedPlatformOnError;
    }
  });
}
