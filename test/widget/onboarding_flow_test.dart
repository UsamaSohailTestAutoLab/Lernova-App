import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lernova/core/services/local_storage_service.dart';
import 'package:lernova/core/services/service_providers.dart';
import 'package:lernova/core/widgets/lernova_parrot.dart';
import 'package:lernova/main.dart';

void main() {
  testWidgets(
    'a new learner reaches language selection without any account step',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
          child: const LernovaApp(),
        ),
      );

      // Splash -> Welcome.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      expect(find.text('Get started'), findsOneWidget);
      // The original Lernova mascot, not the mock owl it briefly stood
      // in danger of copying — one parrot design used everywhere the
      // brand appears.
      expect(find.byType(LernovaParrot), findsOneWidget);
      // Sign-in is gone — the welcome screen offers no account path.
      expect(find.text('I already have an account'), findsNothing);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      // New-user explainer carousel — skip straight through.
      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // The name comes first, so the app can greet the learner by it
      // from the first screen after onboarding.
      expect(find.text("What's your name?"), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Ada Lovelace');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Language selection, populated from the bundled course JSON assets.
      expect(find.text('What do you want to learn?'), findsOneWidget);
      expect(find.text('Spanish'), findsOneWidget);
      expect(find.text('French'), findsOneWidget);

      // Cannot continue before picking a language.
      final continueButton = find.widgetWithText(ElevatedButton, 'Continue');
      expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);

      await tester.tap(find.text('Spanish'));
      await tester.pump();
      expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNotNull);
    },
  );
}
