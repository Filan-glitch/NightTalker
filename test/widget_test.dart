import 'package:flutter_test/flutter_test.dart';

import 'package:nighttalker/app.dart';

void main() {
  testWidgets('NightTalkerApp builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const NightTalkerApp());

    expect(find.text('NightTalker'), findsOneWidget);
  });
}
