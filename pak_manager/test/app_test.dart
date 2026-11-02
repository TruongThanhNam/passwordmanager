import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pak_manager/main.dart';

void main() {
  testWidgets('pak_app_builds_cupertino_app', (tester) async {
    await tester.pumpWidget(const PakApp());

    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.byType(CupertinoPageScaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
