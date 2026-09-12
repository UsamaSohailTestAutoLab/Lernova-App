import '../../core/constants/app_enums.dart';
import 'pro_entitlement.dart';
import 'language_progress.dart';
import 'last_activity.dart';

/// Single source of truth for everything that makes the game feel alive:
/// XP, hearts, streak, daily goal, unlocks, mistake bank and vocab
/// strength. Persisted as one JSON blob by [LocalStorageService].
class UserProgress {
  final int totalXp;

  final int hearts;
  final DateTime? lastHeartLostAt;
  final bool isPremium;

  /// Why [isPremium] is what it is — store purchase, restore, or a
  /// developer override. Persisted so a reopened app can tell a real
  /// subscription from a leftover test flag.
  final ProEntitlement proEntitlement;

  final int streakCount;
  final DateTime? lastStreakDate;
  final bool streakFreezeAvailable;

  final int dailyXp;
  final DateTime dailyGoalDate;
  final int dailyGoalXp;

  final int unlockedUnitIndex; // highest unit index unlocked (0-based)
  final Set<String> completedLessonIds;
  final Set<String> perfectLessonIds;
  final int totalLessonsCompleted;
  final int totalTimeSpentSeconds;

  final int lessonsCompletedToday;
  final DateTime lessonsCompletedTodayDate;

  final Map<String, int> mistakeBank; // exerciseId -> consecutive correct reviews
  final Map<String, int> vocabStrength; // vocabId -> strength (-2..5)

  final Set<String> unlockedAchievementIds;

  /// Levels whose Review Words step has been completed at least once.
  /// Reviewing is mandatory the first time and optional afterwards, so
  /// this is what tells the two apart.
  final Set<String> previewedLevelIds;

  /// One-off explainers the learner has already been shown — currently
  /// the Level 1 survival tutorial. Kept separate from
  /// [previewedLevelIds]: that one gates a *skippable* review step,
  /// this one gates a screen that should never appear twice.
  final Set<String> seenTutorialIds;

  final int weeklyXp;
  final String weekId;
  final LeagueTier leagueTier;

  /// The last activity the learner opened, Path or Fun. Null until they
  /// start something. Drives Home's "Continue learning" card.
  final LastActivity? lastActivity;

  /// Which language the fields above describe. Null only for an install
  /// from before multi-language support; [ProgressController] adopts the
  /// profile's selected language on first run.
  final String? activeLanguageId;

  /// Every *other* language the learner has touched, frozen at the
  /// moment they left it. The language being learned right now is
  /// deliberately absent here — it lives in the fields above, and a
  /// second copy would immediately go stale.
  final Map<String, LanguageProgress> parkedLanguages;

  const UserProgress({
    this.totalXp = 0,
    this.hearts = 5,
    this.lastHeartLostAt,
    this.isPremium = false,
    this.proEntitlement = ProEntitlement.none,
    this.streakCount = 0,
    this.lastStreakDate,
    this.streakFreezeAvailable = false,
    this.dailyXp = 0,
    required this.dailyGoalDate,
    this.dailyGoalXp = 20,
    this.unlockedUnitIndex = 0,
    this.completedLessonIds = const {},
    this.perfectLessonIds = const {},
    this.totalLessonsCompleted = 0,
    this.totalTimeSpentSeconds = 0,
    this.lessonsCompletedToday = 0,
    required this.lessonsCompletedTodayDate,
    this.mistakeBank = const {},
    this.vocabStrength = const {},
    this.unlockedAchievementIds = const {},
    this.previewedLevelIds = const {},
    this.seenTutorialIds = const {},
    this.weeklyXp = 0,
    required this.weekId,
    this.leagueTier = LeagueTier.bronze,
    this.lastActivity,
    this.activeLanguageId,
    this.parkedLanguages = const {},
  });

  factory UserProgress.initial({required String weekId}) {
    final today = DateTime.now();
    return UserProgress(
      dailyGoalDate: DateTime(today.year, today.month, today.day),
      lessonsCompletedTodayDate: DateTime(today.year, today.month, today.day),
      weekId: weekId,
    );
  }

