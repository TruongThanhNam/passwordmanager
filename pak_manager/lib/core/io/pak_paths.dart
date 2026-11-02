import 'dart:io';

/// Bố cục thư mục dữ liệu của app (AD-11, AD-13). Mọi file nằm dưới
/// `ApplicationSupport/pak/`:
///
/// ```text
/// pak/
///   vault/{header,cards,recent,draft}
///   guard
///   settings
///   tmp/
/// ```
///
/// Chỉ tính đường dẫn, không chạm vào hệ thống file.
final class PakPaths {
  /// [root] là đường dẫn `ApplicationSupport`.
  PakPaths(String root) : root = _trimTrailingSeparator(root);

  final String root;

  String get pakDir => _join(root, 'pak');
  String get vaultDir => _join(pakDir, 'vault');
  String get guardFile => _join(pakDir, 'guard');
  String get settingsFile => _join(pakDir, 'settings');
  String get tmpDir => _join(pakDir, 'tmp');

  String get headerFile => _join(vaultDir, 'header');
  String get cardsFile => _join(vaultDir, 'cards');
  String get recentFile => _join(vaultDir, 'recent');
  String get draftFile => _join(vaultDir, 'draft');

  @override
  String toString() => 'PakPaths($pakDir)';
}

String _join(String dir, String name) => '$dir${Platform.pathSeparator}$name';

String _trimTrailingSeparator(String path) {
  var end = path.length;
  while (end > 1 && (path[end - 1] == '/' || path[end - 1] == r'\')) {
    end--;
  }
  return path.substring(0, end);
}
