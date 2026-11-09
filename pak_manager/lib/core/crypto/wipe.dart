import 'dart:typed_data';

/// Ghi đè 0 lên toàn bộ [bytes] (AD-22). Dùng ngay sau khi xong với mọi
/// buffer chứa bản rõ: JSON plaintext, DEK đã mở bọc, bản sao mật khẩu.
void wipe(Uint8List bytes) => bytes.fillRange(0, bytes.length, 0);
