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

  group('runWithErrorPolicy', () {
    // Chạy body qua runWithErrorPolicy trong một zone bắt mọi print; khôi
    // phục handler sau đó. Trả về (dòng đã in, handler có bị thay không).
    (List<String>, bool, bool, bool) runCapturing({required bool releaseMode}) {
      final savedDebugPrint = debugPrint;
      final savedFlutterOnError = FlutterError.onError;
      final savedPlatformOnError = PlatformDispatcher.instance.onError;
      final printed = <String>[];
      try {
        runZoned(
          () => runWithErrorPolicy(() {
            print('print trong body'); // ignore: avoid_print
            debugPrint('debugPrint trong body');
          }, releaseMode: releaseMode),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => printed.add(line),
          ),
        );
        return (
          printed,
          !identical(debugPrint, savedDebugPrint),
          !identical(FlutterError.onError, savedFlutterOnError),
          !identical(PlatformDispatcher.instance.onError, savedPlatformOnError),
        );
      } finally {
        debugPrint = savedDebugPrint;
        FlutterError.onError = savedFlutterOnError;
        PlatformDispatcher.instance.onError = savedPlatformOnError;
      }
    }

    test('ad18_release_mode_silences_print_and_replaces_handlers', () {
      final (printed, debugPrintChanged, flutterChanged, platformChanged) =
          runCapturing(releaseMode: true);

      expect(printed, isEmpty);
      expect(debugPrintChanged, isTrue);
      expect(flutterChanged, isTrue);
      expect(platformChanged, isTrue);
    });

    test('ad18_debug_mode_passes_print_through_and_keeps_handlers', () {
      final (printed, debugPrintChanged, flutterChanged, platformChanged) =
          runCapturing(releaseMode: false);

      expect(printed, contains('print trong body'));
      expect(debugPrintChanged, isFalse);
      expect(flutterChanged, isFalse);
      expect(platformChanged, isFalse);
    });
  });
}
