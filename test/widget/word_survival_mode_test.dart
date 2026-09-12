import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/core/theme/app_theme.dart';
import 'package:lingoquest/data/models/fun/fun_level_config.dart';
import 'package:lingoquest/data/models/fun/fun_question.dart';
import 'package:lingoquest/features/fun/application/falling_word_session_controller.dart';
import 'package:lingoquest/features/fun/application/fun_level_catalog.dart';
import 'package:lingoquest/features/fun/presentation/falling_word_game_screen.dart';
import 'package:lingoquest/features/fun/presentation/widgets/bubble_field.dart';
import 'package:lingoquest/features/fun/presentation/widgets/water_survival_arena.dart';

const _questions = [
  FunQuestion(
    id: 'q1',
    type: FunQuestionType.wordToMeaning,
    promptText: 'Tres',
    options: ['Three', 'Ticket'],
    correctIndex: 0,
    vocabId: 'es_tres',
  ),
];

FunLevelConfig _level(int level) => FunLevelConfig(
      level: level,
      wordCount: 1,
      choiceCount: 3,
      bubbleOptionCount: 2,
      fallDuration: const Duration(seconds: 6),
      allowedTypes: const [FunQuestionType.wordToMeaning],
      comboEnabled: false,
      maxLives: 3,
    );

/// Unmounts rather than settling: a catching round loops by design, and
/// the water scene animates forever.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> _pumpRound(
  WidgetTester tester, {
  required FunGameMode mode,
  required int level,
}) async {
  SharedPreferences.setMockInitialValues({});
  late final LocalStorageService storage;
  await tester.runAsync(() async {
    storage = await LocalStorageService.create();
  });
  final container = ProviderContainer(
    overrides: [localStorageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);

  container.read(fallingWordSessionProvider.notifier).start(
        mode: mode,
        questions: _questions,
        levelConfig: _level(level),
      );

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

void main() {
  // The rising-water scene used to be bolted onto Word Bubble's level 1,
  // so the very first round anyone played was a different game from the
  // nine that followed it. It is now its own mode.
  group('Word Survival is its own game', () {
    testWidgets('Word Bubble level 1 is bubbles, not the water scene',
        (tester) async {
      await _pumpRound(tester, mode: FunGameMode.fallingWords, level: 1);

      expect(find.byType(BubbleField), findsOneWidget);
      expect(find.byType(WaterSurvivalArena), findsNothing);

      await _teardown(tester);
    });

    testWidgets('Word Survival shows the water scene at level 1',
        (tester) async {
      await _pumpRound(tester, mode: FunGameMode.wordSurvival, level: 1);

      expect(find.byType(WaterSurvivalArena), findsOneWidget);
      expect(find.byType(BubbleField), findsNothing);

      await _teardown(tester);
    });

    // The mechanic had nowhere to grow while it was a single level.
    testWidgets('and keeps it at every level, not just the first',
        (tester) async {
      await _pumpRound(tester, mode: FunGameMode.wordSurvival, level: 7);

      expect(find.byType(WaterSurvivalArena), findsOneWidget);

      await _teardown(tester);
    });
  });

  group('it sits at the end of the ladder', () {
    test('last in the list the Fun hub renders', () {
      expect(FunGameMode.values.last, FunGameMode.wordSurvival);
    });

    test('and unlocks after every other mode', () {
      final others = FunGameMode.values
          .where((m) => m != FunGameMode.wordSurvival)
          .map((m) => m.unlockLevel);

      for (final level in others) {
        expect(FunGameMode.wordSurvival.unlockLevel, greaterThan(level));
      }
    });

    test('its rounds scale like every other catching mode', () {
      // Not a special case in the catalogue: it grows on the shared
      // curve rather than being frozen at whatever level 1 happened to
      // be when it lived inside Word Bubble.
      final one = FunLevelCatalog.configFor(1, mode: FunGameMode.wordSurvival);
      final five = FunLevelCatalog.configFor(5, mode: FunGameMode.wordSurvival);

      expect(five.wordCount, greaterThan(one.wordCount));
      expect(five.maxLives, greaterThanOrEqualTo(one.maxLives));
    });
  });
}
