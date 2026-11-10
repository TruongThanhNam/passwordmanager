// Sinh blocklist mật khẩu phổ biến (AD-15):
//   assets/blocklist.bloom          Bloom filter định dạng `PAKB` v1
//   assets/blocklist.FORMAT.md      mô tả định dạng, tham số và nguồn
//   test/fixtures/blocklist/sample.txt  500 mục mẫu chọn tất định
//
// Nguồn (repo, commit ghim, đường dẫn) đọc từ tool/blocklist/SOURCE. Chỉ giữ
// dòng ASCII in được (0x20–0x7E) dài 15–128 sau khi bỏ `\r` cuối dòng, chuyển
// chữ thường, khử trùng, sắp xếp. Tất định: cùng nguồn → cùng byte.
//
// Cố ý không import `lib/` của app: script tự cài MurmurHash3 và Bloom theo
// đặc tả để test bắt được lỗi của `BlocklistFilter` trong app.
//
// Script này là công cụ của dev, có gọi mạng; CI không chạy nó (asset được
// commit). Lỗi mạng/định dạng hoặc asset vượt 2 MiB → exit ≠ 0 và không ghi đè
// file nào.
//
// Chạy trong pak_manager/ (chỉ cần Dart SDK, không qua build hook của
// `sodium`, nên chạy được trên Windows không có Visual Studio):
//   dart tool/blocklist/build_blocklist.dart
// `dart run tool/blocklist/build_blocklist.dart` cũng chạy được ở nơi build hook
// của `sodium` build được.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const sourcePath = 'tool/blocklist/SOURCE';
const bloomPath = 'assets/blocklist.bloom';
const formatPath = 'assets/blocklist.FORMAT.md';
const samplePath = 'test/fixtures/blocklist/sample.txt';

/// Độ dài chấp nhận (khớp `PasswordPolicy.minLength`/`maxLength`).
const minEntryLength = 15;
const maxEntryLength = 128;

/// Tham số Bloom theo spec story 1.5.
const falsePositiveRate = 0.001;
const hashCount = 10;
const bloomSeed = 0x50414B31; // "PAK1"
const seedMix = 0x9E3779B9;
const formatVersion = 1;
const headerLength = 20;
const maxAssetBytes = 2 * 1024 * 1024;
const sampleSize = 500;

// ---------------------------------------------------------------------------
// SOURCE

/// Nội dung đã đọc từ `SOURCE`.
final class BlocklistSource {
  BlocklistSource(this.repo, this.commit, this.license, this.paths);

  final String repo;
  final String commit;
  final String license;
  final List<String> paths;

  Uri urlFor(String path) =>
      Uri.parse('https://raw.githubusercontent.com/$repo/$commit/$path');
}

/// Đọc nội dung file `SOURCE`. Ném [FormatException] nếu thiếu khóa, khóa lạ,
/// commit không phải SHA-1 40 ký tự hex hoặc không có `path`.
BlocklistSource parseSource(String text) {
  String? repo;
  String? commit;
  String? license;
  final paths = <String>[];
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final colon = line.indexOf(':');
    if (colon <= 0) {
      throw FormatException('SOURCE: dòng không hợp lệ: $line');
    }
    final key = line.substring(0, colon).trim();
    final value = line.substring(colon + 1).trim();
    switch (key) {
      case 'repo':
        repo = value;
      case 'commit':
        commit = value;
      case 'license':
        license = value;
      case 'path':
        paths.add(value);
      default:
        throw FormatException('SOURCE: khóa lạ "$key"');
    }
  }
  if (repo == null || !RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(repo)) {
    throw const FormatException('SOURCE: thiếu hoặc sai "repo"');
  }
  if (commit == null || !RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
    throw const FormatException('SOURCE: thiếu hoặc sai "commit"');
  }
  if (license == null || license.isEmpty) {
    throw const FormatException('SOURCE: thiếu "license"');
  }
  if (paths.isEmpty) {
    throw const FormatException('SOURCE: không có "path"');
  }
  return BlocklistSource(repo, commit, license, paths);
}

// ---------------------------------------------------------------------------
// Lọc dòng

