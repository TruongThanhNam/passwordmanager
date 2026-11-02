import 'dart:io' as io;

Future<void> listen() async {
  final server = await io.ServerSocket.bind('127.0.0.1', 0);
  final message = 'cổng ${server.port} ${io.RawSocket}';
  await server.close();
  io.stdout.writeln(message);
}
