/// fsync thư mục, để rename bên trong thư mục đó bền qua mất điện (AD-13).
abstract interface class FileSyncPort {
  /// Ném exception khi không fsync được [path].
  Future<void> fsyncDirectory(String path);
}
