import '../../../core/utils/daily_goal_logic.dart';
import '../../../data/models/user_progress.dart';

/// The rotating line under Home's greeting.
///
/// Built from the learner's actual state rather than a fixed string, so
/// it can say something true — a streak worth protecting, words that
/// need another look, a goal already met — and falls back to general
/// encouragement about language learning when there's nothing specific
/// to point at.
///
/// Pure and dependency-free so it can be unit-tested directly.
class MotivationMessages {
  MotivationMessages._();

  /// Every line that currently applies, most specific first. Never
  /// empty: the evergreen pool always contributes.
  static List<String> forProgress(
    UserProgress progress, {
    required String courseTitle,
    int mistakeCount = 0,
  }) {
    final lines = <String>[];
    final goalMet = DailyGoalLogic.isGoalMet(progress);
    final streak = progress.streakCount;
    final remaining = progress.dailyGoalXp - progress.dailyXp;

    if (goalMet) {
      lines.addAll([
        "Today's goal is done — anything more is a bonus.",
        'Goal met. This is the part most people skip.',
        'Done for today. Tomorrow gets easier because of it.',
      ]);
    } else if (progress.dailyXp > 0) {
      lines.add('$remaining XP to go. You\'re already moving.');
      lines.add('Halfway is a real place. Keep going.');
    } else {
      lines.add('One short lesson is enough to count today.');
      lines.add('Start small. Starting is the hard part.');
    }

    if (streak >= 7) {
      lines.add('$streak days running. That is how fluency is built.');
    } else if (streak >= 2) {
      lines.add('$streak days in a row — consistency beats cramming.');
    } else if (streak == 1) {
      lines.add('Day one of a streak. Day two is what makes it one.');
    }

    if (mistakeCount > 0) {
      lines.add(
        '$mistakeCount word${mistakeCount == 1 ? '' : 's'} still shaky — '
        'reviewing beats re-learning.',
      );
      lines.add('The words you got wrong are the ones worth revisiting.');
    }

    final mastered = progress.vocabStrength.values.where((s) => s >= 4).length;
    if (mastered >= 10) {
      lines.add('$mastered words mastered. You can hear them in the wild now.');
    }

    // Evergreen: always available, so there is never nothing to say.
    lines.addAll([
      'Ten minutes a day outruns three hours on Sunday.',
      'Say it out loud — your mouth needs the practice too.',
      'Mistakes are data. Collect a few today.',
      'You are not bad at $courseTitle. You are early.',
      'Understanding comes before speaking. Both come with reps.',
      'Every word you learn is one you will recognise later.',
      "You don't need talent. You need Tuesdays.",
      'Forgetting is part of remembering. Come back anyway.',
    ]);

    return lines;
  }

  /// Picks the line for [tick], cycling through [lines] in order.
  /// Separated from [forProgress] so rotation is trivially testable and
  /// deterministic — no randomness to make a screen flicker between two
  /// different messages on consecutive rebuilds.
  static String at(List<String> lines, int tick) {
    if (lines.isEmpty) return '';
    return lines[tick.abs() % lines.length];
  }
}
