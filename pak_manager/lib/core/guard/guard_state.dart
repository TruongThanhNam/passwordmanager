/// Số lần nhập sai tối đa; lần sai thứ [maxAttempts] chặn đăng nhập (FR-4).
const int maxAttempts = 10;

/// Từ lần sai thứ [waitFromAttempt] phải chờ [waitDuration] (FR-4). Story
/// 2.2 dùng.
const int waitFromAttempt = 5;

/// Thời gian chờ sau mỗi lần sai từ thứ [waitFromAttempt] (FR-4). Story 2.2
/// dùng.
const Duration waitDuration = Duration(minutes: 30);

/// Trạng thái của file `guard` (AD-8, AD-20). Bất biến; mọi chuyển trạng
/// thái là hàm thuần trả bản mới.
///
/// Story 2.1 chỉ đổi [failCount]; [waitBootId], [waitStartMono] (mốc chờ,
/// story 2.2) và [wiping] (story 2.3) được giữ nguyên khi đếm.
final class GuardState {
  const GuardState({
    required this.failCount,
    this.waitBootId,
    this.waitStartMono,
    this.wiping = false,
  });

  /// Chưa sai lần nào, không mốc chờ, không đang xóa.
  static const initial = GuardState(failCount: 0);

  /// Số lần sai liên tiếp, trong khoảng 0–[maxAttempts].
  final int failCount;

  /// `bootId` lúc đặt mốc chờ; `null` = không có mốc.
  final String? waitBootId;

  /// `ClockPort.monotonicMs` lúc đặt mốc chờ; `null` = không có mốc.
  final int? waitStartMono;

  /// Đang xóa dữ liệu dở dang (AD-21).
  final bool wiping;

  /// Số lần thử còn lại trước khi bị chặn.
  int get attemptsLeft => maxAttempts - failCount;

  /// Đã hết lượt: không cho thử nữa.
  bool get exhausted => failCount >= maxAttempts;

  /// Trạng thái ghi xuống đĩa **trước** KDF: [failCount] + 1, chặn ở
  /// [maxAttempts]; các trường khác giữ nguyên.
  GuardState afterAttempt() => GuardState(
    failCount: failCount >= maxAttempts ? maxAttempts : failCount + 1,
    waitBootId: waitBootId,
    waitStartMono: waitStartMono,
    wiping: wiping,
  );

  /// Mật khẩu đúng (`kcv` khớp): [failCount] về 0 và xóa mốc chờ.
  GuardState afterSuccess() => GuardState(failCount: 0, wiping: wiping);

  @override
  bool operator ==(Object other) =>
      other is GuardState &&
      other.failCount == failCount &&
      other.waitBootId == waitBootId &&
      other.waitStartMono == waitStartMono &&
      other.wiping == wiping;

  @override
  int get hashCode => Object.hash(failCount, waitBootId, waitStartMono, wiping);

  @override
  String toString() =>
      'GuardState(failCount: $failCount, waitBootId: $waitBootId, '
      'waitStartMono: $waitStartMono, wiping: $wiping)';
}