  UserProgress copyWith({
    int? totalXp,
    int? hearts,
    DateTime? lastHeartLostAt,
    bool clearLastHeartLostAt = false,
    bool? isPremium,
    ProEntitlement? proEntitlement,
    int? streakCount,
    DateTime? lastStreakDate,
    bool clearLastStreakDate = false,
    bool? streakFreezeAvailable,
    int? dailyXp,
    DateTime? dailyGoalDate,
    int? dailyGoalXp,
    int? unlockedUnitIndex,
    Set<String>? completedLessonIds,
    Set<String>? perfectLessonIds,
    int? totalLessonsCompleted,
    int? totalTimeSpentSeconds,
    int? lessonsCompletedToday,
    DateTime? lessonsCompletedTodayDate,
    Map<String, int>? mistakeBank,
    Map<String, int>? vocabStrength,
    Set<String>? unlockedAchievementIds,
    Set<String>? previewedLevelIds,
    Set<String>? seenTutorialIds,
    int? weeklyXp,
    String? weekId,
    LeagueTier? leagueTier,
    LastActivity? lastActivity,
    String? activeLanguageId,
    Map<String, LanguageProgress>? parkedLanguages,
  }) {
    return UserProgress(
      totalXp: totalXp ?? this.totalXp,
      hearts: hearts ?? this.hearts,
      lastHeartLostAt: clearLastHeartLostAt
          ? null
          : (lastHeartLostAt ?? this.lastHeartLostAt),
      isPremium: isPremium ?? this.isPremium,
      proEntitlement: proEntitlement ?? this.proEntitlement,
      streakCount: streakCount ?? this.streakCount,
      lastStreakDate:
          clearLastStreakDate ? null : (lastStreakDate ?? this.lastStreakDate),
      streakFreezeAvailable:
          streakFreezeAvailable ?? this.streakFreezeAvailable,
      dailyXp: dailyXp ?? this.dailyXp,
      dailyGoalDate: dailyGoalDate ?? this.dailyGoalDate,
      dailyGoalXp: dailyGoalXp ?? this.dailyGoalXp,
      unlockedUnitIndex: unlockedUnitIndex ?? this.unlockedUnitIndex,
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
      perfectLessonIds: perfectLessonIds ?? this.perfectLessonIds,
      totalLessonsCompleted:
          totalLessonsCompleted ?? this.totalLessonsCompleted,
      totalTimeSpentSeconds:
          totalTimeSpentSeconds ?? this.totalTimeSpentSeconds,
      lessonsCompletedToday:
          lessonsCompletedToday ?? this.lessonsCompletedToday,
      lessonsCompletedTodayDate:
          lessonsCompletedTodayDate ?? this.lessonsCompletedTodayDate,
      mistakeBank: mistakeBank ?? this.mistakeBank,
      vocabStrength: vocabStrength ?? this.vocabStrength,
      unlockedAchievementIds:
          unlockedAchievementIds ?? this.unlockedAchievementIds,
      previewedLevelIds: previewedLevelIds ?? this.previewedLevelIds,
      seenTutorialIds: seenTutorialIds ?? this.seenTutorialIds,
      weeklyXp: weeklyXp ?? this.weeklyXp,
      weekId: weekId ?? this.weekId,
      leagueTier: leagueTier ?? this.leagueTier,
      lastActivity: lastActivity ?? this.lastActivity,
      activeLanguageId: activeLanguageId ?? this.activeLanguageId,
      parkedLanguages: parkedLanguages ?? this.parkedLanguages,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalXp': totalXp,
        'hearts': hearts,
        'lastHeartLostAt': lastHeartLostAt?.toIso8601String(),
        'isPremium': isPremium,
        'proEntitlement': proEntitlement.toJson(),
        'streakCount': streakCount,
        'lastStreakDate': lastStreakDate?.toIso8601String(),
        'streakFreezeAvailable': streakFreezeAvailable,
        'dailyXp': dailyXp,
        'dailyGoalDate': dailyGoalDate.toIso8601String(),
        'dailyGoalXp': dailyGoalXp,
        'unlockedUnitIndex': unlockedUnitIndex,
        'completedLessonIds': completedLessonIds.toList(),
        'perfectLessonIds': perfectLessonIds.toList(),
        'totalLessonsCompleted': totalLessonsCompleted,
        'totalTimeSpentSeconds': totalTimeSpentSeconds,
        'lessonsCompletedToday': lessonsCompletedToday,
        'lessonsCompletedTodayDate':
            lessonsCompletedTodayDate.toIso8601String(),
        'mistakeBank': mistakeBank,
        'vocabStrength': vocabStrength,
        'unlockedAchievementIds': unlockedAchievementIds.toList(),
        'previewedLevelIds': previewedLevelIds.toList(),
        'seenTutorialIds': seenTutorialIds.toList(),
        'weeklyXp': weeklyXp,
        'weekId': weekId,
        'leagueTier': leagueTier.name,
        'lastActivity': lastActivity?.toJson(),
        'activeLanguageId': activeLanguageId,
        'parkedLanguages':
            parkedLanguages.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      totalXp: json['totalXp'] as int? ?? 0,
      hearts: json['hearts'] as int? ?? 5,
      lastHeartLostAt: json['lastHeartLostAt'] != null
          ? DateTime.parse(json['lastHeartLostAt'] as String)
          : null,
      isPremium: json['isPremium'] as bool? ?? false,
      proEntitlement: json['proEntitlement'] == null
          ? ProEntitlement.none
          : ProEntitlement.fromJson(json['proEntitlement'] as Map<String, dynamic>),
      streakCount: json['streakCount'] as int? ?? 0,
      lastStreakDate: json['lastStreakDate'] != null
          ? DateTime.parse(json['lastStreakDate'] as String)
          : null,
      streakFreezeAvailable: json['streakFreezeAvailable'] as bool? ?? false,
      dailyXp: json['dailyXp'] as int? ?? 0,
      dailyGoalDate: DateTime.parse(json['dailyGoalDate'] as String),
      dailyGoalXp: json['dailyGoalXp'] as int? ?? 20,
      unlockedUnitIndex: json['unlockedUnitIndex'] as int? ?? 0,
      completedLessonIds:
          (json['completedLessonIds'] as List? ?? []).cast<String>().toSet(),
      perfectLessonIds:
          (json['perfectLessonIds'] as List? ?? []).cast<String>().toSet(),
      totalLessonsCompleted: json['totalLessonsCompleted'] as int? ?? 0,
      totalTimeSpentSeconds: json['totalTimeSpentSeconds'] as int? ?? 0,
      lessonsCompletedToday: json['lessonsCompletedToday'] as int? ?? 0,
      lessonsCompletedTodayDate:
          DateTime.parse(json['lessonsCompletedTodayDate'] as String),
      mistakeBank: (json['mistakeBank'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, v as int),
      ),
      vocabStrength: (json['vocabStrength'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, v as int),
      ),
      unlockedAchievementIds: (json['unlockedAchievementIds'] as List? ?? [])
          .cast<String>()
          .toSet(),
      previewedLevelIds:
          (json['previewedLevelIds'] as List? ?? []).cast<String>().toSet(),
      seenTutorialIds:
          (json['seenTutorialIds'] as List? ?? []).cast<String>().toSet(),
      weeklyXp: json['weeklyXp'] as int? ?? 0,
      weekId: json['weekId'] as String,
      leagueTier: LeagueTier.values.byName(
        json['leagueTier'] as String? ?? 'bronze',
      ),
      lastActivity: LastActivity.fromJson(
        json['lastActivity'] as Map<String, dynamic>?,
      ),
      activeLanguageId: json['activeLanguageId'] as String?,
      parkedLanguages: (json['parkedLanguages'] as Map? ?? {}).map(
        (k, v) => MapEntry(
          k as String,
          LanguageProgress.fromJson(v as Map<String, dynamic>),
        ),
      ),
    );
  }

