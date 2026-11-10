import 'dart:async';

import 'vault_session.dart';

/// Hook của một bước trong trình tự khóa; mặc định không làm gì.
typedef LockHook = Future<void> Function();

Future<void> _noop() async {}

/// Chủ của phiên đang mở (AD-9): nơi duy nhất gọi [VaultSession.lock] và giữ
/// epoch của cây UI.
///
/// Trình tự khóa: [flushDraft] → chặn hàng đợi → [awaitPendingWrites] →
/// [cancelUnstarted] → chờ [VaultSession.idle] → [VaultSession.lock] →
/// [clearClipboardIfOurs] (chỉ khi khóa ở tiền cảnh) → epoch++ → báo
/// listener. Bước nào chưa có tính năng thì hook rỗng (Epic 3/5/6 lấp).
///
/// Story 1.8 chưa có autolock/giới hạn phiên (1.9): không timer, không đồng
/// hồ.
final class SessionController {
  SessionController({
    this.flushDraft = _noop,
    this.awaitPendingWrites = _noop,
    this.cancelUnstarted = _noop,
    this.clearClipboardIfOurs = _noop,
  });

  final LockHook flushDraft;
  final LockHook awaitPendingWrites;
  final LockHook cancelUnstarted;
  final LockHook clearClipboardIfOurs;

  VaultSession? _session;
  int _epoch = 0;
  Future<void>? _locking;
  final List<void Function()> _listeners = [];

  /// Tăng mỗi lần vào phiên hoặc khóa.
  int get epoch => _epoch;

  /// Phiên đang mở; `null` khi đã khóa hoặc chưa đăng nhập.
  VaultSession? get session => _session;

  /// Kết quả `await` trên port mang epoch cũ thì bỏ (AD-9).
  bool isCurrent(int epoch) => epoch == _epoch;

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Nhận quyền sở hữu [session] (phiên mới từ tạo tài khoản/đăng nhập).
  /// Phiên cũ, nếu còn, bị khóa ngay.
  void enter(VaultSession session) {
    final previous = _session;
    _session = session;
    if (previous != null && !identical(previous, session)) {
      previous.lock();
    }
    _epoch++;
    _notify();
  }

  /// Chạy trình tự khóa. Gọi chồng trả cùng `Future`; không có phiên thì
  /// không làm gì. Lỗi trong hook bị nuốt: khóa luôn hoàn tất.
  Future<void> lock({bool foreground = true}) {
    final pending = _locking;
    if (pending != null) {
      return pending;
    }
    final session = _session;
    if (session == null) {
      return Future<void>.value();
    }
    final locking = _runLock(session, foreground: foreground);
    _locking = locking;
    return locking;
  }

  Future<void> _runLock(
    VaultSession session, {
    required bool foreground,
  }) async {
    try {
      // flushDraft có thể ghi qua `session.run`: chỉ chặn hàng đợi sau bước này.
      await _guard(flushDraft);
      session.holdQueue();
      await _guard(awaitPendingWrites);
      await _guard(cancelUnstarted);
      // Chờ op đang chạy ngay sát trước khi khóa (không await nào xen giữa):
      // `idle` chỉ giữ hàng đợi tới lượt event-loop kế.
      await _guard(session.idle);
    } finally {
      session.lock();
      if (identical(_session, session)) {
        _session = null;
      }
      if (foreground) {
        await _guard(clearClipboardIfOurs);
      }
      _epoch++;
      _locking = null;
      _notify();
    }
  }

  static Future<void> _guard(LockHook hook) async {
    try {
      await hook();
    } on Object {
      // AD-9: một bước lỗi không được chặn việc khóa.
    }
  }

  void _notify() {
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }

  /// Khóa đồng bộ khi chủ sở hữu bị gỡ (không chờ hook, không báo).
  void dispose() {
    _listeners.clear();
    final session = _session;
    _session = null;
    session?.lock();
  }
}
