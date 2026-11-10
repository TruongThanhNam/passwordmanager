import 'dart:async';
import 'dart:collection';

import 'package:sodium/sodium_sumo.dart';

import '../core/model/recent_entry.dart';
import '../core/model/vault_card.dart';

/// Kết quả của mọi method đọc/thao tác trên [VaultSession] (AD-6): phiên đã
/// khóa thì luôn là [SessionLocked], không có I/O.
sealed class SessionResult<T> {
  const SessionResult();
}

/// Phiên còn mở; [value] là kết quả thật.
final class SessionOk<T> extends SessionResult<T> {
  const SessionOk(this.value);

  final T value;

  /// Không lộ dữ liệu giải mã (AD-22).
  @override
  String toString() => 'SessionOk(<hidden>)';
}

/// Phiên đã khóa: thao tác không chạy.
final class SessionLocked<T> extends SessionResult<T> {
  const SessionLocked();

  @override
  String toString() => 'SessionLocked()';
}

/// Một thao tác trong hàng đợi tuần tự.
final class _QueuedOp<T> {
  _QueuedOp(this.op);

  final FutureOr<T> Function(SecureKey dek) op;
  final Completer<SessionResult<T>> completer = Completer<SessionResult<T>>();

  Future<void> start(SecureKey dek) async {
    try {
      completer.complete(SessionOk<T>(await op(dek)));
    } on Object catch (error, stack) {
      completer.completeError(error, stack);
    }
  }

  void cancel() => completer.complete(SessionLocked<T>());
}

/// Một phiên đã mở khóa (AD-6, AD-22): chủ duy nhất của DEK và dữ liệu giải
/// mã. Mỗi lần tạo tài khoản hoặc mở khóa sinh một instance mới.
///
/// Mọi thao tác dùng DEK đi qua hàng đợi tuần tự [run]. Sau [lock], mọi
/// method trả [SessionLocked] và không làm I/O. Chỉ `SessionController` gọi
/// [lock] (ngoài các nhánh hủy phiên chưa trao cho `SessionGate`).
final class VaultSession {
  VaultSession({
    required SecureKey this._dek,
    required List<VaultCard> cards,
    required List<RecentEntry> recent,
  }) : _cards = List<VaultCard>.unmodifiable(cards),
       _recent = List<RecentEntry>.unmodifiable(recent);

  SecureKey? _dek;
  List<VaultCard> _cards;
  List<RecentEntry> _recent;

  final Queue<_QueuedOp<Object?>> _queue = Queue<_QueuedOp<Object?>>();

  /// Thao tác đang chạy; `null` khi rảnh.
  Future<void>? _running;

  /// Số lời gọi [idle] đang giữ hàng đợi (op chưa chạy không được bắt đầu).
  int _holds = 0;

  /// `true` sau [lock]: DEK đã hủy, dữ liệu giải mã đã bỏ tham chiếu.
  bool get isLocked => _dek == null;

  /// Card đã giải mã.
  SessionResult<List<VaultCard>> readCards() =>
      isLocked ? const SessionLocked() : SessionOk(_cards);

  /// Mục Recent đã giải mã.
  SessionResult<List<RecentEntry>> readRecent() =>
      isLocked ? const SessionLocked() : SessionOk(_recent);

  /// Xếp [op] vào hàng đợi tuần tự; [op] nhận DEK khi tới lượt. Phiên đã
  /// khóa (lúc gọi hoặc lúc tới lượt) thì trả [SessionLocked], [op] không
  /// chạy. Lỗi của [op] được trả qua `Future` này, hàng đợi vẫn chạy tiếp.
  Future<SessionResult<T>> run<T>(FutureOr<T> Function(SecureKey dek) op) {
    if (isLocked) {
      return Future<SessionResult<T>>.value(SessionLocked<T>());
    }
    final queued = _QueuedOp<T>(op);
    _queue.add(queued);
    _pump();
    return queued.completer.future;
  }

  /// Chờ thao tác đang chạy (nếu có) xong. Trong lúc chờ, và cho tới hết
  /// lượt microtask hiện tại sau đó, op đã xếp hàng chưa được bắt đầu: người
  /// gọi (trình tự khóa AD-9) kịp [lock] để chúng trả [SessionLocked]. Không
  /// khóa thì hàng đợi chạy tiếp ở lượt event-loop kế.
  Future<void> idle() async {
    _holds++;
    try {
      while (_running != null) {
        await _running;
      }
    } finally {
      Timer.run(() {
        _holds--;
        _pump();
      });
    }
  }

  /// Không bắt đầu op nào nữa (op đang chạy vẫn chạy tiếp); op đã/sẽ xếp
  /// hàng chờ tới [lock] rồi trả [SessionLocked]. Trình tự khóa gọi ở bước
  /// đầu để hook chậm không mở đường cho op mới chạy với DEK.
  void holdQueue() => _holds++;

  void _pump() {
    if (_running != null || _holds > 0 || _queue.isEmpty) {
      return;
    }
    final dek = _dek;
    if (dek == null) {
      _cancelQueued();
      return;
    }
    final next = _queue.removeFirst();
    final running = next.start(dek);
    _running = running;
    unawaited(
      running.whenComplete(() {
        _running = null;
        _pump();
      }),
    );
  }

  void _cancelQueued() {
    while (_queue.isNotEmpty) {
      _queue.removeFirst().cancel();
    }
  }

  /// Hủy DEK (`SecureKey.dispose` ghi đè vùng nhớ khóa), bỏ mọi tham chiếu
  /// tới dữ liệu giải mã và trả [SessionLocked] cho mọi op chưa chạy. Gọi
  /// nhiều lần không lỗi.
  void lock() {
    final dek = _dek;
    _dek = null;
    _cards = const [];
    _recent = const [];
    _cancelQueued();
    try {
      dek?.dispose();
    } on Object {
      // Khóa đã hủy ở nơi khác: không còn gì để xóa.
    }
  }

  /// Không lộ DEK hay nội dung card (AD-22).
  @override
  String toString() => isLocked
      ? 'VaultSession(locked)'
      : 'VaultSession(cards: ${_cards.length}, recent: ${_recent.length})';
}