  /// The language-scoped fields above, packaged as a slice — the form
  /// they get parked in when the learner leaves this language.
  LanguageProgress get activeSlice => LanguageProgress(
        unlockedUnitIndex: unlockedUnitIndex,
        completedLessonIds: completedLessonIds,
        perfectLessonIds: perfectLessonIds,
        totalLessonsCompleted: totalLessonsCompleted,
        mistakeBank: mistakeBank,
        vocabStrength: vocabStrength,
        previewedLevelIds: previewedLevelIds,
        lastActivity: lastActivity,
        xpEarned: totalXp,
        dailyXp: dailyXp,
        dailyGoalDate: dailyGoalDate,
        weeklyXp: weeklyXp,
        weekId: weekId,
        leagueTier: leagueTier,
        streakCount: streakCount,
        lastStreakDate: lastStreakDate,
        streakFreezeAvailable: streakFreezeAvailable,
        unlockedAchievementIds: unlockedAchievementIds,
        totalTimeSpentSeconds: totalTimeSpentSeconds,
        lessonsCompletedToday: lessonsCompletedToday,
        lessonsCompletedTodayDate: lessonsCompletedTodayDate,
      );

  /// Progress for any language, active or parked. Returns a fresh slice
  /// for one that has never been opened, so callers never have to tell
  /// "never started" apart from "started and did nothing".
  LanguageProgress sliceForLanguage(String languageId) {
    if (languageId == activeLanguageId) return activeSlice;
    return parkedLanguages[languageId] ?? LanguageProgress.fresh;
  }

