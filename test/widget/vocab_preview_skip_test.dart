import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lernova/core/services/local_storage_service.dart';
import 'package:lernova/core/services/service_providers.dart';
import 'package:lernova/core/theme/app_theme.dart';
import 'package:lernova/data/models/vocab_preview_item.dart';
import 'package:lernova/data/models/vocab_preview_nav_args.dart';
import 'package:lernova/features/preview/presentation/vocab_preview_screen.dart';
import 'package:lernova/features/progress/application/progress_controller.dart';

const _items = [
  VocabPreviewItem(id: 'w1', word: 'Hola', meaning: 'Hello', emoji: '👋'),
  VocabPreviewItem(id: 'w2', word: 'Gracias', meaning: 'Thank you'),
];

const _previewKey = 'path:es_u1_l1';

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

  /// A minimal router, because the preview hands off with
  /// `pushReplacement` — which needs a real GoRouter above it. The
  /// destination is a stub: what is under test is the preview step.
  Future<void> pumpPreview(WidgetTester tester, {String? previewKey = _previewKey}) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => VocabPreviewScreen(
            args: VocabPreviewNavArgs(
              items: _items,
              levelLabel: 'Say Hello',
              onStartRoute: '/lesson/play',
              previewKey: previewKey,
            ),
          ),
        ),
        GoRoute(
          path: '/lesson/play',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('PLAYING'))),
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Steps through every card and starts the level.
  Future<void> reviewEverything(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      final next = find.byIcon(Icons.arrow_forward_rounded);
      if (next.evaluate().isEmpty) break;
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Start Level'));
    await tester.pump();
  }

  // A beginner meeting this vocabulary for the first time should see all
  // of it — there is deliberately no way past the first review.
  testWidgets('the first review of a level cannot be skipped', (tester) async {
    await pumpPreview(tester);

    expect(find.text('Review Words'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('reviewing it once unlocks Skip for later attempts', (tester) async {
    await pumpPreview(tester);
    expect(find.text('Skip'), findsNothing);

    await reviewEverything(tester);
    expect(
      container.read(progressProvider).previewedLevelIds,
      contains(_previewKey),
    );

    // Coming back to the same level.
    await pumpPreview(tester);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('Skip does not appear on the run that earns it', (tester) async {
    await pumpPreview(tester);
    await reviewEverything(tester);

    // Marking the level reviewed rebuilds this screen; the button must
    // not pop in underneath the learner who just finished reading.
    await tester.pump();
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('a different level still requires its own first review', (tester) async {
    await pumpPreview(tester);
    await reviewEverything(tester);

    await pumpPreview(tester, previewKey: 'path:es_u1_l2');
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('a preview with no level identity stays compulsory', (tester) async {
    // Mistake-review sessions pass no key: that flow is already the
    // remedial one, so its words are always shown.
    await pumpPreview(tester, previewKey: null);
    expect(find.text('Skip'), findsNothing);
  });
}
