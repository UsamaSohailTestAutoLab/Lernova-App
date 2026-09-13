import 'package:flutter_test/flutter_test.dart';

import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/data/models/course.dart';
import 'package:lingoquest/data/models/course_unit.dart';
import 'package:lingoquest/data/models/lesson.dart';
import 'package:lingoquest/data/models/pro_entitlement.dart';
import 'package:lingoquest/data/models/user_progress.dart';
import 'package:lingoquest/features/access/application/entitlements.dart';

/// The free tier is one Path lesson and one Fun level. These pin both
/// halves of that, and — just as importantly — that subscribing gives
/// back ordinary progression rather than opening everything at once.
Lesson _lesson(String id, String title) =>
    Lesson(id: id, title: title, subtitle: '', exercises: const []);

Course _course() => Course(
      id: 'course_es',
      languageId: 'es',
      title: 'Spanish',
      description: '',
      placementQuestions: const [],
      units: [
        CourseUnit(
          id: 'u1',
          title: 'Greetings & Basics',
          description: '',
          lessons: [
            _lesson('es_u1_l1', 'Say Hello'),
            _lesson('es_u1_l2', 'Yes, No, Sorry'),
            _lesson('es_u1_l3', 'Polite Basics'),
          ],
        ),
        CourseUnit(
          id: 'u2',
          title: 'Food & Family',
          description: '',
          lessons: [
            _lesson('es_u2_l1', 'Family Members'),
            _lesson('es_u2_l2', 'Food Basics'),
          ],
        ),
      ],
    );

UserProgress _progress({
  bool pro = false,
  Set<String> completed = const {},
  int unlockedUnitIndex = 0,
}) {
  final base = UserProgress.initial(weekId: '2026-W37').copyWith(
    completedLessonIds: completed,
    unlockedUnitIndex: unlockedUnitIndex,
  );
  if (!pro) return base;
  return base.copyWith(
    isPremium: true,
    proEntitlement: const ProEntitlement(status: EntitlementStatus.subscribedActive, source: ProSource.store),
  );
}

LessonAccess _access(
  int unitIndex,
  int lessonIndex, {
  bool pro = false,
  Set<String> completed = const {},
  int unlockedUnitIndex = 0,
}) =>
    Entitlements.resolveLessonAccess(
      course: _course(),
      unitIndex: unitIndex,
      lessonIndex: lessonIndex,
      progress: _progress(
        pro: pro,
        completed: completed,
        unlockedUnitIndex: unlockedUnitIndex,
      ),
    );

