import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/data/models/fun/fun_level_config.dart';
import 'package:lingoquest/data/models/fun/fun_question.dart';
import 'package:lingoquest/features/fun/application/falling_word_session_controller.dart';
import 'package:lingoquest/features/progress/application/progress_controller.dart';

FunQuestion _q(String id, {int correctIndex = 0}) => FunQuestion(
      id: id,
      type: FunQuestionType.wordToMeaning,
      promptText: 'prompt_$id',
      options: const ['a', 'b', 'c'],
      correctIndex: correctIndex,
      vocabId: 'vocab_$id',
    );

const _config = FunLevelConfig(
  level: 1,
  wordCount: 3,
  choiceCount: 3,
  fallDuration: Duration(seconds: 5),
  allowedTypes: [FunQuestionType.wordToMeaning],
  comboEnabled: true,
  maxLives: 3,
);

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

  test('correct answers build combo and advance without losing a life', () {
    final controller = container.read(fallingWordSessionProvider.notifier);
    controller.start(
      mode: FunGameMode.fallingWords,
      questions: [_q('q1'), _q('q2'), _q('q3')],
      levelConfig: _config,
    );

    final correct1 = controller.submitAnswer(0);
    expect(correct1, isTrue);
    var state = container.read(fallingWordSessionProvider)!;
    expect(state.combo, 1);
    expect(state.lives, 3);
    expect(state.currentIndex, 1);

    controller.submitAnswer(0);
    state = container.read(fallingWordSessionProvider)!;
    expect(state.combo, 2);
  });

  test('a wrong answer resets combo and costs a life', () {
    final controller = container.read(fallingWordSessionProvider.notifier);
    controller.start(
      mode: FunGameMode.fallingWords,
      questions: [_q('q1'), _q('q2'), _q('q3')],
      levelConfig: _config,
    );

    controller.submitAnswer(0); // correct, combo -> 1
    final correct = controller.submitAnswer(1); // wrong
    expect(correct, isFalse);

    final state = container.read(fallingWordSessionProvider)!;
    expect(state.combo, 0);
    expect(state.lives, 2);
    expect(state.mistakeCount, 1);
  });

  test('a missed (timed out) question costs a life and blocks on recall until resolved', () {
    final controller = container.read(fallingWordSessionProvider.notifier);
    controller.start(
      mode: FunGameMode.fallingWords,
      questions: [_q('q1'), _q('q2')],
      levelConfig: _config,
    );

    controller.questionTimedOut();
    var state = container.read(fallingWordSessionProvider)!;
    expect(state.lives, 2);
    expect(state.mistakeCount, 1);
    expect(state.currentIndex, 0); // held until recall resolves
    expect(state.pendingRecall, isNotNull);

    controller.acknowledgeRecall();
    state = container.read(fallingWordSessionProvider)!;
    expect(state.currentIndex, 1);
    expect(state.pendingRecall, isNull);
  });

  test('a correct recall answer clears the challenge and advances the round', () {
    final controller = container.read(fallingWordSessionProvider.notifier);
    controller.start(
      mode: FunGameMode.fallingWords,
      questions: [_q('q1'), _q('q2')],
      levelConfig: _config,
    );

    controller.submitAnswer(1); // wrong
    final challenge = container.read(fallingWordSessionProvider)!.pendingRecall!;
    controller.submitRecallAnswer(challenge.correctMeaning);

    final state = container.read(fallingWordSessionProvider)!;
    expect(state.pendingRecall, isNull);
    expect(state.currentIndex, 1);
  });

  test('a wrong recall answer increments attempts without advancing', () {
    final controller = container.read(fallingWordSessionProvider.notifier);
    controller.start(
      mode: FunGameMode.fallingWords,
      questions: [_q('q1'), _q('q2')],
      levelConfig: _config,
    );

    controller.submitAnswer(1); // wrong
    controller.submitRecallAnswer('totally wrong guess');

    final state = container.read(fallingWordSessionProvider)!;
    expect(state.recallAttempts, 1);
    expect(state.pendingRecall, isNotNull);
    expect(state.currentIndex, 0);
  });

  test('round ends (failed) once lives reach zero, even mid-round', () {
    final controller = container.read(fallingWordSessionProvider.notifier);
    controller.start(
      mode: FunGameMode.fallingWords,
      questions: [_q('q1'), _q('q2'), _q('q3'), _q('q4'), _q('q5')],
      levelConfig: _config,
    );

    controller.submitAnswer(1); // wrong, lives 2
    controller.acknowledgeRecall();
    controller.submitAnswer(1); // wrong, lives 1
    controller.acknowledgeRecall();
    controller.submitAnswer(1); // wrong, lives 0 -> blocked on recall until acknowledged
    var state = container.read(fallingWordSessionProvider)!;
    expect(state.isComplete, isFalse);

    controller.acknowledgeRecall();
    state = container.read(fallingWordSessionProvider)!;
    expect(state.lives, 0);
    expect(state.failed, isTrue);
    expect(state.isComplete, isTrue);
  });

  test('round completes normally once every question is answered', () {
    final controller = container.read(fallingWordSessionProvider.notifier);
    controller.start(
      mode: FunGameMode.fallingWords,
      questions: [_q('q1'), _q('q2')],
      levelConfig: _config,
    );

    controller.submitAnswer(0);
    controller.submitAnswer(0);

    final state = container.read(fallingWordSessionProvider)!;
    expect(state.isComplete, isTrue);
    expect(state.failed, isFalse);
    expect(state.accuracy, 1.0);
    expect(state.isPerfectRound, isTrue);
  });

  test('finishAndApply awards XP/coins to ProgressController exactly once', () {
    final controller = container.read(fallingWordSessionProvider.notifier);
    controller.start(
      mode: FunGameMode.fallingWords,
      questions: [_q('q1')],
      levelConfig: _config,
    );
    controller.submitAnswer(0);

    final xpBefore = container.read(progressProvider).totalXp;
    final result1 = controller.finishAndApply();
    final xpAfter = container.read(progressProvider).totalXp;
    expect(xpAfter - xpBefore, result1.xpEarned);
    expect(result1.xpEarned, greaterThan(0));

    final result2 = controller.finishAndApply();
    expect(result2.xpEarned, result1.xpEarned);
    expect(container.read(progressProvider).totalXp, xpAfter);
  });

  test('finishAndApply feeds correct/incorrect words into shared vocabStrength', () {
    final controller = container.read(fallingWordSessionProvider.notifier);
    controller.start(
      mode: FunGameMode.fallingWords,
      questions: [_q('q1'), _q('q2')],
      levelConfig: _config,
    );
    controller.submitAnswer(0); // correct -> vocab_q1 +1
    controller.submitAnswer(1); // wrong -> vocab_q2 -1

    controller.finishAndApply();
    final progress = container.read(progressProvider);
    expect(progress.vocabStrength['vocab_q1'], 1);
    expect(progress.vocabStrength['vocab_q2'], -1);
  });
}
