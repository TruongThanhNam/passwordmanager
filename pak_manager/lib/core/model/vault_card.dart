/// Một card trong file `cards` (AD-20). Bất biến.
///
/// Chứa bí mật: [toString] chỉ lộ [id] và [createdAt] (AD-22).
final class VaultCard {
  const VaultCard({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.note,
    required this.createdAt,
  });

  /// UUIDv4 chữ thường.
  final String id;
  final String title;
  final String username;
  final String password;

  /// Note rỗng là `""`.
  final String note;

  /// UTC epoch ms.
  final int createdAt;

  @override
  bool operator ==(Object other) =>
      other is VaultCard &&
      other.id == id &&
      other.title == title &&
      other.username == username &&
      other.password == password &&
      other.note == note &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, title, username, password, note, createdAt);

  @override
  String toString() => 'VaultCard(id: $id, createdAt: $createdAt)';
}
