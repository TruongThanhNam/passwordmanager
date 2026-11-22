/// Số lần nhập sai tối đa; lần sai thứ [maxAttempts] chặn đăng nhập (FR-4).
const int maxAttempts = 10;

/// Từ lần sai thứ [waitFromAttempt] phải chờ [waitDuration] (FR-4).
const int waitFromAttempt = 5;

/// Thời gian chờ sau mỗi lần sai từ thứ [waitFromAttempt] tới thứ
/// `maxAttempts - 1` (FR-4).
const Duration waitDuration = Duration(minutes: 30);

/// Trạng thái của file `guard` (AD-8, AD-20). Bất biến; mọi chuyển trạng
/// thái là hàm thuần trả bản mới.
///
/// Mốc chờ ([waitBootId], [waitStartMono]) đo bằng `ClockPort.bootId` và
/// `ClockPort.monotonicMs` (AD-9); không hàm nào ở đây đọc đồng hồ, người gọi
/// truyền giá trị vào. [wiping] được giữ nguyên khi đếm; chỉ [withWiping] bật
/// nó và chỉ [initial] (qua `LockoutGuard.reset`) tắt nó.
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

  /// Đúng bằng [initial]: chưa sai lần nào, không mốc chờ, không đang xóa.
  bool get isInitial =>
      failCount == 0 && waitBootId == null && waitStartMono == null && !wiping;

  /// Số lần thử còn lại trước khi bị chặn.
  int get attemptsLeft => maxAttempts - failCount;

  /// Đã hết lượt: không cho thử nữa.
  bool get exhausted => failCount >= maxAttempts;

  /// [failCount] nằm trong khoảng phải chờ ([waitFromAttempt] tới
  /// `maxAttempts - 1`). Chỉ trong khoảng này mốc chờ có nghĩa.
  bool get inWaitRange =>
      failCount >= waitFromAttempt && failCount < maxAttempts;

  /// Trạng thái ghi xuống đĩa **trước** KDF: [failCount] + 1, chặn ở
  /// [maxAttempts]; các trường khác giữ nguyên.
  GuardState afterAttempt() => GuardState(
    failCount: failCount >= maxAttempts ? maxAttempts : failCount + 1,
    waitBootId: waitBootId,
    waitStartMono: waitStartMono,
    wiping: wiping,
  );

  /// Bản đánh dấu đang xóa dở (AD-21): [wiping] `true`, các trường khác giữ
  /// nguyên (kể cả [failCount]).
  GuardState withWiping() => GuardState(
    failCount: failCount,
    waitBootId: waitBootId,
    waitStartMono: waitStartMono,
    wiping: true,
  );

  /// Mật khẩu đúng (`kcv` khớp): [failCount] về 0 và xóa mốc chờ.
  GuardState afterSuccess() => GuardState(failCount: 0, wiping: wiping);

  /// Bản có mốc chờ = ([bootId], [mono]); các trường khác giữ nguyên.
  GuardState withWaitMark(String bootId, int mono) => GuardState(
    failCount: failCount,
    waitBootId: bootId,
    waitStartMono: mono,
    wiping: wiping,
  );

  /// Neo lại mốc chờ lúc khởi động hoặc khi đọc thời gian còn lại (AD-8 bước
  /// (2) rồi (3)): trong [inWaitRange] mà mốc thiếu hoặc nửa vời, `bootId`
  /// của mốc khác [bootId] hiện tại (máy đã khởi động lại), hoặc [nowMono]
  /// nhỏ hơn mốc (đồng hồ đơn điệu lùi) → mốc = bây giờ, tức chờ lại từ đầu.
  ///
  /// `null` = không cần đổi (ngoài [inWaitRange] hoặc mốc còn hợp lệ). Không
  /// bao giờ đặt mốc về trước mốc cũ trên cùng một lần khởi động, nên thời
  /// gian chờ chỉ có thể bị kéo dài, không bao giờ bị rút ngắn.
  GuardState? reanchored(String bootId, int nowMono) {
    if (!inWaitRange) {
      return null;
    }
    final markBoot = waitBootId;
    final markMono = waitStartMono;
    if (markBoot == null ||
        markMono == null ||
        markBoot != bootId ||
        nowMono < markMono) {
      return withWaitMark(bootId, nowMono);
    }
    return null;
  }

  /// Thời gian chờ còn lại tại [nowMono], luôn trong `[0, waitDuration]`.
  /// Ngoài [inWaitRange] → `Duration.zero`.
  ///
  /// Dùng sau [reanchored]. Mốc thiếu hoặc [nowMono] nhỏ hơn mốc (chưa neo
  /// lại) → [waitDuration], đúng giá trị sau khi neo lại (fail closed).
  Duration waitRemaining(int nowMono) {
    if (!inWaitRange) {
      return Duration.zero;
    }
    final markMono = waitStartMono;
    if (waitBootId == null || markMono == null || nowMono < markMono) {
      return waitDuration;
    }
    final elapsed = nowMono - markMono;
    final left = waitDuration.inMilliseconds - elapsed;
    return left <= 0 ? Duration.zero : Duration(milliseconds: left);
  }

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
