import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

/// Nguồn byte ngẫu nhiên duy nhất của app (AD-4). Code sản phẩm dùng
/// [SodiumRandomSource]; test thay bằng fake trả byte cố định.
abstract interface class RandomSource {
  /// [length] byte ngẫu nhiên an toàn mật mã.
  Uint8List bytes(int length);
}

/// [RandomSource] lấy từ `randombytes_buf` của libsodium.
final class SodiumRandomSource implements RandomSource {
  SodiumRandomSource(this._sodium);

  final SodiumSumo _sodium;

  @override
  Uint8List bytes(int length) => _sodium.randombytes.buf(length);
}

const String _hex = '0123456789abcdef';

/// UUID phiên bản 4 (RFC 9562) dạng chữ thường có gạch, ví dụ
/// `0f8fad5b-d9cb-469f-a165-70867728950e`. Lấy 16 byte từ [random], đặt
/// nibble version = 4 và variant = `10xx`.
String uuidV4(RandomSource random) {
  final b = random.bytes(16);
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final out = StringBuffer();
  for (var i = 0; i < 16; i++) {
    if (i == 4 || i == 6 || i == 8 || i == 10) {
      out.write('-');
    }
    out
      ..write(_hex[b[i] >> 4])
      ..write(_hex[b[i] & 0x0f]);
  }
  return out.toString();
}
