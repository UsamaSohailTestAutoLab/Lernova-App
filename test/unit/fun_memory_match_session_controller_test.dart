import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lernova/core/services/local_storage_service.dart';
import 'package:lernova/core/services/service_providers.dart';
import 'package:lernova/data/models/fun/vocab_word.dart';
import 'package:lernova/features/fun/application/fun_memory_match_session_controller.dart';
import 'package:lernova/features/progress/application/progress_controller.dart';

List<VocabWord> _words() => const [
      VocabWord(id: 'w1', word: 'Hola', translation: 'Hello', languageId: 'es', category: 'g'),
      VocabWord(id: 'w2', word: 'Adiós', translation: 'Goodbye', languageId: 'es', category: 'g'),
      VocabWord(id: 'w3', word: 'Gracias', translation: 'Thanks', languageId: 'es', category: 'g'),
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

  test('start deals exactly 2 cards per pair, shuffled', () {
    final controller = container.read(funMemoryMatchSessionProvider.notifier);
    controller.start(words: _words(), vocabStrength: const {}, pairCount: 3, random: Random(1));
    final s = container.read(funMemoryMatchSessionProvider)!;
    expect(s.cards.length, 6);
    expect(s.pairCount, 3);
    // Every pairId appears exactly twice.
    final counts = <String, int>{};
    for (final c in s.cards) {
      counts[c.pairId] = (counts[c.pairId] ?? 0) + 1;
    }
    expect(counts.values.every((v) => v == 2), isTrue);
  });

  test('flipping two cards from the same pair matches them and builds combo', () {
    final controller = container.read(funMemoryMatchSessionProvider.notifier);
    controller.start(words: _words(), vocabStrength: const {}, pairCount: 3, random: Random(1));
    final s = container.read(funMemoryMatchSessionProvider)!;
    final pairId = s.cards[0].pairId;
    final secondIndex = [
      for (var i = 1; i < s.cards.length; i++)
        if (s.cards[i].pairId == pairId) i,
    ].first;

    controller.flipCard(0);
    controller.flipCard(secondIndex);

    final after = container.read(funMemoryMatchSessionProvider)!;
    expect(after.matchedIndices, containsAll([0, secondIndex]));
    expect(after.combo, 1);
    expect(after.matchesFound, 1);
    expect(after.vocabDeltas[pairId], 1);
  });

  test('flipping two mismatched cards costs a life, resets combo, and stays flipped until resolveMismatch', () {
    final controller = container.read(funMemoryMatchSessionProvider.notifier);
    controller.start(words: _words(), vocabStrength: const {}, pairCount: 3, random: Random(1));
    final s = container.read(funMemoryMatchSessionProvider)!;
    // Find two indices with different pairIds.
    final a = 0;
    final b = s.cards.indexWhere((c) => c.pairId != s.cards[a].pairId);

    controller.flipCard(a);
    controller.flipCard(b);

    final after = container.read(funMemoryMatchSessionProvider)!;
    expect(after.lives, 4); // 5 - 1
    expect(after.combo, 0);
    expect(after.mismatches, 1);
    expect(after.flippedIndices, {a, b}); // still visible until resolved

    controller.resolveMismatch();
    final resolved = container.read(funMemoryMatchSessionProvider)!;
    expect(resolved.flippedIndices, isEmpty);
    // The correct pairing is now shown as a recall challenge rather than
    // the round just continuing straight away.
    expect(resolved.pendingRecall, isNotNull);
    expect(resolved.isComplete, isFalse);

    controller.acknowledgeRecall();
    final acknowledged = container.read(funMemoryMatchSessionProvider)!;
    expect(acknowledged.pendingRecall, isNull);
  });

  test('running out of lives fails the session', () {
    final controller = container.read(funMemoryMatchSessionProvider.notifier);
    controller.start(words: _words(), vocabStrength: const {}, pairCount: 3, random: Random(1));

    for (var i = 0; i < 5; i++) {
      final s = container.read(funMemoryMatchSessionProvider)!;
      if (s.isComplete) break;
      final a = 0;
      final b = s.cards.indexWhere((c) => c.pairId != s.cards[a].pairId);
      controller.flipCard(a);
      controller.flipCard(b);
      controller.resolveMismatch();
      if (container.read(funMemoryMatchSessionProvider)!.pendingRecall != null) {
        controller.acknowledgeRecall();
      }
    }

    final result = container.read(funMemoryMatchSessionProvider)!;
    expect(result.failed, isTrue);
    expect(result.lives, 0);
  });

  test('finishAndApply awards XP through the shared ProgressController exactly once', () {
    final controller = container.read(funMemoryMatchSessionProvider.notifier);
    controller.start(words: _words(), vocabStrength: const {}, pairCount: 3, random: Random(1));
    final s = container.read(funMemoryMatchSessionProvider)!;
    final pairId = s.cards[0].pairId;
    final secondIndex = [
      for (var i = 1; i < s.cards.length; i++)
        if (s.cards[i].pairId == pairId) i,
    ].first;
    controller.flipCard(0);
    controller.flipCard(secondIndex);

    final xpBefore = container.read(progressProvider).totalXp;
    final result1 = controller.finishAndApply();
    final xpAfter = container.read(progressProvider).totalXp;
    expect(xpAfter - xpBefore, result1.xpEarned);

    final result2 = controller.finishAndApply();
    expect(result2.xpEarned, result1.xpEarned);
    expect(container.read(progressProvider).totalXp, xpAfter);
  });
}
