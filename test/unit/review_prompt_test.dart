import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/review_service.dart';
import 'package:lingoquest/features/progress/application/lesson_completion_result.dart';
import 'package:lingoquest/features/reviews/application/review_prompt_controller.dart';

/// A stand-in store. Records what was asked of it so the tests can
/// assert that a slot is spent only when the system was really called.
class FakeReviewService implements ReviewService {
  bool available = true;
  int requestCount = 0;
  int openListingCount = 0;
  bool listingConfigured = true;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requestCount++;

  @override
  Future<bool> openStoreListing() async {
    openListingCount++;
    return listingConfigured;
  }
}

LessonCompletionResult _result({bool outOfHearts = false}) {
  return LessonCompletionResult(
    xpEarned: 20,
    newTotalXp: 200,
    leveledUp: false,
    newLevel: 3,
    streakContinued: true,
    newStreakCount: 4,
    dailyGoalJustReached: false,
    newAchievements: const <AchievementId>[],
    unitJustCompleted: false,
    courseJustCompleted: false,
    outOfHearts: outOfHearts,
  );
}

void main() {
  late LocalStorageService storage;
  late FakeReviewService reviews;
  late ReviewPromptController controller;

  final day0 = DateTime(2026, 3, 1);

  Future<void> boot() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.create();
    reviews = FakeReviewService();
    controller = ReviewPromptController(
      storage,
      reviews,
      // Explicit, not the shipping default, which is now 0. These tests
      // are about what happens around the ask — the budget, the
      // spacing, the once-per-session cap — and a soak gives them a
      // state to arrange from. The default itself is covered in "the
      // soak period" below.
      minDaysSinceFirstEligible: 3,
    );
  }

  setUp(boot);

  /// Walks the controller to the point where the only thing left is the
  /// ask itself: enough lessons done, and the waiting period served.
  Future<void> becomeEligible() async {
    await controller.maybeAskAfterLesson(
      result: _result(),
      totalLessonsCompleted: 5,
      now: day0,
    );
  }

  group('what has to be true before LingoQuest asks at all', () {
    test('a learner two lessons in is not asked', () async {
      final outcome = await controller.maybeAskAfterLesson(
        result: _result(),
        totalLessonsCompleted: 2,
        now: day0,
      );

      expect(outcome, ReviewPromptOutcome.notEnoughLessons);
      expect(reviews.requestCount, 0);
      // Nothing is written either — the clock must not start for
      // someone who has not met the bar.
      expect(controller.state.firstEligibleCheckAt, isNull);
    });

    test('the first qualifying lesson starts the clock, it does not ask',
        () async {
      final outcome = await controller.maybeAskAfterLesson(
        result: _result(),
        totalLessonsCompleted: 5,
        now: day0,
      );

      expect(outcome, ReviewPromptOutcome.tooSoonAfterInstall);
      expect(reviews.requestCount, 0);
      expect(controller.state.firstEligibleCheckAt, day0);
    });

    test('still nothing the next day', () async {
      await becomeEligible();

      final outcome = await controller.maybeAskAfterLesson(
        result: _result(),
        totalLessonsCompleted: 6,
        now: day0.add(const Duration(days: 1)),
      );

      expect(outcome, ReviewPromptOutcome.tooSoonAfterInstall);
      expect(reviews.requestCount, 0);
    });

    test('asks once the waiting period is served', () async {
      await becomeEligible();

      final outcome = await controller.maybeAskAfterLesson(
        result: _result(),
        totalLessonsCompleted: 6,
        now: day0.add(const Duration(days: 4)),
      );

      expect(outcome, ReviewPromptOutcome.asked);
      expect(reviews.requestCount, 1);
      expect(controller.state.asksMade, 1);
    });
  });

  group('the moments LingoQuest refuses to ask', () {
    test('never after a lesson that ended out of hearts', () async {
      await becomeEligible();

      final outcome = await controller.maybeAskAfterLesson(
        result: _result(outOfHearts: true),
        totalLessonsCompleted: 20,
        now: day0.add(const Duration(days: 30)),
      );

      expect(outcome, ReviewPromptOutcome.lessonEndedBadly);
      expect(reviews.requestCount, 0);
    });

    test('never twice in one run of the app', () async {
      await becomeEligible();
      await controller.maybeAskAfterLesson(
        result: _result(),
        totalLessonsCompleted: 6,
        now: day0.add(const Duration(days: 4)),
      );

      // Far enough ahead that only the same-session rule can stop it.
      final second = await controller.maybeAskAfterLesson(
        result: _result(),
        totalLessonsCompleted: 7,
        now: day0.add(const Duration(days: 400)),
      );

      expect(second, ReviewPromptOutcome.alreadyAskedThisSession);
      expect(reviews.requestCount, 1);
    });

    test('never again within the cooling-off period', () async {
      await becomeEligible();
      await controller.maybeAskAfterLesson(
        result: _result(),
        totalLessonsCompleted: 6,
        now: day0.add(const Duration(days: 4)),
      );

      // A fresh run of the app, but only a fortnight later.
      final later = ReviewPromptController(storage, reviews);
      final outcome = await later.maybeAskAfterLesson(
        result: _result(),
        totalLessonsCompleted: 12,
        now: day0.add(const Duration(days: 18)),
      );

      expect(outcome, ReviewPromptOutcome.alreadyAskedRecently);
      expect(reviews.requestCount, 1);
    });

    test('stops for good once the budget is spent', () async {
      await becomeEligible();

      var at = day0.add(const Duration(days: 4));
      for (var i = 0; i < ReviewPromptController.maxAsksEver; i++) {
        // Each ask is a separate run of the app, spaced past the
        // cooling-off period.
        final session = ReviewPromptController(storage, reviews);
        final outcome = await session.maybeAskAfterLesson(
          result: _result(),
          totalLessonsCompleted: 30,
          now: at,
        );
        expect(outcome, ReviewPromptOutcome.asked, reason: 'ask ${i + 1}');
        at = at.add(const Duration(days: 200));
      }

      final fourth = ReviewPromptController(storage, reviews);
      final outcome = await fourth.maybeAskAfterLesson(
        result: _result(),
        totalLessonsCompleted: 99,
        now: at,
      );

      expect(outcome, ReviewPromptOutcome.budgetSpent);
      expect(reviews.requestCount, ReviewPromptController.maxAsksEver);
    });

    test('an unavailable store does not burn a slot', () async {
      await becomeEligible();
      reviews.available = false;

      final outcome = await controller.maybeAskAfterLesson(
        result: _result(),
        totalLessonsCompleted: 6,
        now: day0.add(const Duration(days: 4)),
      );

      expect(outcome, ReviewPromptOutcome.storeUnavailable);
      expect(reviews.requestCount, 0);
      // The slot is intact, so a later run can still ask.
      expect(controller.state.asksMade, 0);
      expect(controller.state.lastAskedAt, isNull);
    });
  });

  group('the state survives a restart', () {
    test('a new controller reads the same budget back', () async {
      await becomeEligible();
      await controller.maybeAskAfterLesson(
        result: _result(),
        totalLessonsCompleted: 6,
        now: day0.add(const Duration(days: 4)),
      );

      final reopened = ReviewPromptController(storage, FakeReviewService());
      expect(reopened.state.asksMade, 1);
      expect(reopened.state.lastAskedAt, day0.add(const Duration(days: 4)));
    });

    test('a corrupt blob resets rather than crashing', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.lernova.active_account_id': 'local',
        'flutter.lernova.review_prompt.local': 'not json at all',
      });
      final fresh = await LocalStorageService.create();

      expect(fresh.loadReviewPromptState().asksMade, 0);
    });
  });

  group('the Settings row', () {
    test('opens the store listing rather than requesting a prompt', () async {
      final opened = await controller.openStoreListing();

      expect(opened, isTrue);
      expect(reviews.openListingCount, 1);
      // The deliberate path must never consume the system's budget.
      expect(reviews.requestCount, 0);
    });

    test('reports false when no App Store id is configured yet', () async {
      reviews.listingConfigured = false;

      expect(await controller.openStoreListing(), isFalse);
    });
  });


  group('the daily-goal moment', () {
    test('asks once the same bars are cleared', () async {
      await becomeEligible();

      final outcome = await controller.maybeAskAfterDailyGoal(
        totalLessonsCompleted: 5,
        now: day0.add(const Duration(days: 4)),
      );

      expect(outcome, ReviewPromptOutcome.asked);
      expect(reviews.requestCount, 1);
    });

    test('a learner two lessons in is not asked', () async {
      // Crossing the daily goal is easy — a single short lesson can do
      // it on day one. It is a *trigger*, not evidence of engagement,
      // so the same lesson bar applies.
      final outcome = await controller.maybeAskAfterDailyGoal(
        totalLessonsCompleted: 2,
        now: day0,
      );

      expect(outcome, ReviewPromptOutcome.notEnoughLessons);
      expect(reviews.requestCount, 0);
    });

    test('shares one budget with the post-lesson ask', () async {
      // The defect this pins: Home asked through its own
      // SharedPreferences flag and its own InAppReview instance, so the
      // two paths each believed they had a full allowance. Between them
      // they could spend more of the platform's three-per-year than
      // either one was permitted.
      await becomeEligible();
      final first = await controller.maybeAskAfterDailyGoal(
        totalLessonsCompleted: 5,
        now: day0.add(const Duration(days: 4)),
      );
      expect(first, ReviewPromptOutcome.asked);

      final second = await controller.maybeAskAfterLesson(
        result: _result(),
        totalLessonsCompleted: 6,
        now: day0.add(const Duration(days: 5)),
      );

      expect(second, ReviewPromptOutcome.alreadyAskedRecently);
      expect(reviews.requestCount, 1);
      expect(controller.state.asksMade, 1);
    });

    test('respects the 120-day spacing across sessions', () async {
      await becomeEligible();
      await controller.maybeAskAfterDailyGoal(
        totalLessonsCompleted: 5,
        now: day0.add(const Duration(days: 4)),
      );

      // A fresh run of the app clears the per-session cap but not the
      // persisted one.
      final next = ReviewPromptController(storage, reviews);
      final outcome = await next.maybeAskAfterDailyGoal(
        totalLessonsCompleted: 9,
        now: day0.add(const Duration(days: 40)),
      );

      expect(outcome, ReviewPromptOutcome.alreadyAskedRecently);
      expect(reviews.requestCount, 1);
    });

    test('never spends a slot when the store cannot show anything',
        () async {
      await becomeEligible();
      reviews.available = false;

      final outcome = await controller.maybeAskAfterDailyGoal(
        totalLessonsCompleted: 5,
        now: day0.add(const Duration(days: 4)),
      );

      expect(outcome, ReviewPromptOutcome.storeUnavailable);
      expect(controller.state.asksMade, 0);
    });
  });

  group('the soak period', () {
    test('ships with no soak, so the first qualifying lesson asks', () async {
      // The policy this pins: a learner who has done the lessons is
      // asked at that moment, not three days later.
      //
      // The old default of 3 could not do what it was written for. The
      // first qualifying lesson only *started* the clock, so the
      // earliest ask was three days and one lesson away — and a Play
      // install is a release build, where there is no way to observe
      // any of this. It is also redundant: minLessonsCompleted already
      // tests engagement directly, and a date only proxies it.
      expect(ReviewPromptController.defaultMinDaysSinceFirstEligible, 0);

      final shipping = ReviewPromptController(storage, reviews);
      final outcome = await shipping.maybeAskAfterLesson(
        result: _result(),
        totalLessonsCompleted: 3,
        now: day0,
      );

      expect(outcome, ReviewPromptOutcome.asked);
      expect(reviews.requestCount, 1);
      // The budget is still spent and recorded, so dropping the soak
      // does not make this askable twice.
      expect(shipping.state.asksMade, 1);
    });

    test('no soak does not weaken the lesson bar', () async {
      final shipping = ReviewPromptController(storage, reviews);

      expect(
        await shipping.maybeAskAfterLesson(
          result: _result(),
          totalLessonsCompleted: 2,
          now: day0,
        ),
        ReviewPromptOutcome.notEnoughLessons,
      );
      expect(reviews.requestCount, 0);
    });

    test('no soak still refuses after a lesson lost on hearts', () async {
      // The guard that matters most is unrelated to the clock: never
      // ask someone the moment they failed.
      final shipping = ReviewPromptController(storage, reviews);

      expect(
        await shipping.maybeAskAfterLesson(
          result: _result(outOfHearts: true),
          totalLessonsCompleted: 9,
          now: day0,
        ),
        ReviewPromptOutcome.lessonEndedBadly,
      );
      expect(reviews.requestCount, 0);
    });

    test('a soak, when set, still holds the ask back', () async {
      // The mechanism is retained, not deleted, so the wait can be put
      // back by changing one number.
      final patient =
          ReviewPromptController(storage, reviews, minDaysSinceFirstEligible: 3);

      expect(
        await patient.maybeAskAfterLesson(
          result: _result(),
          totalLessonsCompleted: 5,
          now: day0,
        ),
        ReviewPromptOutcome.tooSoonAfterInstall,
      );
      expect(reviews.requestCount, 0);
      expect(patient.state.firstEligibleCheckAt, day0);
    });
  });

  test('no App Store id is hard-coded', () {
    // Apple assigns this number; guessing one would deep-link the wrong
    // listing. It stays null until the app exists in App Store Connect.
    expect(kAppStoreId, isNull);
  });
}
