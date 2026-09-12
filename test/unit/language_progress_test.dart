import 'package:flutter_test/flutter_test.dart';
import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/data/models/language_progress.dart';
import 'package:lingoquest/data/models/last_activity.dart';
import 'package:lingoquest/data/models/pro_entitlement.dart';
import 'package:lingoquest/data/models/user_progress.dart';

UserProgress _spanishInProgress() => UserProgress(
      dailyGoalDate: DateTime(2026, 9, 9),
      lessonsCompletedTodayDate: DateTime(2026, 9, 9),
      weekId: '2026-W37',
      activeLanguageId: 'es',
      // Account-level: an attempt budget, a purchase, a target.
      hearts: 3,
      isPremium: true,
      proEntitlement: const ProEntitlement(
        productId: 'com.monthly.learning',
        source: ProSource.store,
      ),
      dailyGoalXp: 30,
      seenTutorialIds: {'water_survival'},
      // Spanish's own history.
      totalXp: 1200,
      dailyXp: 40,
      weeklyXp: 260,
      leagueTier: LeagueTier.silver,
      streakCount: 12,
      lastStreakDate: DateTime(2026, 9, 8),
      streakFreezeAvailable: true,
      unlockedAchievementIds: {'first_lesson', 'week_streak'},
      totalTimeSpentSeconds: 4200,
      lessonsCompletedToday: 2,
      unlockedUnitIndex: 1,
      completedLessonIds: {'es_u1_l1', 'es_u1_l2', 'es_u1_l3'},
      perfectLessonIds: {'es_u1_l1'},
      totalLessonsCompleted: 3,
      mistakeBank: {'es_u2_l1_e3': 1},
      vocabStrength: {'es_hola': 4, 'es_gracias': 2},
      previewedLevelIds: {'es_u2_l1'},
      lastActivity: LastActivity.pathLesson(
        at: DateTime(2026, 9, 8),
        courseId: 'course_es',
        lessonId: 'es_u2_l1',
        unitIndex: 1,
        lessonIndex: 0,
        title: 'Family Members',
        subtitle: 'Unit 2',
      ),
    );