/// Thêm vào [out] mọi dòng hợp lệ của [data] (tách theo `\n`, bỏ một `\r`
/// cuối dòng), đã chuyển chữ thường. Trả số dòng hợp lệ (trước khử trùng).
int collectEntries(Uint8List data, Set<String> out) {
  var accepted = 0;
  var start = 0;
  final length = data.length;
  while (start < length) {
    var end = start;
    while (end < length && data[end] != 0x0A) {
      end++;
    }
    final next = end + 1;
    if (end > start && data[end - 1] == 0x0D) {
      end--;
    }
    final entry = normalizeEntry(data, start, end);
    if (entry != null) {
      out.add(entry);
      accepted++;
    }
    start = next;
  }
  return accepted;
}

/// Bản chữ thường của `data[start, end)` nếu đó là ASCII in được dài
/// [minEntryLength]–[maxEntryLength]; ngược lại `null`.
String? normalizeEntry(Uint8List data, int start, int end) {
  final length = end - start;
  if (length < minEntryLength || length > maxEntryLength) {
    return null;
  }
  final units = Uint8List(length);
  for (var i = 0; i < length; i++) {
    final c = data[start + i];
    if (c < 0x20 || c > 0x7E) {
      return null;
    }
    units[i] = (c >= 0x41 && c <= 0x5A) ? c + 0x20 : c;
  }
  return String.fromCharCodes(units);
}

// ---------------------------------------------------------------------------
// Tar (ustar/pax, chỉ đọc)

/// Nội dung của file thường duy nhất trong [tar]. Bỏ qua mục không phải file
/// thường (thư mục, header pax/GNU). Ném [FormatException] nếu tar hỏng hoặc
/// số file thường khác 1.
Uint8List extractSingleTarFile(Uint8List tar) {
  Uint8List? found;
  var offset = 0;
  while (offset + 512 <= tar.length) {
    final header = Uint8List.sublistView(tar, offset, offset + 512);
    if (header.every((b) => b == 0)) {
      break;
    }
    final size = _tarOctal(header, 124, 12);
    final type = header[156];
    final dataStart = offset + 512;
    if (dataStart + size > tar.length) {
      throw const FormatException('tar: mục vượt quá cuối file');
    }
    if (type == 0x30 || type == 0) {
      if (found != null) {
        throw const FormatException('tar: có nhiều hơn một file thường');
      }
      found = Uint8List.sublistView(tar, dataStart, dataStart + size);
    }
    offset = dataStart + ((size + 511) & ~511);
  }
  if (found == null) {
    throw const FormatException('tar: không có file thường');
  }
  return found;
}

int _tarOctal(Uint8List header, int start, int length) {
  var value = 0;
  var seen = false;
  for (var i = start; i < start + length; i++) {
    final c = header[i];
    if (c == 0 || c == 0x20) {
      if (seen) {
        break;
      }
      continue;
    }
    if (c < 0x30 || c > 0x37) {
      throw const FormatException('tar: trường kích thước không phải bát phân');
    }
    value = value * 8 + (c - 0x30);
    seen = true;
  }
  return value;
}

// ---------------------------------------------------------------------------
// MurmurHash3 x86_32 + Bloom (cài độc lập với lib/core/policy)

/// MurmurHash3 x86_32 của [data] với [seed]; kết quả không dấu 32-bit.
int murmur3(List<int> data, int seed) {
  const m32 = 0xFFFFFFFF;
  int mul(int a, int b) {
    // Tách nửa thấp/cao 16 bit để tích không vượt 2^53.
    final lo = (a & 0xFFFF) * b;
    final hi = ((a >> 16) * b) & 0xFFFF;
    return (lo + (hi << 16)) & m32;
  }

  int rotl(int x, int r) => ((x << r) & m32) | (x >> (32 - r));

  var h = seed & m32;
  final n = data.length;
  final whole = n - (n % 4);
  for (var i = 0; i < whole; i += 4) {
    var k =
        (data[i] & 0xFF) |
        ((data[i + 1] & 0xFF) << 8) |
        ((data[i + 2] & 0xFF) << 16) |
        ((data[i + 3] & 0xFF) << 24);
    k = mul(rotl(mul(k, 0xCC9E2D51), 15), 0x1B873593);
    h = rotl(h ^ k, 13);
    h = (mul(h, 5) + 0xE6546B64) & m32;
  }
  var k = 0;
  for (var i = n - 1; i >= whole; i--) {
    k = (k << 8) | (data[i] & 0xFF);
  }
  if (n > whole) {
    k = mul(rotl(mul(k, 0xCC9E2D51), 15), 0x1B873593);
    h ^= k;
  }
  h ^= n & m32;
  h ^= h >> 16;
  h = mul(h, 0x85EBCA6B);
  h ^= h >> 13;
  h = mul(h, 0xC2B2AE35);
  h ^= h >> 16;
  return h;
}

