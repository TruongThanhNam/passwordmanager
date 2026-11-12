// Phân tích output thô của aapt2/unzip/readelf cho APK release (AD-11, AD-12,
// AD-15, AD-19, NFR-7, NFR-8).
//
// Dart thuần, không dependency. `check_android_apk.sh` gọi công cụ, ghi output
// vào thư mục làm việc rồi chạy (trong pak_manager/):
//   dart run tool/ci/apk_rules.dart <workDir> [expectedApplicationId]
// Cấu trúc <workDir>:
//   manifest.txt              aapt2 dump xmltree --file AndroidManifest.xml
//   listing.txt               unzip -l
//   readelf/<abi>/<so>.txt    readelf -lW cho từng lib/<abi>/<so>
//   badging.txt               aapt2 dump badging (khi có expectedApplicationId)
// Exit 0 và in "OK" khi sạch; exit 1 khi có vi phạm (mỗi vi phạm một dòng
// stderr).

import 'dart:io';

/// ABI 64-bit bắt buộc căn 16 KB; `.so` 32-bit không kiểm align.
const abis64 = {'arm64-v8a', 'x86_64'};

/// Căn tối thiểu của segment LOAD (16 KB).
const minLoadAlign = 0x4000;

/// Asset blocklist phải được đóng gói (AD-15).
const blocklistAsset = 'assets/flutter_assets/assets/blocklist.bloom';

// aapt2 in boolean dạng `=false` hoặc `=(type 0x12)0x0`.
final _allowBackupOff = RegExp(
  r':allowBackup\(0x[0-9a-fA-F]+\)=(false|\(type 0x12\)0x0)(\s|$)',
  multiLine: true,
);

/// Kiểm manifest đã merge (output `aapt2 dump xmltree`).
List<String> checkManifest(String manifest) {
  final violations = <String>[];
  if (manifest.contains('android.permission.INTERNET')) {
    violations.add('manifest có android.permission.INTERNET (AD-12)');
  }
  if (!_allowBackupOff.hasMatch(manifest.replaceAll('\r', ''))) {
    violations.add(
      'manifest không có android:allowBackup=false (AD-11, NFR-8)',
    );
  }
  for (final attr in ['dataExtractionRules', 'fullBackupContent']) {
    if (!RegExp(':$attr\\(0x[0-9a-fA-F]+\\)=@').hasMatch(manifest)) {
      violations.add('manifest thiếu android:$attr trỏ tới resource (AD-11)');
    }
  }
  return violations;
}

final _listingEntry = RegExp(r'^\s*\d+\s+\S+\s+\S+\s+(\S.*)$');

/// Đường dẫn file trong output `unzip -l` (cột sau ngày giờ).
List<String> parseListing(String listing) => [
  for (final line in listing.split('\n'))
    if (_listingEntry.firstMatch(line.replaceAll('\r', '').trimRight())
        case final m?)
      m.group(1)!,
];

/// Các `.so` trong listing, dạng `<abi>/<tên>.so`.
List<String> soFilesInListing(String listing) => [
  for (final p in parseListing(listing))
    if (RegExp(r'^lib/[^/]+/[^/]+\.so$').hasMatch(p)) p.substring(4),
];

/// Kiểm listing: có lib/arm64-v8a/, libsodium.so ở mọi ABI, asset blocklist.
List<String> checkListing(String listing) {
  final violations = <String>[];
  final paths = parseListing(listing);
  final sos = soFilesInListing(listing);
  if (sos.isEmpty) {
    violations.add('APK không có lib/*/*.so (AD-19)');
  }
  if (!sos.any((s) => s.startsWith('arm64-v8a/'))) {
    violations.add('APK thiếu lib/arm64-v8a/ (AD-19)');
  }
  final abis = {for (final s in sos) s.split('/').first}.toList()..sort();
  for (final abi in abis) {
    if (!sos.contains('$abi/libsodium.so')) {
      violations.add(
        'APK thiếu lib/$abi/libsodium.so (build hook của sodium không chạy?)',
      );
    }
  }
  if (!paths.contains(blocklistAsset)) {
    violations.add('APK thiếu $blocklistAsset (AD-15)');
  }
  return violations;
}

/// Kiểm align LOAD từ `readelf -lW`; khóa là `<abi>/<tên>.so`. Chỉ ABI 64-bit.
List<String> checkElfAligns(Map<String, String> readelfByPath) {
  final violations = <String>[];
  final keys = readelfByPath.keys.toList()..sort();
  for (final path in keys) {
    if (!abis64.contains(path.split('/').first)) {
      continue;
    }
    final aligns = <String>[];
    for (final raw in readelfByPath[path]!.split('\n')) {
      final tokens = raw.trim().split(RegExp(r'\s+'));
      if (tokens.first == 'LOAD') {
        aligns.add(tokens.last);
      }
    }
    if (aligns.isEmpty) {
      violations.add('lib/$path không có segment LOAD (AD-19)');
      continue;
    }
    final bad = [
      for (final a in aligns)
        if ((int.tryParse(a.replaceFirst(RegExp('^0[xX]'), ''), radix: 16) ??
                0) <
            minLoadAlign)
          a,
    ];
    if (bad.isNotEmpty) {
      violations.add(
        'lib/$path có LOAD align < 0x4000: ${bad.join(' ')} (AD-19)',
      );
    }
  }
  return violations;
}

/// Kiểm applicationId từ `aapt2 dump badging`.
List<String> checkBadging(String badging, String expectedId) {
  final m = RegExp(
    r"^package: name='([^']*)'",
    multiLine: true,
  ).firstMatch(badging.replaceAll('\r', ''));
  if (m == null) {
    return ['badging không có dòng package: name=... (applicationId)'];
  }
  if (m.group(1) != expectedId) {
    return ['applicationId "${m.group(1)}" khác "$expectedId"'];
  }
  return [];
}

String? _readOrNull(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}

/// [args] = `[workDir, expectedApplicationId?]`; trả exit code.
int run(List<String> args, {StringSink? out, StringSink? err}) {
  final output = out ?? stdout;
  final errors = err ?? stderr;
  if (args.isEmpty) {
    errors.writeln('Dùng: apk_rules.dart <workDir> [expectedApplicationId]');
    return 1;
  }
  final work = args[0];
  final violations = <String>[];

  final manifest = _readOrNull('$work/manifest.txt');
  if (manifest == null) {
    violations.add('không đọc được $work/manifest.txt');
  } else {
    violations.addAll(checkManifest(manifest));
  }

  final listing = _readOrNull('$work/listing.txt');
  if (listing == null) {
    violations.add('không đọc được $work/listing.txt');
  } else {
    violations.addAll(checkListing(listing));
    final readelf = <String, String>{};
    for (final so in soFilesInListing(listing)) {
      final text = _readOrNull('$work/readelf/$so.txt');
      if (text == null) {
        violations.add('thiếu output readelf cho lib/$so');
      } else {
        readelf[so] = text;
      }
    }
    violations.addAll(checkElfAligns(readelf));
  }

  if (args.length > 1) {
    final badging = _readOrNull('$work/badging.txt');
    if (badging == null) {
      violations.add('không đọc được $work/badging.txt');
    } else {
      violations.addAll(checkBadging(badging, args[1]));
    }
  }

  if (violations.isEmpty) {
    output.writeln('OK');
    return 0;
  }
  for (final v in violations) {
    errors.writeln(v);
  }
  return 1;
}

void main(List<String> args) {
  exit(run(args));
}
