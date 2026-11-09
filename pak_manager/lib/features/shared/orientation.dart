import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:flutter/services.dart';

/// Cạnh ngắn (logical px) từ ngưỡng này trở lên là tablet: ngưỡng `sw600dp`
/// của Android; mọi iPhone đều < 500.
const double tabletShortestSide = 600;

const _phone = [DeviceOrientation.portraitUp];
const _tablet = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Hướng được phép cho màn hình (display) có kích thước logic [logical]
/// (AD-1, UX-DR49): điện thoại chỉ dọc, tablet mọi hướng.
///
/// Trả `null` khi chưa có kích thước (size rỗng hoặc không hữu hạn): chưa
/// khóa, chờ metrics.
List<DeviceOrientation>? preferredOrientationsFor(Size logical) {
  if (logical.isEmpty || !logical.isFinite) {
    return null;
  }
  return logical.shortestSide < tabletShortestSide ? _phone : _tablet;
}

/// Áp chính sách hướng theo kích thước **màn hình** của [view] (không theo
/// cửa sổ, nên tablet chạy split-screen vẫn là tablet). Không bao giờ ném:
/// lỗi của `SystemChrome` bị nuốt.
void applyOrientationPolicy(FlutterView view) {
  try {
    final display = view.display;
    final ratio = display.devicePixelRatio;
    if (!(ratio > 0)) {
      return;
    }
    final orientations = preferredOrientationsFor(display.size / ratio);
    if (orientations == null) {
      return;
    }
    unawaited(
      SystemChrome.setPreferredOrientations(orientations)
          .catchError((Object _) {}),
    );
  } on Object {
    // Không khóa được hướng thì giữ mặc định của hệ thống; không chặn app.
  }
}