/// Số bit của filter cho [n] mục: `⌈−n·ln p / (ln 2)²⌉`.
int bloomBitCount(int n) =>
    (-n * math.log(falsePositiveRate) / (math.ln2 * math.ln2)).ceil();

/// Các chỉ số bit của [entry] trong filter [mBits] bit.
List<int> bloomIndices(String entry, int mBits) {
  final bytes = ascii.encode(entry);
  final h1 = murmur3(bytes, bloomSeed);
  final h2 = murmur3(bytes, bloomSeed ^ seedMix) | 1;
  return [for (var j = 0; j < hashCount; j++) (h1 + j * h2) % mBits];
}

/// Dựng file `PAKB` v1 cho [entries] (ASCII chữ thường).
Uint8List buildBloom(List<String> entries) {
  final n = entries.length;
  final mBits = math.max(bloomBitCount(n), 8);
  final out = Uint8List(headerLength + ((mBits + 7) >> 3));
  out.setAll(0, ascii.encode('PAKB'));
  ByteData.sublistView(out)
    ..setUint8(4, formatVersion)
    ..setUint8(5, hashCount)
    ..setUint16(6, 0, Endian.little)
    ..setUint32(8, mBits, Endian.little)
    ..setUint32(12, n, Endian.little)
    ..setUint32(16, bloomSeed, Endian.little);
  for (final entry in entries) {
    for (final i in bloomIndices(entry, mBits)) {
      out[headerLength + (i >> 3)] |= 1 << (i & 7);
    }
  }
  return out;
}

/// Tỷ lệ dương tính giả lý thuyết `(1 − e^(−k·n/m))^k`.
double expectedFalsePositiveRate(int n, int mBits) =>
    math.pow(1 - math.exp(-hashCount * n / mBits), hashCount).toDouble();

/// 500 mục mẫu: mục thứ `i·⌊n/500⌋` của [sorted], `i` = 0…499.
List<String> pickSample(List<String> sorted) {
  if (sorted.length < sampleSize) {
    throw StateError('chỉ có ${sorted.length} mục, cần ít nhất $sampleSize');
  }
  final step = sorted.length ~/ sampleSize;
  return [for (var i = 0; i < sampleSize; i++) sorted[i * step]];
}

// ---------------------------------------------------------------------------
// Chạy

Future<Uint8List> _download(HttpClient client, Uri url) async {
  final request = await client.getUrl(url);
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    await response.drain<void>();
    throw HttpException('HTTP ${response.statusCode}', uri: url);
  }
  final builder = BytesBuilder(copy: false);
  await response.forEach(builder.add);
  return builder.takeBytes();
}

Uint8List _decodeSource(String path, Uint8List raw) {
  if (path.endsWith('.tar.gz')) {
    return extractSingleTarFile(Uint8List.fromList(gzip.decode(raw)));
  }
  if (path.endsWith('.gz')) {
    return Uint8List.fromList(gzip.decode(raw));
  }
  return raw;
}

void _writeAtomically(String path, List<int> bytes) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  final tmp = File('$path.tmp')..writeAsBytesSync(bytes, flush: true);
  tmp.renameSync(path);
}

