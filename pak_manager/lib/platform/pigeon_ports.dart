import '../core/ports/backup_port.dart';
import '../core/ports/clock_port.dart';
import '../core/ports/file_sync_port.dart';
import 'platform_api.g.dart';

/// Cài [ClockPort], [FileSyncPort], [BackupPort] bằng API Pigeon (AD-14).
final class PigeonPlatformPorts implements ClockPort, FileSyncPort, BackupPort {
  PigeonPlatformPorts({PlatformApi? api}) : _api = api ?? PlatformApi();

  final PlatformApi _api;

  @override
  Future<int> monotonicMs() => _api.monotonicMs();

  @override
  Future<String> bootId() => _api.bootId();

  @override
  Future<void> fsyncDirectory(String path) => _api.fsyncDirectory(path);

  @override
  Future<void> excludeFromBackup(String dirPath) =>
      _api.excludeFromBackup(dirPath);
}
