/// Một mục trong file `recent` (AD-20): mật khẩu generator đã sinh. Bất
/// biến.
///
/// Chứa bí mật: [toString] chỉ lộ [recordedAt] (AD-22).
final class RecentEntry {
  const RecentEntry({required this.password, required this.recordedAt});

  final String password;

  /// UTC epoch ms.
  final int recordedAt;

  @override
  bool operator ==(Object other) =>
      other is RecentEntry &&
      other.password == password &&
      other.recordedAt == recordedAt;

  @override
  int get hashCode => Object.hash(password, recordedAt);

  @override
  String toString() => 'RecentEntry(recordedAt: $recordedAt)';
}
