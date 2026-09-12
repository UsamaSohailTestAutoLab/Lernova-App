import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lingoquest/core/widgets/lingoquest_parrot.dart';

void main() {
  testWidgets('renders without the wordmark by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LingoQuestParrot())),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(LingoQuestParrot), findsOneWidget);
    expect(find.text('LingoQuest'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showWordmark adds the brand name underneath', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LingoQuestParrot(showWordmark: true)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('LingoQuest'), findsOneWidget);
  });

  testWidgets('every mood paints without throwing', (tester) async {
    for (final mood in LingoQuestParrotMood.values) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: LingoQuestParrot(mood: mood))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: mood.name);
    }
  });

  // A looping mascot on a screen the learner sits on (Home, the Fun hub)
  // would repaint forever behind everything else and stall
  // `pumpAndSettle` in any test that lands there.
  testWidgets('animate:false settles rather than looping', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LingoQuestParrot())),
    );
    await tester.pumpAndSettle();
  });
}
