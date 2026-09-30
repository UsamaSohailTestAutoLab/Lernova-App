import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lingoquest/core/analytics/analytics_events.dart';
import 'package:lingoquest/core/analytics/analytics_providers.dart';
import 'package:lingoquest/core/analytics/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/core/utils/fun_daily_challenge_logic.dart';
import 'package:lingoquest/features/fun/application/fun_progress_controller.dart';

void main() {
  late ProviderContainer container;

  group("analytics", _analyticsTests);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
  });

  test('a fresh FunProgress starts every mode at level 1', () {
    final progress = container.read(funProgressProvider);
    expect(progress.levelFor(FunGameMode.fallingWords.name), 1);
  });

  // Home shows this beside the Path lesson count, so "how many Fun
  // levels have I done" has to mean levels *cleared*, not the level
  // number you happen to be sitting on.
  group('levelsCleared', () {
    test('a player who has never finished a round has cleared none', () {
      expect(container.read(funProgressProvider).levelsCleared, 0);
    });

    test('counts cleared levels, not the level you are on', () {
      final controller = container.read(funProgressProvider.notifier);
      for (var i = 0; i < 3; i++) {
        controller.recordRoundResult(
          mode: FunGameMode.fallingWords,
          accuracy: 0.9,
          comboAchieved: 1,
          starsEarned: 1,
        );
      }

      final progress = container.read(funProgressProvider);
      expect(progress.levelFor(FunGameMode.fallingWords.name), 4);
      expect(progress.levelsCleared, 3);
    });

    test('sums across every mode played', () {
      final controller = container.read(funProgressProvider.notifier);
      controller.recordRoundResult(
        mode: FunGameMode.fallingWords,
        accuracy: 0.9,
        comboAchieved: 1,
        starsEarned: 1,
      );
      controller.recordRoundResult(
        mode: FunGameMode.wordMatch,
        accuracy: 0.9,
        comboAchieved: 1,
        starsEarned: 1,
      );
      controller.recordRoundResult(
        mode: FunGameMode.wordMatch,
        accuracy: 0.9,
        comboAchieved: 1,
        starsEarned: 1,
      );

      final progress = container.read(funProgressProvider);
      expect(progress.levelsCleared, 3);
      expect(progress.modesPlayed, 2);
    });

    test('a failed round adds nothing', () {
      final controller = container.read(funProgressProvider.notifier);
      controller.recordRoundResult(
        mode: FunGameMode.fallingWords,
        accuracy: 0.2,
        comboAchieved: 1,
        starsEarned: 0,
      );
      expect(container.read(funProgressProvider).levelsCleared, 0);
      expect(container.read(funProgressProvider).modesPlayed, 0);
    });
  });

  group('recordRoundResult', () {
    test('good accuracy levels the mode up', () {
      final controller = container.read(funProgressProvider.notifier);
      final leveledUp = controller.recordRoundResult(
        mode: FunGameMode.fallingWords,
        accuracy: 0.9,
        comboAchieved: 5,
        starsEarned: 3,
      );
      expect(leveledUp, isTrue);
      final progress = container.read(funProgressProvider);
      expect(progress.levelFor(FunGameMode.fallingWords.name), 2);
      expect(progress.bestComboFor(FunGameMode.fallingWords.name), 5);
      expect(progress.starsFor(FunGameMode.fallingWords.name), 3);
    });

    test('poor accuracy does not level the mode up', () {
      final controller = container.read(funProgressProvider.notifier);
      final leveledUp = controller.recordRoundResult(
        mode: FunGameMode.fallingWords,
        accuracy: 0.3,
        comboAchieved: 1,
        starsEarned: 0,
      );
      expect(leveledUp, isFalse);
      expect(
        container.read(funProgressProvider).levelFor(FunGameMode.fallingWords.name),
        1,
      );
    });

    test('best combo only ever increases', () {
      final controller = container.read(funProgressProvider.notifier);
      controller.recordRoundResult(
        mode: FunGameMode.wordRush,
        accuracy: 0.5,
        comboAchieved: 10,
        starsEarned: 1,
      );
      controller.recordRoundResult(
        mode: FunGameMode.wordRush,
        accuracy: 0.5,
        comboAchieved: 4,
        starsEarned: 1,
      );
      expect(container.read(funProgressProvider).bestComboFor(FunGameMode.wordRush.name), 10);
    });
  });

  group('recordWordsLearnedToday', () {
    test('reports completion exactly once when crossing the target', () {
      final controller = container.read(funProgressProvider.notifier);
      final ids = List.generate(
        FunDailyChallengeLogic.targetWordCount,
        (i) => 'word_$i',
      ).toSet();

      final justCompleted = controller.recordWordsLearnedToday(ids);
      expect(justCompleted, isTrue);
      expect(container.read(funProgressProvider).dailyChallengeCompletedToday, isTrue);

      final again = controller.recordWordsLearnedToday({'word_extra'});
      expect(again, isFalse);
    });

    test('does not complete before the target is reached', () {
      final controller = container.read(funProgressProvider.notifier);
      final justCompleted = controller.recordWordsLearnedToday({'word_1', 'word_2'});
      expect(justCompleted, isFalse);
      expect(container.read(funProgressProvider).dailyChallengeCompletedToday, isFalse);
    });
  });
}

/// The analytics a finished round records.
///
/// Split out from the rest of this file because it needs its own
/// container, with a recorder in place of the no-op the app ships.
void _analyticsTests() {
  late ProviderContainer container;
  late RecordingAnalytics analytics;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    analytics = RecordingAnalytics();
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        analyticsProvider.overrideWithValue(analytics),
      ],
    );
    addTearDown(container.dispose);
  });

  test('a finished round is recorded once', () {
    container.read(funProgressProvider.notifier).recordRoundResult(
          mode: FunGameMode.fallingWords,
          accuracy: 0.8,
          comboAchieved: 4,
          starsEarned: 2,
        );

    expect(analytics.countOf(AnalyticsEvent.gameRoundCompleted), 1);
    final p = analytics.paramsFor(AnalyticsEvent.gameRoundCompleted).single;
    expect(p[AnalyticsParam.gameMode], 'fallingWords');
    expect(p[AnalyticsParam.completionPercent], 80);
    expect(p[AnalyticsParam.score], 2);
  });

  test('it reports the level played, not the one just unlocked', () {
    final notifier = container.read(funProgressProvider.notifier);
    // An accuracy this high promotes the mode, so the level afterwards
    // is 2. The round itself was played at 1, and reporting 2 would make
    // every game look as though it were being won a level early.
    final leveledUp = notifier.recordRoundResult(
      mode: FunGameMode.fallingWords,
      accuracy: 1.0,
      comboAchieved: 6,
      starsEarned: 3,
    );

    expect(leveledUp, isTrue);
    expect(container.read(funProgressProvider).levelFor('fallingWords'), 2);
    expect(
      analytics.paramsFor(AnalyticsEvent.gameRoundCompleted)
          .single[AnalyticsParam.gameLevel],
      1,
    );
  });
}
