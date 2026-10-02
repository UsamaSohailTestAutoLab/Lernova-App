import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_storage_service.dart';
import '../../../core/services/review_service.dart';
import '../../../core/services/service_providers.dart';
import '../../../data/models/review_prompt_state.dart';
import '../../progress/application/lesson_completion_result.dart';

final reviewServiceProvider = Provider<ReviewService>((ref) => ReviewService());

/// Turns on the review diagnostics in a build that is not a debug build.
///
///     flutter build appbundle --dart-define=REVIEW_DEBUG=true
///
/// A Play install — including an internal test — is a release build, so
/// `kDebugMode` is false and everything that helps diagnose this
/// disappears exactly where it is most needed: the decision log, and
/// the Settings row that fires the prompt on demand. Without them the
/// only available observation is "nothing happened", which is also what
/// six different refusals look like.
///
/// Off unless asked for, so a store build carries neither.
const kReviewDebug = bool.fromEnvironment('REVIEW_DEBUG');

/// Whether to log review decisions and show the manual trigger.
bool get reviewDiagnosticsOn => kDebugMode || kReviewDebug;

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

  /// Days to wait between first eligibility and the earliest ask.
  ///
  /// Zero: the ask happens at the first qualifying moment.
  ///
  /// This was three. The intent was that the prompt should land on
  /// someone who came back rather than someone still in their first
  /// sitting, which is sound in general and wrong here, for two
  /// reasons.
  ///
  /// The arithmetic never worked. The first qualifying lesson only
  /// *starts* the clock, so the earliest possible ask was three days
  /// and one lesson later. A learner who finishes three lessons and
  /// does not return for three days is not the learner worth asking,
  /// and the one who does return gets asked on a day they may not have
  /// had a good session.
  ///
  /// And [minLessonsCompleted] already does this job better. Three
  /// completed lessons is evidence of engagement; a date is a proxy for
  /// it. Keeping both meant the weaker test set the schedule.
  ///
  /// What actually stops this becoming nagging is unchanged and is
  /// where it belongs: [maxAsksEver] three times ever,
  /// [minDaysBetweenAsks] 120 days apart, one per session, never after
  /// a lesson the learner lost, and both stores rate-limiting on top.
  static const defaultMinDaysSinceFirstEligible = 0;

  /// Days to wait before the first ask.
  ///
  /// Injected rather than fixed so a debug build can set it to zero.
  /// Otherwise the feature cannot be exercised at all without waiting
  /// three days — and `flutter install` wipes app storage, so the clock
  /// restarts on every deploy and the three days never elapse.
  ///
  /// The default is the shipping value, so a test that does not mention
  /// this gets the real policy. Tying it to [kDebugMode] inside the
  /// class looked simpler and was wrong: tests run in debug, so the
  /// policy that ships would have been the one policy never tested.
  final int minDaysSinceFirstEligible;

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

  ReviewPromptController(
    this._storage,
    this._reviews, {
    this.minDaysSinceFirstEligible = defaultMinDaysSinceFirstEligible,
  });

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

  /// Reports every decision to the log in debug builds.
  ///
  /// "The prompt didn't appear" has at least six causes here and three
  /// more inside the store, and none of them announce themselves. This
  /// turns that into one line naming the reason.
  ///
  /// Note what [ReviewPromptOutcome.asked] does and does not mean: the
  /// request reached the store. Neither store reports whether a sheet
  /// was drawn, and on Android the Play In-App Review API returns a
  /// no-op flow for any app Play did not install — so a sideloaded
  /// build logs `asked` and shows nothing, correctly.
  ReviewPromptOutcome _log(ReviewPromptOutcome outcome, [String? detail]) {
    if (reviewDiagnosticsOn) {
      debugPrint('[review] $outcome${detail == null ? '' : ' — $detail'}');
    }
    return outcome;
  }

  Future<ReviewPromptOutcome> _askIfEligible(
    DateTime at,
    int totalLessonsCompleted,
  ) async {
    if (totalLessonsCompleted < minLessonsCompleted) {
      return _log(ReviewPromptOutcome.notEnoughLessons,
          '$totalLessonsCompleted of $minLessonsCompleted lessons done');
    }

    var current = state;

    // First time they reach the bar, note the date. The wait is
    // measured from genuine engagement, not from install.
    //
    // Stopping here is only right when there is a wait to serve. With
    // the soak at zero — debug builds — returning early would mean the
    // prompt could never fire on the lesson that first qualifies, which
    // is exactly the moment under test.
    if (current.firstEligibleCheckAt == null) {
      current = current.copyWith(firstEligibleCheckAt: at);
      await _storage.saveReviewPromptState(current);
      if (minDaysSinceFirstEligible > 0) {
        return _log(ReviewPromptOutcome.tooSoonAfterInstall,
            'clock started; earliest ask in $minDaysSinceFirstEligible days');
      }
    }

    final waited = at.difference(current.firstEligibleCheckAt!).inDays;
    if (waited < minDaysSinceFirstEligible) {
      return _log(ReviewPromptOutcome.tooSoonAfterInstall,
          'waited ${waited}d of ${minDaysSinceFirstEligible}d');
    }

    if (current.asksMade >= maxAsksEver) {
      return _log(ReviewPromptOutcome.budgetSpent,
          '${current.asksMade} of $maxAsksEver spent');
    }

    final last = current.lastAskedAt;
    if (last != null && at.difference(last).inDays < minDaysBetweenAsks) {
      return _log(ReviewPromptOutcome.alreadyAskedRecently,
          'last ask ${at.difference(last).inDays}d ago, '
          'need ${minDaysBetweenAsks}d');
    }

    if (_askedThisSession) {
      return _log(ReviewPromptOutcome.alreadyAskedThisSession);
    }

    // Asked last, so an unavailable store does not spend a slot.
    if (!await _reviews.isAvailable()) {
      return _log(ReviewPromptOutcome.storeUnavailable,
          'the store reports no review flow here');
    }

    await _reviews.requestReview();
    _askedThisSession = true;
    await _storage.saveReviewPromptState(
      current.copyWith(asksMade: current.asksMade + 1, lastAskedAt: at),
    );
    return _log(ReviewPromptOutcome.asked,
        'request sent — the store decides whether a sheet is drawn');
  }

  /// The deliberate path: the learner tapped "Rate LingoQuest".
  ///
  /// Opens the write-review page rather than requesting the system
  /// prompt, because a button that may silently do nothing is a broken
  /// button. Returns false when no App Store id is configured yet.
  Future<bool> openStoreListing() => _reviews.openStoreListing();

  /// Requests the system prompt immediately, skipping every rule above.
  ///
  /// For verifying the wiring only, and gated on [reviewDiagnosticsOn] at its one
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
