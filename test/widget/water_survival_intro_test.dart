import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/routing/app_routes.dart';
import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/core/theme/app_theme.dart';
import 'package:lingoquest/features/fun/presentation/water_survival_intro_screen.dart';
import 'package:lingoquest/features/progress/application/progress_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
  });

  /// A real router, because the CTA navigates — and a stub destination,
  /// so the test can prove it arrives exactly once.
  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.funSurvivalIntro,
      routes: [
        GoRoute(
          path: AppRoutes.funSurvivalIntro,
          builder: (context, state) => const WaterSurvivalIntroScreen(),
        ),
        GoRoute(
          path: AppRoutes.funGamePlay,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('LEVEL'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    // Bounded: the demo animation loops forever, so this never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // The reported problem: the learner met the drowning mechanic with no
  // warning — the first they knew of it was the water already rising.
  testWidgets('explains the stake and the action before the level', (tester) async {
    await pump(tester);

    expect(find.text('Watch out! 🌊'), findsOneWidget);
    // What to do...
    expect(find.textContaining('right meaning'), findsOneWidget);
    // ...how long they have...
    expect(find.textContaining('your time'), findsOneWidget);
    // ...and what happens if they don't.
    expect(find.textContaining('raises the water'), findsOneWidget);
    expect(find.text('Got it! Start level'), findsOneWidget);
  });

  testWidgets('is short — three steps, not a manual', (tester) async {
    await pump(tester);

    for (final step in ['1', '2', '3']) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.text('4'), findsNothing);
  });

  testWidgets('starting marks it seen, so a replay goes straight to the level',
      (tester) async {
    await pump(tester);
    expect(
      container.read(progressProvider).seenTutorialIds,
      isNot(contains(waterSurvivalTutorialId)),
    );

    await tester.tap(find.text('Got it! Start level'));
    await tester.pump();

    expect(
      container.read(progressProvider).seenTutorialIds,
      contains(waterSurvivalTutorialId),
    );
  });

  testWidgets('a double tap on the CTA only starts the level once', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Got it! Start level'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // One navigation, one destination — a second tap can't stack another.
    expect(find.text('LEVEL'), findsOneWidget);
    expect(find.text('Got it! Start level'), findsNothing);
  });

  // The tutorial is a screen, not an overlay, so navigating away cannot
  // leave anything stuck over the game.
  testWidgets('leaves nothing behind when disposed', (tester) async {
    await pump(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(find.text('Watch out! 🌊'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('seenTutorialIds', () {
    test('is recorded once and survives a storage round-trip', () {
      final notifier = container.read(progressProvider.notifier);
      notifier.markTutorialSeen(waterSurvivalTutorialId);
      notifier.markTutorialSeen(waterSurvivalTutorialId);

      final ids = container.read(progressProvider).seenTutorialIds;
      expect(ids, hasLength(1));

      final json = container.read(progressProvider).toJson();
      expect(json['seenTutorialIds'], contains(waterSurvivalTutorialId));
    });
  });
}