  /// Every language with something worth showing on the language list,
  /// the active one included.
  Set<String> get startedLanguageIds => {
        for (final entry in parkedLanguages.entries)
          if (!entry.value.isUntouched) entry.key,
        if (activeLanguageId != null && !activeSlice.isUntouched)
          activeLanguageId!,
      };

  /// Parks [from]'s progress and restores whatever [to] had.
  ///
  /// [from] is passed in rather than read off [activeLanguageId] so an
  /// install predating that field can still name the language its inline
  /// progress belongs to. Getting it wrong would silently misfile a
  /// course's history; there is no way to detect that later, so the
  /// caller is made to say.
  ///
  /// The restored language is *removed* from [parkedLanguages]: its data
  /// now lives inline, and a leftover parked copy would be a second
  /// version of the truth that stops updating.
  ///
  /// A restored slice can be missing its dates and week id — that is
  /// what a never-opened language looks like — so those fall back to
  /// [now] and the account's current week. Everything time-based is then
  /// reconciled by [ProgressController] on the way out.
  UserProgress switchLanguage({
    required String from,
    required String to,
    DateTime? now,
  }) {
    if (from == to) return copyWith(activeLanguageId: to);

    final at = now ?? DateTime.now();
    final today = DateTime(at.year, at.month, at.day);

    final parked = Map<String, LanguageProgress>.from(parkedLanguages);
    final leaving = activeSlice;
    parked[from] =
        leaving.isUntouched ? leaving : leaving.copyWith(lastStudiedAt: at);

    final arriving = parked.remove(to) ?? LanguageProgress.fresh;

    return UserProgress(
      // The account: an attempt budget, a purchase, and a target the
      // learner set once. None of these describe a course.
      hearts: hearts,
      lastHeartLostAt: lastHeartLostAt,
      isPremium: isPremium,
      proEntitlement: proEntitlement,
      dailyGoalXp: dailyGoalXp,
      seenTutorialIds: seenTutorialIds,
      // The course: swapped wholesale.
      unlockedUnitIndex: arriving.unlockedUnitIndex,
      completedLessonIds: arriving.completedLessonIds,
      perfectLessonIds: arriving.perfectLessonIds,
      totalLessonsCompleted: arriving.totalLessonsCompleted,
      mistakeBank: arriving.mistakeBank,
      vocabStrength: arriving.vocabStrength,
      previewedLevelIds: arriving.previewedLevelIds,
      lastActivity: arriving.lastActivity,
      totalXp: arriving.xpEarned,
      dailyXp: arriving.dailyXp,
      dailyGoalDate: arriving.dailyGoalDate ?? today,
      weeklyXp: arriving.weeklyXp,
      weekId: arriving.weekId ?? weekId,
      leagueTier: arriving.leagueTier,
      streakCount: arriving.streakCount,
      lastStreakDate: arriving.lastStreakDate,
      streakFreezeAvailable: arriving.streakFreezeAvailable,
      unlockedAchievementIds: arriving.unlockedAchievementIds,
      totalTimeSpentSeconds: arriving.totalTimeSpentSeconds,
      lessonsCompletedToday: arriving.lessonsCompletedToday,
      lessonsCompletedTodayDate: arriving.lessonsCompletedTodayDate ?? today,
      activeLanguageId: to,
      parkedLanguages: parked,
    );
  }

  /// This progress as it would look if [slice] were the active language.
  ///
  /// Lets pure course logic — `findCurrentLesson`, `lessonState` — run
  /// against a *parked* language without switching to it, which is what
  /// the language list needs to show "Unit 2 · Lesson 3" for a course
  /// you are not currently in.
  UserProgress viewAs(LanguageProgress slice) => copyWith(
        unlockedUnitIndex: slice.unlockedUnitIndex,
        completedLessonIds: slice.completedLessonIds,
        perfectLessonIds: slice.perfectLessonIds,
        totalLessonsCompleted: slice.totalLessonsCompleted,
        mistakeBank: slice.mistakeBank,
        vocabStrength: slice.vocabStrength,
        previewedLevelIds: slice.previewedLevelIds,
        totalXp: slice.xpEarned,
        streakCount: slice.streakCount,
        unlockedAchievementIds: slice.unlockedAchievementIds,
      );
}