void main() {
  group('switching language parks one course and restores the other', () {
    test('a language never opened before starts from the beginning', () {
      final next = _spanishInProgress().switchLanguage(from: 'es', to: 'fr');

      expect(next.activeLanguageId, 'fr');
      expect(next.unlockedUnitIndex, 0);
      expect(next.completedLessonIds, isEmpty);
      expect(next.perfectLessonIds, isEmpty);
      expect(next.totalLessonsCompleted, 0);
      expect(next.mistakeBank, isEmpty);
      expect(next.vocabStrength, isEmpty);
      expect(next.previewedLevelIds, isEmpty);
      // Nothing to resume — the Home card must not offer a Spanish
      // lesson to someone who just switched to French.
      expect(next.lastActivity, isNull);
    });

    // The whole of Home's dashboard is a claim about one course, so none
    // of it may follow the learner into another language.
    test('a new language shows no history from the old one', () {
      final next = _spanishInProgress().switchLanguage(from: 'es', to: 'fr');

      expect(next.totalXp, 0, reason: 'Total XP');
      expect(next.dailyXp, 0);
      expect(next.weeklyXp, 0);
      expect(next.leagueTier, LeagueTier.bronze);
      expect(next.streakCount, 0, reason: 'Day streak');
      expect(next.lastStreakDate, isNull);
      expect(next.streakFreezeAvailable, isFalse);
      expect(next.unlockedAchievementIds, isEmpty, reason: 'Achievements');
      expect(next.totalTimeSpentSeconds, 0);
      expect(next.lessonsCompletedToday, 0);
    });

    test('what the learner leaves behind is exactly what they come back to',
        () {
      final before = _spanishInProgress();
      final inFrench = before.switchLanguage(from: 'es', to: 'fr');
      final back = inFrench.switchLanguage(from: 'fr', to: 'es');

      expect(back.activeLanguageId, 'es');
      expect(back.unlockedUnitIndex, before.unlockedUnitIndex);
      expect(back.completedLessonIds, before.completedLessonIds);
      expect(back.perfectLessonIds, before.perfectLessonIds);
      expect(back.totalLessonsCompleted, before.totalLessonsCompleted);
      expect(back.mistakeBank, before.mistakeBank);
      expect(back.vocabStrength, before.vocabStrength);
      expect(back.previewedLevelIds, before.previewedLevelIds);
      expect(back.lastActivity?.lessonId, 'es_u2_l1');
      // ...history included.
      expect(back.totalXp, 1200);
      expect(back.streakCount, 12);
      expect(back.lastStreakDate, DateTime(2026, 9, 8));
      expect(back.unlockedAchievementIds, {'first_lesson', 'week_streak'});
      expect(back.weeklyXp, 260);
      expect(back.leagueTier, LeagueTier.silver);
      expect(back.totalTimeSpentSeconds, 4200);
    });

    // Hearts are an attempt budget, Pro a purchase, and the daily
    // target a setting. None of them is a claim about a course.
    test('the account keeps its hearts, Pro and settings', () {
      final before = _spanishInProgress();
      final next = before.switchLanguage(from: 'es', to: 'ja');

      expect(next.hearts, before.hearts);
      expect(next.isPremium, isTrue);
      expect(next.proEntitlement.productId, 'com.monthly.learning');
      expect(next.dailyGoalXp, 30);
      expect(next.seenTutorialIds, {'water_survival'});
    });

    test('the language being learned is never also parked', () {
      final next = _spanishInProgress().switchLanguage(from: 'es', to: 'fr');

      expect(next.parkedLanguages.keys, contains('es'));
      expect(
        next.parkedLanguages.keys,
        isNot(contains('fr')),
        reason: 'a parked copy of the active language would go stale',
      );
    });

    test('progress in one language cannot leak into another', () {
      // Spanish → French, do some French work, → German, → back.
      var progress = _spanishInProgress().switchLanguage(from: 'es', to: 'fr');
      progress = progress.copyWith(
        completedLessonIds: {'fr_u1_l1'},
        totalLessonsCompleted: 1,
        totalXp: 90,
        streakCount: 1,
        vocabStrength: {'fr_bonjour': 3},
      );
      progress = progress.switchLanguage(from: 'fr', to: 'de');

      expect(progress.completedLessonIds, isEmpty, reason: 'German is new');
      expect(progress.vocabStrength, isEmpty);
      expect(progress.totalXp, 0);
      expect(progress.streakCount, 0);

      progress = progress.switchLanguage(from: 'de', to: 'es');
      expect(progress.completedLessonIds, hasLength(3));
      expect(progress.vocabStrength.keys, contains('es_hola'));
      expect(progress.totalXp, 1200);

      progress = progress.switchLanguage(from: 'es', to: 'fr');
      expect(progress.completedLessonIds, {'fr_u1_l1'});
      expect(progress.totalXp, 90);
      expect(progress.streakCount, 1);
    });

    test('switching to the language already active changes nothing', () {
      final before = _spanishInProgress();
      final next = before.switchLanguage(from: 'es', to: 'es');

      expect(next.completedLessonIds, before.completedLessonIds);
      expect(next.totalXp, before.totalXp);
      expect(next.parkedLanguages, isEmpty);
      expect(next.activeLanguageId, 'es');
    });

    test('leaving stamps when the language was last studied', () {
      final next = _spanishInProgress()
          .switchLanguage(from: 'es', to: 'fr', now: DateTime(2026, 9, 9, 14));

      expect(
        next.parkedLanguages['es']!.lastStudiedAt,
        DateTime(2026, 9, 9, 14),
      );
    });

    test('a language left untouched is not stamped as studied', () {
      var progress = _spanishInProgress().switchLanguage(from: 'es', to: 'fr');
      progress = progress.switchLanguage(
        from: 'fr',
        to: 'de',
        now: DateTime(2026, 9, 9),
      );

      expect(progress.parkedLanguages['fr']!.isUntouched, isTrue);
      expect(progress.parkedLanguages['fr']!.lastStudiedAt, isNull);
    });

    // A blank slice carries no dates; leaving those null would crash the
    // non-nullable fields they restore into.
    test('a fresh language gets today for its date-keyed counters', () {
      final next = _spanishInProgress()
          .switchLanguage(from: 'es', to: 'fr', now: DateTime(2026, 9, 9, 14));

      expect(next.dailyGoalDate, DateTime(2026, 9, 9));
      expect(next.lessonsCompletedTodayDate, DateTime(2026, 9, 9));
      expect(next.weekId, '2026-W37', reason: 'the account week carries over');
    });
  });

  group('reading another language without switching to it', () {
    test('the active language reads back its live progress', () {
      final progress = _spanishInProgress();
      expect(progress.sliceForLanguage('es').completedLessonIds, hasLength(3));
      expect(progress.sliceForLanguage('es').xpEarned, 1200);
    });

    test('a parked language reads back what was parked', () {
      final progress = _spanishInProgress().switchLanguage(from: 'es', to: 'fr');
      expect(progress.sliceForLanguage('es').completedLessonIds, hasLength(3));
      expect(progress.sliceForLanguage('es').xpEarned, 1200);
      expect(progress.sliceForLanguage('es').streakCount, 12);
    });

    test('a language never opened reads back a blank slice', () {
      final slice = _spanishInProgress().sliceForLanguage('zh');
      expect(slice.isUntouched, isTrue);
      expect(slice.unlockedUnitIndex, 0);
    });

    test('only started languages are listed as started', () {
      final progress = _spanishInProgress().switchLanguage(from: 'es', to: 'fr');
      expect(progress.startedLanguageIds, {'es'});
    });

    test('viewAs runs course logic against a language you are not in', () {
      final progress = _spanishInProgress().switchLanguage(from: 'es', to: 'fr');
      final asSpanish = progress.viewAs(progress.sliceForLanguage('es'));

      expect(asSpanish.completedLessonIds, hasLength(3));
      expect(asSpanish.unlockedUnitIndex, 1);
      expect(asSpanish.totalXp, 1200);
      // Still the same account underneath.
      expect(asSpanish.hearts, 3);
    });
  });

  group('persistence', () {
    test('parked languages survive a round trip through JSON', () {
      final original = _spanishInProgress()
          .switchLanguage(from: 'es', to: 'fr', now: DateTime(2026, 9, 9))
          .copyWith(completedLessonIds: {'fr_u1_l1'}, totalXp: 90);

      final restored = UserProgress.fromJson(original.toJson());

      expect(restored.activeLanguageId, 'fr');
      expect(restored.completedLessonIds, {'fr_u1_l1'});
      expect(restored.totalXp, 90);

      final spanish = restored.sliceForLanguage('es');
      expect(spanish.completedLessonIds, hasLength(3));
      expect(spanish.perfectLessonIds, {'es_u1_l1'});
      expect(spanish.vocabStrength['es_hola'], 4);
      expect(spanish.unlockedUnitIndex, 1);
      expect(spanish.lastStudiedAt, DateTime(2026, 9, 9));
      expect(spanish.lastActivity?.lessonId, 'es_u2_l1');
      expect(spanish.xpEarned, 1200);
      expect(spanish.streakCount, 12);
      expect(spanish.leagueTier, LeagueTier.silver);
      expect(spanish.unlockedAchievementIds, hasLength(2));
      expect(spanish.lastStreakDate, DateTime(2026, 9, 8));
    });

    test('an install from before multi-language reads back unchanged', () {
      // No activeLanguageId, no parkedLanguages — the shape written by
      // the version that only knew one language.
      final legacy = UserProgress.fromJson({
        'totalXp': 500,
        'dailyGoalDate': '2026-09-09T00:00:00.000',
        'lessonsCompletedTodayDate': '2026-09-09T00:00:00.000',
        'weekId': '2026-W37',
        'unlockedUnitIndex': 2,
        'completedLessonIds': ['es_u1_l1'],
        'streakCount': 9,
      });

      expect(legacy.activeLanguageId, isNull);
      expect(legacy.parkedLanguages, isEmpty);
      expect(legacy.totalXp, 500);
      expect(legacy.streakCount, 9);
      expect(legacy.unlockedUnitIndex, 2);
      expect(legacy.completedLessonIds, {'es_u1_l1'});
    });

    test('a blank slice round-trips', () {
      final restored =
          LanguageProgress.fromJson(LanguageProgress.fresh.toJson());
      expect(restored.isUntouched, isTrue);
      expect(restored.lastActivity, isNull);
      expect(restored.lastStudiedAt, isNull);
      expect(restored.weekId, isNull);
      expect(restored.dailyGoalDate, isNull);
    });
  });
}
