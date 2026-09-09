import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/services/service_providers.dart';
import '../../../core/utils/fun_daily_challenge_logic.dart';
import '../../../data/models/fun_progress.dart';
import '../../onboarding/application/user_controller.dart';

const _levelUpAccuracyThreshold = 0.7;

/// Owns per-mode level/combo/star progress and the daily word challenge.
/// XP, coins and vocab mastery are *not* duplicated here — those flow
/// through the shared [ProgressController] instead.
class FunProgressController extends Notifier<FunProgress> {
  /// The language these levels belong to. Watched, not read, so that
  /// switching language rebuilds this controller against the other
  /// language's saved levels instead of leaving Spanish's on screen.
  String? _languageId;

  @override
  FunProgress build() {
    _languageId = ref.watch(userProvider.select((u) => u.selectedLanguageId));
    final storage = ref.read(localStorageServiceProvider);
    final now = DateTime.now();
    final loaded =
        storage.loadFunProgress(languageId: _languageId) ?? FunProgress.initial();
    final reconciled = FunDailyChallengeLogic.reconcileOnResume(loaded, now);
    if (reconciled != loaded) {
      storage.saveFunProgress(reconciled, languageId: _languageId);
    }
    return reconciled;
  }

  void _persist(FunProgress next) {
    state = next;
    ref
        .read(localStorageServiceProvider)
        .saveFunProgress(next, languageId: _languageId);
  }

  /// Levels up the given mode when the round's accuracy clears the bar.
  /// Returns whether it did.
  bool recordRoundResult({
    required FunGameMode mode,
    required double accuracy,
    required int comboAchieved,
    required int starsEarned,
  }) {
    final key = mode.name;
    final leveledUp = accuracy >= _levelUpAccuracyThreshold;

    final levels = Map<String, int>.from(state.gameLevels);
    levels[key] = leveledUp ? state.levelFor(key) + 1 : state.levelFor(key);

    final combos = Map<String, int>.from(state.gameBestCombo);
    if (comboAchieved > state.bestComboFor(key)) {
      combos[key] = comboAchieved;
    }

    final stars = Map<String, int>.from(state.gameStars);
    stars[key] = state.starsFor(key) + starsEarned;

    _persist(state.copyWith(gameLevels: levels, gameBestCombo: combos, gameStars: stars));
    return leveledUp;
  }

  /// Merges newly-correct vocab ids into today's daily-challenge set.
  /// Returns true only on the call that first crosses the target.
  bool recordWordsLearnedToday(Set<String> vocabIds) {
    if (vocabIds.isEmpty) return false;

    final wasComplete = state.dailyChallengeCompletedToday;
    final merged = {...state.dailyChallengeWordIds, ...vocabIds};
    final nowComplete = merged.length >= FunDailyChallengeLogic.targetWordCount;

    _persist(
      state.copyWith(
        dailyChallengeWordIds: merged,
        dailyChallengeCompletedToday: nowComplete,
      ),
    );
    return !wasComplete && nowComplete;
  }

  /// Testing aid only: jumps the two implemented modes' difficulty
  /// level way up so higher tiers (audio prompts, synonym/antonym
  /// questions, combo scoring) can be tested without grinding. The
  /// other 8 modes stay non-playable regardless of level — they aren't
  /// built yet — so this intentionally doesn't touch them.
  void debugUnlockAllFunLevels({int level = 20}) {
    final levels = Map<String, int>.from(state.gameLevels);
    levels[FunGameMode.fallingWords.name] = level;
    levels[FunGameMode.wordRush.name] = level;
    _persist(state.copyWith(gameLevels: levels));
  }
}

final funProgressProvider = NotifierProvider<FunProgressController, FunProgress>(
  FunProgressController.new,
);
