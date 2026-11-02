import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

import 'error_policy.dart';

void main() {
  if (kReleaseMode) {
    installReleaseErrorPolicy();
  }
  runApp(const PakApp());
}

/// Gốc ứng dụng. Story 1.1 chỉ dựng khung rỗng; `SessionGate`, theme và
/// localization được thêm ở các story sau (AD-23).
class PakApp extends StatelessWidget {
  const PakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: CupertinoPageScaffold(child: SizedBox.shrink()),
    );
  }
}
