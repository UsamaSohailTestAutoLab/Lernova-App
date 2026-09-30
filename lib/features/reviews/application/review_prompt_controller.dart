import 'package:flutter/foundation.dart' show kDebugMode;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_storage_service.dart';
import '../../../core/services/review_service.dart';
import '../../../core/services/service_providers.dart';
import '../../../data/models/review_prompt_state.dart';
import '../../progress/application/lesson_completion_result.dart';

final reviewServiceProvider = Provider<ReviewService>((ref) => ReviewService());

/// Why the app did or did not ask for a review.
///
/// Returned so the decision is inspectable in tests and in a debug
/// build. It describes *our* decision only — when the answer is [asked],
/// the system still decides independently whether anything appeared.
enum ReviewPromptOutcome {
  asked,
  notEnoughLessons,
  tooSoonAfterInstall,
  lessonEndedBadly,
  alreadyAskedRecently,
  budgetSpent,
  alreadyAskedThisSession,
  storeUnavailable,
}

/// Decides when LingoQuest may ask for a store review.
///
/// The platform rules this implements, and the reason for each:
///
///  * **Only the system prompt, never a custom one.** App Store Review
///    Guideline 1.1.7 requires the provided API for ratings; a bespoke
///    dialog is a rejection. [ReviewService] is the only caller of it.
///  * **No gating.** Apple forbids asking "do you like the app?" first
///    and routing only the happy answers to the real prompt. There is no
///    pre-question here — eligibility is decided from behaviour the
///    learner already showed, and then the system prompt is requested
///    directly.
///  * **No incentive.** Nothing is offered for reviewing. No XP, no
///    hearts, no Pro trial.
///  * **Never mid-task.** The ask happens as the post-lesson reward
///    chain ends and the learner is returning to Home, so it never
///    interrupts an exercise, a game or a purchase.
///  * **Not after a bad session.** A lesson that ended because the
///    learner ran out of hearts is the worst possible moment, and it is
///    excluded outright.
///  * **Spend the budget well.** iOS allows three prompts per year and
///    silently drops the rest. The thresholds below aim the first ask at
///    someone who has actually used the app, not someone two screens in.
///
/// Nothing anywhere records whether a review was left. Neither platform
/// reports it, so no feature may depend on it.
class ReviewPromptController {
  final LocalStorageService _storage;
  final ReviewService _reviews;

  /// A learner who has finished fewer lessons than this has not seen
  /// enough of the app to have a view worth asking for.
  static const minLessonsCompleted = 3;

  /// Days between first eligibility and the earliest ask. Long enough
  /// that the prompt lands on someone who came back, not someone still
  /// in their first sitting.
  static const minDaysSinceFirstEligible = 3;

  /// Days between one ask and the next. Comfortably wider than needed:
  /// three asks at this spacing cannot exceed iOS's yearly allowance
  /// even if every one of them is granted.
  static const minDaysBetweenAsks = 120;

  /// Our own ceiling, matching the platform's. Once spent, this install
  /// stops asking — the Settings row remains for anyone who wants to
  /// leave a review deliberately.
  static const maxAsksEver = 3;

  /// One ask per run of the app, whatever else qualifies. Two prompts in
  /// one sitting would be the most annoying possible reading of the
  /// rules above.
  bool _askedThisSession = false;

  ReviewPromptController(this._storage, this._reviews);

  ReviewPromptState get state => _storage.loadReviewPromptState();

