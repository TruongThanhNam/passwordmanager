import 'dart:io';

// HttpClient trong comment không tính.
Future<void> fetch() async {
  final client = HttpClient();
  await Socket.connect('host', 1);
  client.close();
}
