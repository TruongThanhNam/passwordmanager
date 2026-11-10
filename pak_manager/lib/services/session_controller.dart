import 'dart:async';

import '../core/model/settings.dart';
import '../core/ports/clock_port.dart';
import 'vault_session.dart';

/// Hook của một bước trong trình tự khóa; mặc định không làm gì.
typedef LockHook = Future<void> Function();

/// Dựng `Timer` đánh thức (test thay bằng fake).
typedef TimerFactory = Timer Function(Duration duration, void Function() wake);

Timer _realTimer(Duration duration, void Function() wake) =>
    Timer(duration, wake);

Future<void> _noop() async {}

/// Chủ của phiên đang mở (AD-9): nơi duy nhất gọi [VaultSession.lock] và giữ
/// epoch của cây UI.
///
/// Trình tự khóa: [flushDraft] → chặn hàng đợi → [awaitPendingWrites] →
/// [cancelUnstarted] → chờ [VaultSession.idle] → [VaultSession.lock] →
/// [clearClipboardIfOurs] (chỉ khi khóa ở tiền cảnh) → epoch++ → báo
/// listener. Bước nào chưa có tính năng thì hook rỗng (Epic 3/5/6 lấp).
///
/// Tự khóa (FR-14/15, AD-8): hạn phiên = mốc [enter] + `sessionMin`, hạn
/// nền = mốc [enteredBackground] + `autolockMin`, cả hai đo bằng
/// [ClockPort.monotonicMs]. [evaluate] khóa khi một trong hai hạn đã qua;
/// `Timer` chỉ đánh thức [evaluate]. Không có [clock] thì không tự khóa.
final class SessionController {
  SessionController({
    this.flushDraft = _noop,
    this.awaitPendingWrites = _noop,
    this.cancelUnstarted = _noop,
    this.clearClipboardIfOurs = _noop,
    this.clock,
    this.limits = _defaultLimits,
    this.timerFactory = _realTimer,
  });

  static Settings _defaultLimits() => Settings.defaults;

  /// Nguồn sự thật duy nhất cho mọi hạn; `null` = không tự khóa.
  final ClockPort? clock;

  /// Cài đặt hiện tại; chỉ được chụp lúc bắt đầu một lần đếm.
  final Settings Function() limits;

  final TimerFactory timerFactory;

  final LockHook flushDraft;
  final LockHook awaitPendingWrites;
  final LockHook cancelUnstarted;
  final LockHook clearClipboardIfOurs;

  VaultSession? _session;
  int _epoch = 0;
  Future<void>? _locking;
  final List<void Function()> _listeners = [];

  /// Mốc vào phiên và hạn phiên (ms đơn điệu).
  int? _enteredAt;
  int? _sessionDeadline;

  /// Đang ở nền (đặt đồng bộ khi vào nền, xóa khi `resumed` không khóa).
  bool _inBackground = false;

