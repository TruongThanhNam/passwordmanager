import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import 'kdf.dart';

/// Hàm sinh KEK; production dùng [kekDeriver], test truyền fake.
typedef KekDeriver = Future<SecureKey?> Function(
  Uint8List password,
  Uint8List salt,
  KdfParams params,
);

/// Kết quả hiệu chỉnh: tham số đã chọn và KEK của lần chạy cuối (sinh từ
/// đúng mật khẩu và salt thật, dùng luôn cho tài khoản).
typedef CalibratedKek = ({KdfParams params, SecureKey kek});

/// [KekDeriver] mặc định: [deriveKek] trên [sodium].
KekDeriver kekDeriver(SodiumSumo sodium) =>
    (password, salt, params) => deriveKek(sodium, password, salt, params);

/// Thời gian mục tiêu và trần của một lần mở khóa (NFR, AD-4).
const int _targetMs = 1000;
const int _acceptLowMs = 500;
const int _acceptHighMs = 1500;
const int _ceilingMs = 2000;
const int _maxRuns = 3;

/// Hiệu chỉnh Argon2id trên máy (AD-4): mục tiêu ~1 giây, trần 2 giây.
///
/// 1. Probe [KdfParams.start] → T. Nhận nếu 500 ≤ T ≤ 1500 ms.
/// 2. f = 1000/T. f > 1: tăng t (tối đa 10), giữ 64 MiB. f < 1: giảm t
///    rồi m (không dưới sàn). Chạy lại → T'.
/// 3. Nhận nếu T' ≤ 2000 ms hoặc đã ở sàn; ngược lại giảm thêm một lần và
///    nhận kết quả dù chậm. Tối đa 3 lần chạy.
///
/// Trả `null` khi một lần KDF bất kỳ lỗi. Mọi KEK không trả về đều bị
/// `dispose`. [nowMs] mặc định đo bằng `Stopwatch`.
Future<CalibratedKek?> calibrateVaultKdf({
  required Uint8List password,
  required Uint8List salt,
  required KekDeriver derive,
  int Function()? nowMs,
}) async {
  final stopwatch = Stopwatch()..start();
  final clock = nowMs ?? () => stopwatch.elapsedMilliseconds;
  var params = KdfParams.start;
  for (var run = 1; ; run++) {
    final startedAt = clock();
    final SecureKey? kek;
    try {
      kek = await derive(password, salt, params);
    } on Object {
      return null;
    }
    if (kek == null) {
      return null;
    }
    final elapsed = clock() - startedAt;
    final accept = switch (run) {
      1 => elapsed >= _acceptLowMs && elapsed <= _acceptHighMs,
      _ =>
        run >= _maxRuns || elapsed <= _ceilingMs || params == KdfParams.floor,
    };
    if (accept) {
      return (params: params, kek: kek);
    }
    kek.dispose();
    params = run == 1
        ? _rescale(params, elapsed)
        : _reduce(params, _targetMs / elapsed);
  }
}

/// Bước 2: f = 1000/T. f > 1 thì tăng t (tối đa 10), giữ nguyên m vì máy
/// yếu dễ hết bộ nhớ; f < 1 thì [_reduce].
KdfParams _rescale(KdfParams current, int elapsedMs) {
  if (elapsedMs <= 0) {
    return KdfParams(KdfParams.opsMax, current.memLimitBytes);
  }
  final f = _targetMs / elapsedMs;
  if (f < 1) {
    return _reduce(current, f);
  }
  final ops = (current.opsLimit * f).round();
  return KdfParams(
    ops > KdfParams.opsMax ? KdfParams.opsMax : ops,
    current.memLimitBytes,
  );
}

/// Giảm chi phí (∝ t·m) theo hệ số f < 1: t = max(2, floor(t·f)), phần
/// còn lại dồn vào m = max(19 MiB, floor(m·t·f/t')) làm tròn xuống theo MiB.
KdfParams _reduce(KdfParams current, double f) {
  final scaled = current.opsLimit * f;
  final floored = scaled.floor();
  final ops = floored < KdfParams.opsMin ? KdfParams.opsMin : floored;
  final mem = (current.memLimitBytes ~/ mib * scaled / ops).floor() * mib;
  return KdfParams(
    ops,
    mem < KdfParams.memMinBytes
        ? KdfParams.memMinBytes
        : (mem > KdfParams.memMaxBytes ? KdfParams.memMaxBytes : mem),
  );
}
