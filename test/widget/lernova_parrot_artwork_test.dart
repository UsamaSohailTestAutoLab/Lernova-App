import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lernova/core/theme/app_theme.dart';
import 'package:lernova/core/widgets/lernova_parrot.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
  );
  // Bounded: the mascot plays a one-shot settle that would otherwise
  // keep pumpAndSettle busy.
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  // Seventeen call sites draw their mascot through this one widget, so
  // a missing or misnamed artwork file must degrade to the painted
  // parrot rather than to a broken-image box on every screen at once.
  group('the mascot survives its artwork going missing', () {
    testWidgets('it renders without throwing when the asset is absent',
        (tester) async {
      await _pump(tester, const LernovaParrot(size: 96));

      expect(find.byType(LernovaParrot), findsOneWidget);
      expect(tester.takeException(), isNull);
      // The fallback is a painter, not an error placeholder.
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('every mood still builds', (tester) async {
      for (final mood in LernovaParrotMood.values) {
        await _pump(tester, LernovaParrot(size: 72, mood: mood));
        expect(tester.takeException(), isNull, reason: mood.name);
      }
    });

    testWidgets('the wordmark variant is unaffected', (tester) async {
      await _pump(tester, const LernovaParrot(size: 64, showWordmark: true));

      expect(find.text('Lernova'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // The size a caller asks for is the box the art occupies, whichever
    // of the two sources is drawing it.
    testWidgets('it honours the requested size', (tester) async {
      await _pump(tester, const LernovaParrot(size: 80));

      final box = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(LernovaParrot),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(box.width, 80);
    });
  });
}