String _formatDoc({
  required BlocklistSource source,
  required List<(String, int)> counts,
  required int n,
  required int mBits,
  required int assetBytes,
}) {
  final fp = (expectedFalsePositiveRate(n, mBits) * 100).toStringAsFixed(4);
  final sources = [for (final (path, count) in counts) '| `$path` | $count |']
      .join('\n');
  return '''
# `blocklist.bloom` — định dạng PAKB v1 (AD-15)

Sinh bằng `dart tool/blocklist/build_blocklist.dart` (trong `pak_manager/`).
Không sửa tay. Đọc bởi `BlocklistFilter.parse` (`lib/core/policy/`).

## Layout (little-endian)

| Offset | Kích thước | Trường | Giá trị |
|---|---|---|---|
| 0 | 4 | magic | `PAKB` |
| 4 | 1 | version (u8) | $formatVersion |
| 5 | 1 | k (u8), số hàm băm | $hashCount |
| 6 | 2 | reserved (u16) | 0 |
| 8 | 4 | mBits (u32) | $mBits |
| 12 | 4 | n (u32), số mục | $n |
| 16 | 4 | seed (u32) | `0x${bloomSeed.toRadixString(16).toUpperCase()}` ("PAK1") |
| 20 | ⌈mBits/8⌉ | bits | mảng bit |

Bit `i` nằm ở byte `20 + (i >> 3)`, bit `i & 7` (LSB trước).

## Tra cứu

`s` là byte ASCII của chuỗi đã chuyển chữ thường.

- `h1 = murmur3_x86_32(s, seed)`
- `h2 = murmur3_x86_32(s, seed ^ 0x9E3779B9) | 1`
- chỉ số thứ `j` (0 ≤ j < k) = `(h1 + j·h2) mod mBits`, tính bằng số nguyên
  64-bit (không tràn).

Chuỗi "có trong blocklist" khi cả `k` bit đều bật.

## Tham số

- Tỷ lệ dương tính giả thiết kế p = $falsePositiveRate:
  `mBits = ⌈−n·ln p / (ln 2)²⌉`, k = $hashCount.
- Tỷ lệ dương tính giả lý thuyết với n, mBits trên: $fp%.
- Kích thước file: $assetBytes byte (trần $maxAssetBytes).

## Nguồn

Repo `${source.repo}`, commit `${source.commit}`, giấy phép ${source.license}.
Chỉ giữ dòng ASCII in được (0x20–0x7E) dài $minEntryLength–$maxEntryLength
sau khi bỏ `\\r` cuối dòng, chuyển chữ thường, khử trùng.

| File | Số dòng hợp lệ (trước khử trùng) |
|---|---|
$sources

Tổng sau khử trùng: $n mục.

Mẫu kiểm thử `test/fixtures/blocklist/sample.txt`: $sampleSize mục, mục thứ
`i·⌊n/$sampleSize⌋` của danh sách đã sắp xếp.
''';
}

Future<int> run() async {
  if (!File('pubspec.yaml').existsSync() || !File(sourcePath).existsSync()) {
    stderr.writeln('Chạy trong thư mục pak_manager/.');
    return 2;
  }
  final source = parseSource(File(sourcePath).readAsStringSync());
  final entries = <String>{};
  final counts = <(String, int)>[];
  final client = HttpClient();
  try {
    for (final path in source.paths) {
      final url = source.urlFor(path);
      stdout.writeln('Tải $url');
      final data = _decodeSource(path, await _download(client, url));
      final accepted = collectEntries(data, entries);
      counts.add((path, accepted));
      stdout.writeln('  $accepted dòng hợp lệ');
    }
  } finally {
    client.close(force: true);
  }

  final sorted = entries.toList()..sort();
  final bloom = buildBloom(sorted);
  if (bloom.length > maxAssetBytes) {
    stderr.writeln(
      'blocklist.bloom dài ${bloom.length} byte, vượt trần $maxAssetBytes',
    );
    return 1;
  }
  final mBits = ByteData.sublistView(bloom).getUint32(8, Endian.little);
  final sample = pickSample(sorted);
  final doc = _formatDoc(
    source: source,
    counts: counts,
    n: sorted.length,
    mBits: mBits,
    assetBytes: bloom.length,
  );

  _writeAtomically(bloomPath, bloom);
  _writeAtomically(formatPath, utf8.encode(doc));
  _writeAtomically(samplePath, ascii.encode('${sample.join('\n')}\n'));
  stdout.writeln(
    'Đã sinh $bloomPath (${bloom.length} byte, n=${sorted.length}, '
    'mBits=$mBits), $formatPath, $samplePath',
  );
  return 0;
}

Future<void> main() async {
  try {
    exitCode = await run();
  } on Object catch (e) {
    stderr.writeln('build_blocklist: lỗi: $e');
    exitCode = 1;
  }
}
