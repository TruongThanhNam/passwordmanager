import 'dart:io';

/// Xóa mọi file `*.tmp` dưới [pakDir], ở mọi cấp (AD-13). Không đi theo
/// symlink và không xóa symlink. Lỗi khi liệt kê một thư mục hoặc xóa một file
/// không dừng phần còn lại. Không ném exception; trả số file đã xóa.
Future<int> sweepTmpFiles(String pakDir) async {
  var deleted = 0;
  final pending = <Directory>[Directory(pakDir)];
  while (pending.isNotEmpty) {
    final dir = pending.removeLast();
    // Lỗi liệt kê (thư mục mất, không có quyền) chỉ bỏ qua phần bị lỗi.
    final entries = await dir
        .list(followLinks: false)
        .handleError((Object _) {})
        .toList();
    for (final entry in entries) {
      if (entry is Directory) {
        pending.add(entry);
      } else if (entry is File && entry.path.endsWith('.tmp')) {
        try {
          await entry.delete();
          deleted++;
        } on Object {
          // Bỏ qua, thử các file khác.
        }
      }
    }
  }
  return deleted;
}
