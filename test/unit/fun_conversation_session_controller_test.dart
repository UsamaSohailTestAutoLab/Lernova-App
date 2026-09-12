import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/data/models/fun/conversation.dart';
import 'package:lingoquest/features/fun/application/fun_conversation_session_controller.dart';
import 'package:lingoquest/features/progress/application/progress_controller.dart';

List<Conversation> _conversations() => const [
      Conversation(
        id: 'c1',
        title: 'At the Café',
        scenario: 'Ordering coffee',
        languageId: 'es',
        turns: [
          ConversationTurn(id: 't1', line: 'Line 1', options: ['A', 'B', 'C'], correctIndex: 0),
          ConversationTurn(id: 't2', line: 'Line 2', options: ['A', 'B', 'C'], correctIndex: 1),
        ],
      ),
      Conversation(
        id: 'c2',
        title: 'Directions',
        scenario: 'Asking directions',
        languageId: 'es',
        turns: [
          ConversationTurn(id: 't3', line: 'Line 3', options: ['A', 'B'], correctIndex: 0),
        ],
      ),
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

  test('a correct response builds combo and marks the turn correct', () {
    final controller = container.read(funConversationSessionProvider.notifier);
    controller.start(pool: [_conversations()[0]], totalConversations: 1, random: Random(1));

    controller.chooseResponse(0, Random(1)); // t1 correctIndex is 0
    final s = container.read(funConversationSessionProvider)!;
    expect(s.turnCorrectness[0], isTrue);
    expect(s.combo, 1);
    expect(s.currentTurnIndex, 1); // advanced to the next turn
    expect(s.vocabDeltas['t1'], 1);
  });

  test('a wrong response resets combo and blocks the turn until the correct option is re-tapped', () {
    final controller = container.read(funConversationSessionProvider.notifier);
    controller.start(pool: [_conversations()[0]], totalConversations: 1, random: Random(1));

    controller.chooseResponse(1, Random(1)); // wrong (correctIndex is 0)
    var s = container.read(funConversationSessionProvider)!;
    expect(s.turnCorrectness[0], isFalse);
    expect(s.combo, 0);
    expect(s.currentTurnIndex, 0); // held until the correct option is re-tapped
    expect(s.awaitingRecallConfirmation, isTrue);
    expect(s.vocabDeltas['t1'], -1);

    // Re-tapping another wrong option is a no-op — still blocked.
    controller.chooseResponse(2, Random(1));
    s = container.read(funConversationSessionProvider)!;
    expect(s.currentTurnIndex, 0);
    expect(s.awaitingRecallConfirmation, isTrue);

    // Re-tapping the correct option unblocks and advances.
    controller.chooseResponse(0, Random(1));
    s = container.read(funConversationSessionProvider)!;
    expect(s.currentTurnIndex, 1);
    expect(s.awaitingRecallConfirmation, isFalse);
  });

  test('finishing every turn of a conversation advances to the next conversation', () {
    final controller = container.read(funConversationSessionProvider.notifier);
    controller.start(pool: _conversations(), totalConversations: 2, random: Random(2));
    final first = container.read(funConversationSessionProvider)!;
    final firstConversationId = first.currentConversation.id;

    // Answer every turn of the first conversation.
    for (var i = 0; i < first.currentConversation.turns.length; i++) {
      final s = container.read(funConversationSessionProvider)!;
      controller.chooseResponse(s.currentTurn.correctIndex, Random(2));
    }

    final after = container.read(funConversationSessionProvider)!;
    expect(after.currentConversationIndex, 1);
    expect(after.isComplete, isFalse);
    expect(after.currentTurnIndex, 0);
    expect(after.turnCorrectness.every((c) => c == null), isTrue);
    // The round set is drawn distinct up front, so the second
    // conversation is a genuinely different scenario.
    expect(after.currentConversation.id, isNot(firstConversationId));
  });

  // The intro's Review Words step lists every scenario the session will
  // run; it used to show one card because only the first conversation
  // had been picked by then.
  group('round set', () {
    test('holds one distinct conversation per round, ready before play', () {
      final controller = container.read(funConversationSessionProvider.notifier);
      controller.start(pool: _conversations(), totalConversations: 2, random: Random(6));
      final s = container.read(funConversationSessionProvider)!;

      expect(s.pool, hasLength(2));
      expect(s.pool.map((c) => c.id).toSet(), hasLength(2));
      expect(s.currentConversation, s.pool.first);
    });

    test('a short pool shortens the session instead of repeating a scenario', () {
      final controller = container.read(funConversationSessionProvider.notifier);
      controller.start(
        pool: [_conversations().first],
        totalConversations: 3,
        random: Random(6),
      );
      final s = container.read(funConversationSessionProvider)!;

      expect(s.totalConversations, 1);
      expect(s.pool, hasLength(1));
    });
  });

  test('session completes after the requested number of conversations', () {
    final controller = container.read(funConversationSessionProvider.notifier);
    controller.start(pool: [_conversations()[1]], totalConversations: 1, random: Random(3));
    final s = container.read(funConversationSessionProvider)!;

    controller.chooseResponse(s.currentTurn.correctIndex, Random(3));
    final after = container.read(funConversationSessionProvider)!;
    expect(after.isComplete, isTrue);
  });

  test('finishAndApply awards XP through the shared ProgressController exactly once', () {
    final controller = container.read(funConversationSessionProvider.notifier);
    controller.start(pool: [_conversations()[1]], totalConversations: 1, random: Random(4));
    final s = container.read(funConversationSessionProvider)!;
    controller.chooseResponse(s.currentTurn.correctIndex, Random(4));

    final xpBefore = container.read(progressProvider).totalXp;
    final result1 = controller.finishAndApply();
    final xpAfter = container.read(progressProvider).totalXp;
    expect(xpAfter - xpBefore, result1.xpEarned);

    final result2 = controller.finishAndApply();
    expect(result2.xpEarned, result1.xpEarned);
    expect(container.read(progressProvider).totalXp, xpAfter);
  });
}
