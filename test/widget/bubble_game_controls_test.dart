import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lernova/core/constants/app_enums.dart';
import 'package:lernova/core/services/local_storage_service.dart';
import 'package:lernova/core/services/service_providers.dart';
import 'package:lernova/core/theme/app_theme.dart';
import 'package:lernova/data/models/fun/fun_level_config.dart';
import 'package:lernova/data/models/fun/fun_question.dart';
import 'package:lernova/features/fun/application/falling_word_session_controller.dart';
import 'package:lernova/features/fun/presentation/falling_word_game_screen.dart';
import 'package:lernova/features/fun/presentation/widgets/miss_banner.dart';
import 'package:lernova/features/fun/presentation/widgets/pause_overlay.dart';
import 'package:lernova/features/fun/presentation/widgets/water_bubble.dart';

const _questions = [
  FunQuestion(
    id: 'q1',
    type: FunQuestionType.wordToMeaning,
    promptText: 'Tres',
    options: ['Three', 'Ticket'],
    optionEmojis: ['3️⃣', '🎫'],
    correctIndex: 0,
    vocabId: 'es_tres',
  ),
  FunQuestion(
    id: 'q2',
    type: FunQuestionType.wordToMeaning,
    promptText: 'Boleto',
    options: ['Ticket', 'Three'],
    correctIndex: 0,
    vocabId: 'es_boleto',
  ),
];

/// A Word Bubble round, which uses the rising bubble field. Word
/// Survival's water scene has an ambient wave animation that never
/// settles under `pumpAndSettle`; it is covered separately, with
/// bounded pumps, in word_survival_mode_test.dart.
const _level = FunLevelConfig(
  level: 3,
  wordCount: 2,
  choiceCount: 3,
  bubbleOptionCount: 2,
  fallDuration: Duration(seconds: 6),
  allowedTypes: [FunQuestionType.wordToMeaning],
  comboEnabled: false,
  maxLives: 3,
);

/// Unmounts the game rather than settling it. A catching round is an
/// endless loop by design — `pumpAndSettle` would just roll into the next
/// question — so the deterministic way to finish a test is to dispose the
/// screen, which cancels its timers.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    container.read(fallingWordSessionProvider.notifier).start(
          mode: FunGameMode.fallingWords,
          questions: _questions,
          levelConfig: _level,
        );
  });

  Future<void> pumpGame(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const FallingWordGameScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Taps the wrong bubble on the current question.
  Future<void> tapWrongBubble(WidgetTester tester) async {
    final question = container.read(fallingWordSessionProvider)!.currentQuestion!;
    final wrong = question.options[question.correctIndex == 0 ? 1 : 0];
    await tester.tap(find.text(wrong));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('a miss does not interrupt play', () {
    // Regression: a wrong answer replaced the whole board with a card
    // that demanded the meaning be typed before the round would move on.
    // In a timed catching game that stopped play on every single miss.
    testWidgets('the board stays on screen and the answer appears beneath it',
        (tester) async {
      await pumpGame(tester);
      await tapWrongBubble(tester);

      expect(find.byType(MissBanner), findsOneWidget);
      expect(find.byType(WaterBubble), findsWidgets, reason: 'the board is still there');
      expect(find.textContaining('Tres = Three'), findsOneWidget);
      expect(find.textContaining('You picked'), findsOneWidget);
      // Nothing to type, and nothing gating the round.
      expect(find.byType(TextField), findsNothing);

      await _teardown(tester);
    });

    testWidgets('it clears itself without the player doing anything', (tester) async {
      await pumpGame(tester);
      await tapWrongBubble(tester);
      expect(find.byType(MissBanner), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2700));
      await tester.pump();

      expect(find.byType(MissBanner), findsNothing);
      expect(container.read(fallingWordSessionProvider)!.pendingRecall, isNull);
      await _teardown(tester);
    });

    testWidgets('Next skips the wait', (tester) async {
      await pumpGame(tester);
      await tapWrongBubble(tester);

      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pump();

      expect(find.byType(MissBanner), findsNothing);
      await _teardown(tester);
    });
  });

  group('pause', () {
    testWidgets('freezes the round clock and blocks answering', (tester) async {
      await pumpGame(tester);

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();

      expect(find.byType(PauseOverlay), findsOneWidget);

      // Well past the 6s fall: without a working pause this would have
      // timed the question out and cost a life.
      await tester.pump(const Duration(seconds: 10));
      final session = container.read(fallingWordSessionProvider)!;
      expect(session.lives, _level.maxLives);
      expect(session.pendingRecall, isNull);
      expect(session.currentIndex, 0);

      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(find.byType(PauseOverlay), findsNothing);
      await _teardown(tester);
    });

    testWidgets('resuming continues the question rather than restarting it',
        (tester) async {
      await pumpGame(tester);

      await tester.pump(const Duration(seconds: 3)); // half the fall
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5)); // paused: nothing moves

      await tester.tap(find.text('Resume'));
      await tester.pump();

      // The remaining ~3s finish the question the player was already on;
      // a restart would have handed back the time already spent.
      await tester.pump(const Duration(milliseconds: 3500));
      expect(container.read(fallingWordSessionProvider)!.pendingRecall, isNotNull);
      await _teardown(tester);
    });
  });
}
