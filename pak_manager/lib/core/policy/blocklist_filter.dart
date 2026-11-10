import 'dart:typed_data';

/// Bloom filter chứa các mật khẩu phổ biến (AD-15), đọc từ
/// `assets/blocklist.bloom`. Định dạng mô tả trong
/// `assets/blocklist.FORMAT.md`; asset sinh bằng
/// `tool/blocklist/build_blocklist.dart`.
///
/// Nạp asset (`rootBundle`) và dựng provider là việc của tầng trên; lớp này chỉ
/// nhận byte đã đọc.
final class BlocklistFilter {
  BlocklistFilter._(this._bits, this._mBits, this._k, this._seed);

  /// Độ dài phần header cố định, tính bằng byte.
  static const int headerLength = 20;

  /// Phiên bản định dạng duy nhất được hỗ trợ.
  static const int formatVersion = 1;

  /// Hằng trộn seed cho hàm băm thứ hai (`h2`).
  static const int seedMix = 0x9E3779B9;

  static const List<int> _magic = [0x50, 0x41, 0x4B, 0x42]; // "PAKB"

  final Uint8List _bits;
  final int _mBits;
  final int _k;
  final int _seed;

  /// Đọc [bytes] theo định dạng `PAKB` v1. Trả `null` (không ném) khi dữ liệu
  /// rỗng, sai magic/version, `k` = 0, `mBits` = 0, trường dự trữ khác 0 hoặc
  /// độ dài mảng bit không khớp header.
  static BlocklistFilter? parse(Uint8List bytes) {
    if (bytes.length < headerLength) {
      return null;
    }
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) {
        return null;
      }
    }
    final view = ByteData.sublistView(bytes);
    final version = view.getUint8(4);
    final k = view.getUint8(5);
    final reserved = view.getUint16(6, Endian.little);
    final mBits = view.getUint32(8, Endian.little);
    final seed = view.getUint32(16, Endian.little);
    if (version != formatVersion || k == 0 || reserved != 0 || mBits == 0) {
      return null;
    }
    final bitBytes = (mBits + 7) >> 3;
    if (bytes.length != headerLength + bitBytes) {
      return null;
    }
    // Sao chép để filter không phụ thuộc vào buffer của người gọi.
    final bits = Uint8List.fromList(Uint8List.sublistView(bytes, headerLength));
    return BlocklistFilter._(bits, mBits, k, seed);
  }

  /// `true` nếu [lowerAscii] có thể nằm trong blocklist (có thể dương tính
  /// giả, không bao giờ âm tính giả). Người gọi phải chuyển chữ thường trước;
  /// chuỗi có ký tự ngoài ASCII luôn trả `false` vì blocklist chỉ chứa ASCII.
  bool contains(String lowerAscii) {
    final units = lowerAscii.codeUnits;
    final data = Uint8List(units.length);
    try {
      for (var i = 0; i < units.length; i++) {
        final c = units[i];
        if (c > 0x7F) {
          return false;
        }
        data[i] = c;
      }
      final h1 = murmur3X86x32(data, _seed);
      final h2 = murmur3X86x32(data, _seed ^ seedMix) | 1;
      for (var j = 0; j < _k; j++) {
        // h1, h2 < 2^32 và j < 256 nên tổng < 2^41: không tràn int 64-bit.
        final index = (h1 + j * h2) % _mBits;
        if (_bits[index >> 3] & (1 << (index & 7)) == 0) {
          return false;
        }
      }
      return true;
    } finally {
      // AD-22: ghi đè 0 lên byte bản rõ ngay sau khi dùng, trên mọi đường ra.
      data.fillRange(0, data.length, 0);
    }
  }
}

const int _mask32 = 0xFFFFFFFF;

/// Nhân hai số 32-bit không dấu, lấy 32 bit thấp, không phụ thuộc phép nhân
/// tràn của nền tảng.
int _mul32(int a, int b) {
  final lo = (a & 0xFFFF) * b;
  final hi = (((a >>> 16) * b) & 0xFFFF) << 16;
  return (lo + hi) & _mask32;
}

int _rotl32(int x, int r) => ((x << r) | (x >>> (32 - r))) & _mask32;

/// MurmurHash3 x86_32 (Austin Appleby, public domain) trên [data] với [seed]
/// 32-bit; trả giá trị không dấu trong [0, 2^32).
int murmur3X86x32(Uint8List data, int seed) {
  const c1 = 0xCC9E2D51;
  const c2 = 0x1B873593;
  final length = data.length;
  final nBlocks = length >> 2;
  var h = seed & _mask32;

  for (var i = 0; i < nBlocks; i++) {
    final o = i << 2;
    var k =
        data[o] |
        (data[o + 1] << 8) |
        (data[o + 2] << 16) |
        (data[o + 3] << 24);
    k = _mul32(k, c1);
    k = _rotl32(k, 15);
    k = _mul32(k, c2);
    h ^= k;
    h = _rotl32(h, 13);
    h = (_mul32(h, 5) + 0xE6546B64) & _mask32;
  }

  final tail = nBlocks << 2;
  var k1 = 0;
  switch (length & 3) {
    case 3:
      k1 ^= data[tail + 2] << 16;
      k1 ^= data[tail + 1] << 8;
      k1 ^= data[tail];
    case 2:
      k1 ^= data[tail + 1] << 8;
      k1 ^= data[tail];
    case 1:
      k1 ^= data[tail];
  }
  if (length & 3 != 0) {
    k1 = _mul32(k1, c1);
    k1 = _rotl32(k1, 15);
    k1 = _mul32(k1, c2);
    h ^= k1;
  }

  h ^= length & _mask32;
  h ^= h >>> 16;
  h = _mul32(h, 0x85EBCA6B);
  h ^= h >>> 13;
  h = _mul32(h, 0xC2B2AE35);
  h ^= h >>> 16;
  return h;
}