void main() {
  group('the Path, without a subscription', () {
    test('Say Hello is open on a brand new account', () {
      expect(_access(0, 0), LessonAccess.open);
    });

    test('the next lesson asks for Pro, even once Say Hello is done', () {
      // The exact tap the whole change exists for: finish the free
      // lesson, reach for the next one, meet the paywall.
      expect(
        _access(0, 1, completed: {'es_u1_l1'}),
        LessonAccess.requiresPro,
      );
    });

    test('so does every lesson after it, and every later unit', () {
      expect(_access(0, 2), LessonAccess.requiresPro);
      expect(_access(1, 0), LessonAccess.requiresPro);
      expect(_access(1, 1), LessonAccess.requiresPro);
    });

    test('an unreached lesson says Pro, not "finish the one before"', () {
      // Lesson 3 is behind lesson 2 by progression *and* behind the
      // paywall. Naming the progression rule would be technically true
      // and useless: they cannot get to lesson 2 either.
      expect(_access(0, 2), LessonAccess.requiresPro);
    });

    test('a placement jump grants order, not entitlement', () {
      // unlockedUnitIndex is how far the learner has been placed. It has
      // never meant "paid for", and it must not start meaning it.
      expect(
        _access(1, 0, unlockedUnitIndex: 1),
        LessonAccess.requiresPro,
      );
    });

    test('Say Hello stays open after it has been completed', () {
      // Replaying the free lesson is the only practice a free account
      // has; taking it away the moment it is finished would leave the
      // app with nothing to do at all.
      expect(_access(0, 0, completed: {'es_u1_l1'}), LessonAccess.open);
    });
  });

  group('the Path, with a subscription', () {
    test('the second lesson opens once the first is done', () {
      expect(
        _access(0, 1, pro: true, completed: {'es_u1_l1'}),
        LessonAccess.open,
      );
    });

    test('the rest of the course opens at once, not one lesson at a time', () {
      // Paying opens everything — CourseProgress treats isPremium as a
      // read-time override on the sequential rule, so a subscriber can
      // jump ahead rather than re-earning the order they already paid
      // to skip. Access is recomputed on every build, so cancelling
      // closes it all again without anything to undo.
      expect(
        _access(0, 2, pro: true, completed: {'es_u1_l1'}),
        LessonAccess.open,
      );
      expect(_access(1, 1, pro: true), LessonAccess.open);
    });

    test('a later unit is reachable', () {
      expect(_access(1, 0, pro: true), LessonAccess.open);
    });
  });

  group('the Fun Zone, without a subscription', () {
    test('Word Bubble level 1 is open', () {
      expect(
        Entitlements.resolveFunAccess(
          mode: FunGameMode.fallingWords,
          level: 1,
          progress: _progress(),
        ),
        FunAccess.open,
      );
    });

    test('Word Bubble level 2 asks for Pro', () {
      // Clearing level 1 moves the learner to level 2, so this is what
      // "Next Level" hits the moment the free level is finished.
      expect(
        Entitlements.resolveFunAccess(
          mode: FunGameMode.fallingWords,
          level: 2,
          progress: _progress(),
        ),
        FunAccess.requiresPro,
      );
    });

    test('every other game asks for Pro, even at level 1', () {
      for (final mode in FunGameMode.values) {
        if (mode == FunGameMode.fallingWords) continue;
        expect(
          Entitlements.resolveFunAccess(
            mode: mode,
            level: 1,
            progress: _progress(),
          ),
          FunAccess.requiresPro,
          reason: '${mode.title} must be behind the paywall',
        );
      }
    });
  });

  group('the Fun Zone, with a subscription', () {
    test('the Fun level ladder no longer applies', () {
      // Pro is sold as "every game in the Fun Zone". Keeping the ladder
      // for members is what left a paid account at Fun level 2 looking
      // at eight padlocks: only Word Bubble and Word Rush unlock at
      // level 1.
      for (final mode in FunGameMode.values) {
        expect(
          Entitlements.isFunModeUnlockedByLevel(
            mode: mode,
            overallLevel: 2,
            progress: _progress(pro: true),
          ),
          isTrue,
          reason: '${mode.title} (unlocks at ${mode.unlockLevel}) must open',
        );
      }
    });

    test('the ladder still applies to everybody else', () {
      // It is not dead code: it is what orders the free Fun Zone, and
      // taking entitlement out of the question must not take it away.
      expect(
        Entitlements.isFunModeUnlockedByLevel(
          mode: FunGameMode.wordSurvival,
          overallLevel: 2,
          progress: _progress(),
        ),
        isFalse,
      );
      expect(
        Entitlements.isFunModeUnlockedByLevel(
          mode: FunGameMode.fallingWords,
          overallLevel: 2,
          progress: _progress(),
        ),
        isTrue,
      );
    });

    test('every game at every level opens', () {
      for (final mode in FunGameMode.values) {
        for (final level in [1, 2, 7, 40]) {
          expect(
            Entitlements.resolveFunAccess(
              mode: mode,
              level: level,
              progress: _progress(pro: true),
            ),
            FunAccess.open,
            reason: '${mode.title} level $level',
          );
        }
      }
    });
  });

  group('what the free tier is', () {
    test('exactly one lesson and one Fun level', () {
      expect(Entitlements.isLessonFree(0, 0), isTrue);
      expect(Entitlements.isLessonFree(0, 1), isFalse);
      expect(Entitlements.isLessonFree(1, 0), isFalse);

      expect(Entitlements.isFunLevelFree(FunGameMode.fallingWords, 1), isTrue);
      expect(Entitlements.isFunLevelFree(FunGameMode.fallingWords, 2), isFalse);
      expect(Entitlements.isFunLevelFree(FunGameMode.wordRush, 1), isFalse);
    });

    test('is positional, so it means the same in every language', () {
      // Held as unit 0 / lesson 0 rather than the id `es_u1_l1`, so
      // adding a language does not need a matching entry anywhere.
      expect(Entitlements.freeUnitIndex, 0);
      expect(Entitlements.freeLessonIndex, 0);
      expect(Entitlements.freeFunMode, FunGameMode.fallingWords);
      expect(Entitlements.freeFunLevel, 1);
    });
  });
}
