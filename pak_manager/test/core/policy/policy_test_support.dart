import 'dart:io';
import 'dart:typed_data';

import 'package:pak_manager/core/policy/blocklist_filter.dart';

/// Đường dẫn asset và mẫu (tính từ thư mục gốc package khi `flutter test`).
const blocklistAssetPath = 'assets/blocklist.bloom';
const blocklistSamplePath = 'test/fixtures/blocklist/sample.txt';

/// Vector chuẩn công khai của MurmurHash3 x86_32.
const murmurVectors = <(String, int, int)>[
  ('', 0, 0x00000000),
  ('', 1, 0x514E28B7),
  ('', 0xFFFFFFFF, 0x81F16F39),
  ('test', 0, 0xBA6BD213),
  ('Hello, world!', 1234, 0xFAF6CDB3),
  ('The quick brown fox jumps over the lazy dog', 0, 0x2E4FF723),
  // Phủ cả ba độ dài phần đuôi (1, 2, 3 byte).
  ('a', 0x9747B28C, 0x7FA09EA6),
  ('aa', 0x9747B28C, 0x5D211726),
  ('aaa', 0x9747B28C, 0x283E0130),
  ('aaaa', 0x9747B28C, 0x5A97808A),
];

/// Byte `PAKB` v1 tự ghép cho test: [mBits] bit, mọi bit bằng [fill].
Uint8List fakeBloomBytes({
  int mBits = 64,
  int k = 3,
  int version = 1,
  int reserved = 0,
  int fill = 0x00,
  int seed = 0x50414B31,
}) {
  final out = Uint8List(BlocklistFilter.headerLength + ((mBits + 7) >> 3))
    ..setAll(0, 'PAKB'.codeUnits);
  ByteData.sublistView(out)
    ..setUint8(4, version)
    ..setUint8(5, k)
    ..setUint16(6, reserved, Endian.little)
    ..setUint32(8, mBits, Endian.little)
    ..setUint32(12, 0, Endian.little)
    ..setUint32(16, seed, Endian.little);
  out.fillRange(BlocklistFilter.headerLength, out.length, fill);
  return out;
}

/// Filter giả không chứa gì (mọi bit tắt).
BlocklistFilter emptyFilter() => BlocklistFilter.parse(fakeBloomBytes())!;

/// Filter giả chứa mọi chuỗi ASCII (mọi bit bật).
BlocklistFilter fullFilter() =>
    BlocklistFilter.parse(fakeBloomBytes(fill: 0xFF))!;

/// Filter thật từ asset đã commit.
BlocklistFilter assetFilter() =>
    BlocklistFilter.parse(File(blocklistAssetPath).readAsBytesSync())!;

/// 500 dòng mẫu sinh bởi `tool/blocklist/build_blocklist.dart`. Không trim:
/// dòng có thể bắt đầu/kết thúc bằng khoảng trắng.
List<String> blocklistSample() {
  final text = File(blocklistSamplePath).readAsStringSync();
  final lines = text.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

/// Bộ sinh số giả ngẫu nhiên tất định (xorshift32) cho test; không dùng
/// `dart:math Random`.
final class Xorshift32 {
  Xorshift32(this._state);

  int _state;

  int next() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >>> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    return _state = x & 0xFFFFFFFF;
  }

  /// Chuỗi ASCII in được (0x20–0x7E) dài [length].
  String printableAscii(int length) => String.fromCharCodes([
    for (var i = 0; i < length; i++) 0x20 + next() % 95,
  ]);
}
