import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nighttalker/app.dart';

void main() {
  testWidgets('NightTalkerApp builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NightTalkerApp()));

    expect(find.text('NightTalker'), findsOneWidget);
  });
}
