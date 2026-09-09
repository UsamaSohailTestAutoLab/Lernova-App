import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lernova/core/services/local_storage_service.dart';
import 'package:lernova/core/services/service_providers.dart';
import 'package:lernova/data/models/fun/phrase.dart';
import 'package:lernova/features/fun/application/fun_sentence_builder_session_controller.dart';
import 'package:lernova/features/progress/application/progress_controller.dart';

List<Phrase> _phrases() => const [
      Phrase(id: 'p1', phrase: 'Hola amigo', meaning: 'Hello friend', languageId: 'es', category: 'g'),
      Phrase(id: 'p2', phrase: 'Muchas gracias', meaning: 'Thank you very much', languageId: 'es', category: 'g'),
      Phrase(id: 'p3', phrase: 'Buenos días a todos', meaning: 'Good morning everyone', languageId: 'es', category: 'g'),
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

  test('shuffled tokens are never already in the correct order for 3+ word phrases', () {
    final controller = container.read(funSentenceBuilderSessionProvider.notifier);
    for (var seed = 0; seed < 30; seed++) {
      controller.start(pool: _phrases(), totalRounds: 1, random: Random(seed));
      final s = container.read(funSentenceBuilderSessionProvider)!;
      if (s.currentPhrase.phrase.split(' ').length >= 3) {
        expect(s.shuffledTokens.join(' '), isNot(s.currentPhrase.phrase));
      }
    }
  });

  test('choosing tokens in the correct order and submitting resolves correctly', () {
    final controller = container.read(funSentenceBuilderSessionProvider.notifier);
    controller.start(pool: [_phrases()[0]], totalRounds: 1, random: Random(2));
    final s = container.read(funSentenceBuilderSessionProvider)!;

    // Reconstruct the correct order regardless of shuffle by choosing
    // tokens in the order the correct phrase requires.
    for (final word in s.currentPhrase.phrase.split(' ')) {
      final idx = s.shuffledTokens.indexOf(word);
      controller.chooseToken(idx);
    }
    controller.submitSentence(Random(2));

    final result = container.read(funSentenceBuilderSessionProvider)!;
    expect(result.isComplete, isTrue); // only 1 round requested
    expect(result.correctCount, 1);
    expect(result.wrongCount, 0);
  });

  test('submitting the wrong order costs a life and still advances', () {
    final controller = container.read(funSentenceBuilderSessionProvider.notifier);
    controller.start(pool: _phrases(), totalRounds: 3, random: Random(3));
    final s = container.read(funSentenceBuilderSessionProvider)!;

    // Choose tokens in shuffled (likely wrong) order.
    for (var i = 0; i < s.shuffledTokens.length; i++) {
      controller.chooseToken(i);
    }
    controller.submitSentence(Random(3));

    final result = container.read(funSentenceBuilderSessionProvider)!;
    expect(result.wrongCount + result.correctCount, 1);
    if (result.wrongCount == 1) {
      expect(result.lives, 2);
      expect(result.combo, 0);
    }
  });

  test('removeToken un-chooses a token so it becomes available again', () {
    final controller = container.read(funSentenceBuilderSessionProvider.notifier);
    controller.start(pool: [_phrases()[0]], totalRounds: 1, random: Random(4));
    controller.chooseToken(0);
    expect(container.read(funSentenceBuilderSessionProvider)!.chosenIndices, [0]);

    controller.removeToken(0);
    final s = container.read(funSentenceBuilderSessionProvider)!;
    expect(s.chosenIndices, isEmpty);
    expect(s.availableIndices, contains(0));
  });

  // The round set is drawn up front so the intro's Review Words step can
  // show every sentence the round will ask for. It used to show one card
  // because only the first phrase existed at that point, and a run could
  // serve the same sentence twice.
  group('round set', () {
    test('holds one distinct phrase per round, ready before play starts', () {
      final controller = container.read(funSentenceBuilderSessionProvider.notifier);
      controller.start(pool: _phrases(), totalRounds: 3, random: Random(4));
      final s = container.read(funSentenceBuilderSessionProvider)!;

      expect(s.pool, hasLength(3));
      expect(s.pool.map((p) => p.id).toSet(), hasLength(3));
      expect(s.currentPhrase, s.pool.first);
    });

    test('a short pool shortens the round instead of repeating a sentence', () {
      final controller = container.read(funSentenceBuilderSessionProvider.notifier);
      controller.start(pool: _phrases().take(2).toList(), totalRounds: 8, random: Random(4));
      final s = container.read(funSentenceBuilderSessionProvider)!;

      expect(s.totalRounds, 2);
      expect(s.pool.map((p) => p.id).toSet(), hasLength(2));
    });

    test('each round serves the next phrase in the set', () {
      final controller = container.read(funSentenceBuilderSessionProvider.notifier);
      controller.start(pool: _phrases(), totalRounds: 3, random: Random(9));
      final set = container.read(funSentenceBuilderSessionProvider)!.pool;

      final seen = <String>[];
      for (var round = 0; round < 3; round++) {
        final s = container.read(funSentenceBuilderSessionProvider)!;
        if (s.isComplete) break;
        seen.add(s.currentPhrase.id);
        for (var i = 0; i < s.shuffledTokens.length; i++) {
          controller.chooseToken(i);
        }
        controller.submitSentence(Random(round));
        if (container.read(funSentenceBuilderSessionProvider)!.pendingRecall != null) {
          controller.acknowledgeRecall(Random(round));
        }
      }

      expect(seen, set.take(seen.length).map((p) => p.id).toList());
    });
  });

  test('running out of lives fails the session', () {
    // Three distinct 4-word phrases: a round set never repeats a phrase,
    // so burning three lives needs three of them. _tokensFor guarantees
    // the shuffled order never equals the correct order for 3+ word
    // phrases, so submitting tokens in shuffled order is a reliably
    // wrong answer every time.
    const pool = [
      Phrase(id: 'w1', phrase: 'Buenos días a todos', meaning: 'Good morning everyone', languageId: 'es', category: 'g'),
      Phrase(id: 'w2', phrase: 'Muchas gracias por todo', meaning: 'Thanks for everything', languageId: 'es', category: 'g'),
      Phrase(id: 'w3', phrase: 'Hasta luego mi amigo', meaning: 'See you later my friend', languageId: 'es', category: 'g'),
    ];
    final controller = container.read(funSentenceBuilderSessionProvider.notifier);
    controller.start(pool: pool, totalRounds: 10, random: Random(5));

    for (var i = 0; i < 3; i++) {
      final s = container.read(funSentenceBuilderSessionProvider)!;
      if (s.isComplete) break;
      for (var i2 = 0; i2 < s.shuffledTokens.length; i2++) {
        controller.chooseToken(i2);
      }
      controller.submitSentence(Random(5 + i));
      if (container.read(funSentenceBuilderSessionProvider)!.pendingRecall != null) {
        controller.acknowledgeRecall(Random(5 + i));
      }
    }

    final result = container.read(funSentenceBuilderSessionProvider)!;
    expect(result.lives, 0);
    expect(result.failed, isTrue);
    expect(result.isComplete, isTrue);
  });

  test('finishAndApply awards XP through the shared ProgressController exactly once', () {
    final controller = container.read(funSentenceBuilderSessionProvider.notifier);
    controller.start(pool: [_phrases()[0]], totalRounds: 1, random: Random(6));
    final s = container.read(funSentenceBuilderSessionProvider)!;
    for (final word in s.currentPhrase.phrase.split(' ')) {
      controller.chooseToken(s.shuffledTokens.indexOf(word));
    }
    controller.submitSentence(Random(6));

    final xpBefore = container.read(progressProvider).totalXp;
    final result1 = controller.finishAndApply();
    final xpAfter = container.read(progressProvider).totalXp;
    expect(xpAfter - xpBefore, result1.xpEarned);

    final result2 = controller.finishAndApply();
    expect(result2.xpEarned, result1.xpEarned);
    expect(container.read(progressProvider).totalXp, xpAfter);
  });
}
