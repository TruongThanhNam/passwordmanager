/// Nguồn thời gian duy nhất cho mọi hạn khóa (AD-8). Không dùng `Stopwatch`
/// hay `DateTime.now()` làm nguồn sự thật.
abstract interface class ClockPort {
  /// Đồng hồ đơn điệu tính cả lúc máy ngủ, đơn vị ms.
  Future<int> monotonicMs();

  /// Định danh lần khởi động máy; `""` khi không đọc được. `bootId` đổi hoặc
  /// [monotonicMs] lùi nghĩa là máy đã khởi động lại.
  Future<String> bootId();
}