  /// Evaluates and, if everything lines up, asks the system to show its
  /// rating prompt.
  ///
  /// Call this at the end of the post-lesson reward chain. [now] is
  /// injectable so the date arithmetic is testable without waiting
  /// three days.
  Future<ReviewPromptOutcome> maybeAskAfterLesson({
    required LessonCompletionResult result,
    required int totalLessonsCompleted,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();

    // Worst moment there is: they just lost. Checked before anything is
    // written, so a bad session cannot even start the clock.
    if (result.outOfHearts) return ReviewPromptOutcome.lessonEndedBadly;

    return _askIfEligible(at, totalLessonsCompleted);
  }

  /// Evaluates and, if everything lines up, asks after the learner has
  /// just met their daily goal.
  ///
  /// The other good moment: a goal met is a small win, and it lands on
  /// Home rather than inside a lesson. It shares every rule above —
  /// same soak period, same 120-day spacing, same lifetime budget, same
  /// once-per-session cap — because they are one budget, not two.
  ///
  /// Home used to do this itself: its own `SharedPreferences` flag and a
  /// direct `InAppReview.instance` call, which walked straight past all
  /// of it. The daily goal is reachable on day one, so that path fired
  /// first in practice, spent one of the platform's three yearly
  /// prompts, and left this controller still believing it had asked
  /// nobody.
  Future<ReviewPromptOutcome> maybeAskAfterDailyGoal({
    required int totalLessonsCompleted,
    DateTime? now,
  }) =>
      _askIfEligible(now ?? DateTime.now(), totalLessonsCompleted);

  Future<ReviewPromptOutcome> _askIfEligible(
    DateTime at,
    int totalLessonsCompleted,
  ) async {
    if (totalLessonsCompleted < minLessonsCompleted) {
      return ReviewPromptOutcome.notEnoughLessons;
    }

    var current = state;

    // First time they reach the bar, note the date and stop. The wait
    // is measured from genuine engagement, not from install.
    if (current.firstEligibleCheckAt == null) {
      current = current.copyWith(firstEligibleCheckAt: at);
      await _storage.saveReviewPromptState(current);
      return ReviewPromptOutcome.tooSoonAfterInstall;
    }

    if (at.difference(current.firstEligibleCheckAt!).inDays <
        minDaysSinceFirstEligible) {
      return ReviewPromptOutcome.tooSoonAfterInstall;
    }

    if (current.asksMade >= maxAsksEver) return ReviewPromptOutcome.budgetSpent;

    final last = current.lastAskedAt;
    if (last != null && at.difference(last).inDays < minDaysBetweenAsks) {
      return ReviewPromptOutcome.alreadyAskedRecently;
    }

    if (_askedThisSession) {
      return ReviewPromptOutcome.alreadyAskedThisSession;
    }

    // Asked last, so an unavailable store does not spend a slot.
    if (!await _reviews.isAvailable()) {
      return ReviewPromptOutcome.storeUnavailable;
    }

    await _reviews.requestReview();
    _askedThisSession = true;
    await _storage.saveReviewPromptState(
      current.copyWith(asksMade: current.asksMade + 1, lastAskedAt: at),
    );
    return ReviewPromptOutcome.asked;
  }

  /// The deliberate path: the learner tapped "Rate LingoQuest".
  ///
  /// Opens the write-review page rather than requesting the system
  /// prompt, because a button that may silently do nothing is a broken
  /// button. Returns false when no App Store id is configured yet.
  Future<bool> openStoreListing() => _reviews.openStoreListing();

  /// Requests the system prompt immediately, skipping every rule above.
  ///
  /// For verifying the wiring only, and gated on [kDebugMode] at its one
  /// call site in Settings. It exists because the rules make the real
  /// prompt almost impossible to observe deliberately: three lessons, a
  /// three-day wait, and then the exact moment a daily goal is crossed.
  /// Waiting three days to find out whether a store dialog appears is
  /// not a workable way to check a release.
  ///
  /// It does not touch [asksMade] or [lastAskedAt] — a debug ask must not
  /// consume the real budget, or testing the prompt would be what stops
  /// the app asking a genuine learner later.
  ///
  /// Returns what the store said about itself. On Android false means
  /// Play reports the review flow unavailable; true means the request
  /// went through, which is **not** the same as the sheet appearing.
  Future<bool> debugAskNow() async {
    if (!await _reviews.isAvailable()) return false;
    await _reviews.requestReview();
    return true;
  }
}

final reviewPromptProvider = Provider<ReviewPromptController>((ref) {
  return ReviewPromptController(
    ref.watch(localStorageServiceProvider),
    ref.watch(reviewServiceProvider),
  );
});
