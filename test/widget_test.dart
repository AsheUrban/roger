import 'package:flutter_test/flutter_test.dart';

import 'package:roger/main.dart';

void main() {
  testWidgets('RogerApp renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const RogerApp());
    expect(find.text('roger'), findsNothing); // placeholder — no UI built yet
  });
}
