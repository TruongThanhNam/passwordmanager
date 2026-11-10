import 'package:sodium/sodium_sumo.dart';

import '../core/model/recent_entry.dart';
import '../core/model/vault_card.dart';

/// Một phiên đã mở khóa (AD-6, AD-22): chủ duy nhất của DEK và dữ liệu giải
/// mã. Mỗi lần tạo tài khoản hoặc mở khóa sinh một instance mới.
///
/// Story 1.6 chỉ có phần tối thiểu: giữ DEK, `cards`, `recent` và [dispose].
/// Hàng đợi I/O tuần tự và `lock()` (mọi method trả `locked`) thuộc story
/// 1.8.
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

  /// `true` sau [dispose]: DEK đã hủy, dữ liệu giải mã đã bỏ tham chiếu.
  bool get isDisposed => _dek == null;

  /// Card đã giải mã; rỗng sau [dispose].
  List<VaultCard> get cards => _cards;

  /// Mục Recent đã giải mã; rỗng sau [dispose].
  List<RecentEntry> get recent => _recent;

  /// Hủy DEK (`SecureKey.dispose` ghi đè vùng nhớ khóa) và bỏ mọi tham chiếu
  /// tới dữ liệu giải mã. Gọi nhiều lần không lỗi.
  void dispose() {
    final dek = _dek;
    _dek = null;
    _cards = const [];
    _recent = const [];
    try {
      dek?.dispose();
    } on Object {
      // Khóa đã hủy ở nơi khác: không còn gì để xóa.
    }
  }

  /// Không lộ DEK hay nội dung card (AD-22).
  @override
  String toString() => isDisposed
      ? 'VaultSession(disposed)'
      : 'VaultSession(cards: ${_cards.length}, recent: ${_recent.length})';
}
