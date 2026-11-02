import 'package:flutter/foundation.dart';

/// Chính sách lỗi cho bản release (AD-18): không in gì ra log.
///
/// - `debugPrint` thành no-op.
/// - `FlutterError.onError` nuốt lỗi framework.
/// - `PlatformDispatcher.instance.onError` nuốt lỗi async chưa bắt và trả
///   `true` (đã xử lý) để engine không in lại.
///
/// `main()` chỉ gọi hàm này khi `kReleaseMode`.
void installReleaseErrorPolicy() {
  debugPrint = _silentDebugPrint;
  FlutterError.onError = _swallowFlutterError;
  PlatformDispatcher.instance.onError = _swallowPlatformError;
}

void _silentDebugPrint(String? message, {int? wrapWidth}) {}

void _swallowFlutterError(FlutterErrorDetails details) {}

bool _swallowPlatformError(Object error, StackTrace stack) => true;
