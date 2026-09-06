import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lernova/core/services/local_storage_service.dart';
import 'package:lernova/core/services/service_providers.dart';
import 'package:lernova/data/models/fun/vocab_word.dart';
import 'package:lernova/features/fun/application/fun_word_match_session_controller.dart';
import 'package:lernova/features/progress/application/progress_controller.dart';

List<VocabWord> _words() => const [
      VocabWord(id: 'w1', word: 'Hola', translation: 'Hello', languageId: 'es', category: 'g'),
      VocabWord(id: 'w2', word: 'Adiós', translation: 'Goodbye', languageId: 'es', category: 'g'),
      VocabWord(id: 'w3', word: 'Gracias', translation: 'Thanks', languageId: 'es', category: 'g'),
      VocabWord(id: 'w4', word: 'Perro', translation: 'Dog', languageId: 'es', category: 'a'),
    ];

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

  test('a correct pair locks in and building combo', () {
    final controller = container.read(funWordMatchSessionProvider.notifier);
    controller.start(
      words: _words(),
      vocabStrength: const {},
      totalRounds: 1,
      pairsPerRound: 2,
      random: Random(1),
    );
    final before = container.read(funWordMatchSessionProvider)!;
    final leftWord = before.currentRoundWords[0];

    controller.attemptPair(0, 0, Random(1));
    final after = container.read(funWordMatchSessionProvider)!;
    expect(after.matched[0], 0);
    expect(after.combo, 1);
    expect(after.correctPairs, 1);
    expect(after.vocabDeltas[leftWord.id], 1);
  });

  test('a wrong pair resets combo and costs a life without locking anything', () {
    final controller = container.read(funWordMatchSessionProvider.notifier);
    controller.start(
      words: _words(),
      vocabStrength: const {},
      totalRounds: 1,
      pairsPerRound: 2,
      random: Random(1),
    );
    controller.attemptPair(0, 1, Random(1)); // mismatched (unless 0==1, but pairsPerRound=2 so distinct)
    final state = container.read(funWordMatchSessionProvider)!;
    expect(state.lives, 2);
    expect(state.combo, 0);
    expect(state.matched, isEmpty);
    expect(state.wrongAttempts, 1);
    expect(state.pendingRecall, isNotNull);
  });

  test('a correct recall answer clears the challenge and re-enables the grid', () {
    final controller = container.read(funWordMatchSessionProvider.notifier);
    controller.start(
      words: _words(),
      vocabStrength: const {},
      totalRounds: 1,
      pairsPerRound: 2,
      random: Random(1),
    );
    controller.attemptPair(0, 1, Random(1)); // wrong
    final challenge = container.read(funWordMatchSessionProvider)!.pendingRecall!;
    controller.submitRecallAnswer(challenge.correctMeaning);

    final state = container.read(funWordMatchSessionProvider)!;
    expect(state.pendingRecall, isNull);
  });

  test('a wrong recall answer increments attempts without clearing the challenge', () {
    final controller = container.read(funWordMatchSessionProvider.notifier);
    controller.start(
      words: _words(),
      vocabStrength: const {},
      totalRounds: 1,
      pairsPerRound: 2,
      random: Random(1),
    );
    controller.attemptPair(0, 1, Random(1)); // wrong
    controller.submitRecallAnswer('nonsense guess');

    final state = container.read(funWordMatchSessionProvider)!;
    expect(state.recallAttempts, 1);
    expect(state.pendingRecall, isNotNull);
  });

  test('round completes and advances once every pair in it is matched', () {
    final controller = container.read(funWordMatchSessionProvider.notifier);
    controller.start(
      words: _words(),
      vocabStrength: const {},
      totalRounds: 2,
      pairsPerRound: 2,
      random: Random(1),
    );
    controller.attemptPair(0, 0, Random(1));
    controller.attemptPair(1, 1, Random(1));

    final state = container.read(funWordMatchSessionProvider)!;
    expect(state.currentRoundIndex, 1); // moved to round 2
    expect(state.matched, isEmpty); // fresh round
    expect(state.isComplete, isFalse);
  });

  test('session completes after the final round finishes', () {
    final controller = container.read(funWordMatchSessionProvider.notifier);
    controller.start(
      words: _words(),
      vocabStrength: const {},
      totalRounds: 1,
      pairsPerRound: 2,
      random: Random(1),
    );
    controller.attemptPair(0, 0, Random(1));
    controller.attemptPair(1, 1, Random(1));

    final state = container.read(funWordMatchSessionProvider)!;
    expect(state.isComplete, isTrue);
    expect(state.failed, isFalse);
  });

  test('running out of lives fails the session', () {
    final controller = container.read(funWordMatchSessionProvider.notifier);
    controller.start(
      words: _words(),
      vocabStrength: const {},
      totalRounds: 1,
      pairsPerRound: 2,
      random: Random(1),
    );
    controller.attemptPair(0, 1, Random(1)); // wrong, lives 2
    controller.acknowledgeRecall();
    controller.attemptPair(0, 1, Random(1)); // wrong, lives 1
    controller.acknowledgeRecall();
    controller.attemptPair(0, 1, Random(1)); // wrong, lives 0 -> blocked on recall
    var state = container.read(funWordMatchSessionProvider)!;
    expect(state.isComplete, isFalse);

    controller.acknowledgeRecall();
    state = container.read(funWordMatchSessionProvider)!;
    expect(state.lives, 0);
    expect(state.failed, isTrue);
    expect(state.isComplete, isTrue);
  });

  test('finishAndApply awards XP through the shared ProgressController exactly once', () {
    final controller = container.read(funWordMatchSessionProvider.notifier);
    controller.start(
      words: _words(),
      vocabStrength: const {},
      totalRounds: 1,
      pairsPerRound: 2,
      random: Random(1),
    );
    controller.attemptPair(0, 0, Random(1));
    controller.attemptPair(1, 1, Random(1));

    final xpBefore = container.read(progressProvider).totalXp;
    final result1 = controller.finishAndApply();
    final xpAfter = container.read(progressProvider).totalXp;
    expect(xpAfter - xpBefore, result1.xpEarned);

    final result2 = controller.finishAndApply();
    expect(result2.xpEarned, result1.xpEarned);
    expect(container.read(progressProvider).totalXp, xpAfter);
  });
}