  /// Tăng mỗi lần vào nền, để `resumed` cũ không xóa mốc nền mới.
  int _backgroundGen = 0;
  int? _backgroundAt;
  int? _autolockMs;
  Timer? _timer;

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
    _resetTiming();
    _epoch++;
    _notify();
    final clock = this.clock;
    if (clock != null) {
      unawaited(_startSession(clock, _epoch, limits().sessionMin));
    }
  }

  Future<void> _startSession(ClockPort clock, int epoch, int sessionMin) async {
    final int now;
    try {
      now = await clock.monotonicMs();
    } on Object {
      if (isCurrent(epoch)) {
        unawaited(lock(foreground: !_inBackground));
      }
      return;
    }
    if (!isCurrent(epoch) || _session == null) {
      return;
    }
    _enteredAt = now;
    _sessionDeadline = now + sessionMin * Duration.millisecondsPerMinute;
    _schedule(now);
  }

  /// App vừa vào nền (lần đầu `hidden`/`paused` sau `resumed`): chụp
  /// `autolockMin` hiện tại và mốc nền, hẹn timer.
  void enteredBackground() {
    final clock = this.clock;
    if (clock == null || _session == null) {
      return;
    }
    _inBackground = true;
    final gen = ++_backgroundGen;
    final autolockMin = limits().autolockMin;
    unawaited(_markBackground(clock, _epoch, gen, autolockMin));
  }

  Future<void> _markBackground(
    ClockPort clock,
    int epoch,
    int gen,
    int autolockMin,
  ) async {
    final int now;
    try {
      now = await clock.monotonicMs();
    } on Object {
      if (isCurrent(epoch)) {
        unawaited(lock(foreground: false));
      }
      return;
    }
    if (!isCurrent(epoch) || gen != _backgroundGen || _session == null) {
      return;
    }
    _backgroundAt = now;
    _autolockMs = autolockMin * Duration.millisecondsPerMinute;
    _schedule(now);
  }

  /// Khóa nếu hạn phiên hoặc hạn nền đã qua; chưa thì hẹn lại timer theo
  /// phần còn lại. [resumed] = gọi khi app trở lại tiền cảnh: không khóa
  /// thì xóa mốc nền. Clock lùi hoặc lỗi → khóa (fail closed). Trả `true`
  /// nếu đã khởi động khóa.
  Future<bool> evaluate({bool foreground = true, bool resumed = false}) async {
    final clock = this.clock;
    if (clock == null || _session == null) {
      return false;
    }
    final epoch = _epoch;
    final gen = _backgroundGen;
    final int now;
    try {
      now = await clock.monotonicMs();
    } on Object {
      if (!isCurrent(epoch)) {
        return false;
      }
      unawaited(lock(foreground: foreground));
      return true;
    }
    if (!isCurrent(epoch) || _session == null) {
      return false;
    }
    if (_expired(now)) {
      unawaited(lock(foreground: foreground));
      return true;
    }
    if (resumed && gen == _backgroundGen) {
      // Vô hiệu `_markBackground` còn treo để nó không ghi mốc cũ.
      _backgroundGen++;
      _inBackground = false;
      _backgroundAt = null;
      _autolockMs = null;
    }
    _schedule(now);
    return false;
  }

  bool _expired(int now) {
    final enteredAt = _enteredAt;
    if (enteredAt != null && now < enteredAt) {
      return true;
    }
    final deadline = _sessionDeadline;
    if (deadline != null && now >= deadline) {
      return true;
    }
    final backgroundAt = _backgroundAt;
    final autolockMs = _autolockMs;
    if (backgroundAt != null && autolockMs != null) {
      if (now < backgroundAt || now - backgroundAt >= autolockMs) {
        return true;
      }
    }
    return false;
  }

  /// Hẹn timer tới hạn gần nhất tính từ [now]; timer chỉ gọi [evaluate].
  void _schedule(int now) {
    _timer?.cancel();
    _timer = null;
    int? remaining;
    final deadline = _sessionDeadline;
    if (deadline != null) {
      remaining = deadline - now;
    }
    final backgroundAt = _backgroundAt;
    final autolockMs = _autolockMs;
    if (backgroundAt != null && autolockMs != null) {
      final left = backgroundAt + autolockMs - now;
      remaining = remaining == null || left < remaining ? left : remaining;
    }
    if (remaining == null) {
      return;
    }
    _timer = timerFactory(
      Duration(milliseconds: remaining < 0 ? 0 : remaining),
      () => unawaited(evaluate(foreground: !_inBackground)),
    );
  }

  void _resetTiming() {
    _timer?.cancel();
    _timer = null;
    _enteredAt = null;
    _sessionDeadline = null;
    _inBackground = false;
    _backgroundGen++;
    _backgroundAt = null;
    _autolockMs = null;
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
    _timer?.cancel();
    _timer = null;
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
        _resetTiming();
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
    _resetTiming();
    _listeners.clear();
    final session = _session;
    _session = null;
    session?.lock();
  }
}
