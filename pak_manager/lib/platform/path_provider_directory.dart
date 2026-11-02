import 'package:path_provider/path_provider.dart';

import '../core/ports/app_directory_port.dart';

/// Cài [AppDirectoryPort] bằng `path_provider` (AD-11).
final class PathProviderDirectory implements AppDirectoryPort {
  const PathProviderDirectory();

  @override
  Future<String> applicationSupportPath() async =>
      (await getApplicationSupportDirectory()).path;
}
