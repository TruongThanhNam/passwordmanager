import 'dart:async';

import 'package:flutter/foundation.dart';

/// Chạy [body] theo chính sách lỗi (AD-18).
///
/// Khi [releaseMode] là `true`: cài [installReleaseErrorPolicy] rồi chạy
/// [body] trong một zone nuốt mọi `print` (kể cả từ dependency). Khi `false`:
/// chạy [body] nguyên trạng.
void runWithErrorPolicy(void Function() body, {required bool releaseMode}) {
  if (!releaseMode) {
    body();
    return;
  }
  installReleaseErrorPolicy();
  runZoned(
    body,
    zoneSpecification: const ZoneSpecification(print: _swallowPrint),
  );
}

/// Chính sách lỗi cho bản release (AD-18): không in gì ra log.
///
/// - `debugPrint` thành no-op.
/// - `FlutterError.onError` nuốt lỗi framework.
/// - `PlatformDispatcher.instance.onError` nuốt lỗi async chưa bắt và trả
///   `true` (đã xử lý) để engine không in lại.
void installReleaseErrorPolicy() {
  debugPrint = _silentDebugPrint;
  FlutterError.onError = _swallowFlutterError;
  PlatformDispatcher.instance.onError = _swallowPlatformError;
}

void _swallowPrint(Zone self, ZoneDelegate parent, Zone zone, String line) {}

void _silentDebugPrint(String? message, {int? wrapWidth}) {}

void _swallowFlutterError(FlutterErrorDetails details) {}

bool _swallowPlatformError(Object error, StackTrace stack) => true;
