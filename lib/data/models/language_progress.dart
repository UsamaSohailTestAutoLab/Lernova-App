import '../../core/constants/app_enums.dart';
import 'last_activity.dart';

/// Everything in [UserProgress] that belongs to *one* language.
///
/// A learner's history is a fact about a course, not about the account:
/// the lessons done, the words known, the XP earned, the streak kept and
/// the achievements unlocked all describe how far someone has got in
/// *that* language. Carrying them across a switch would be nonsense — a
/// Spanish lesson id means nothing to the Japanese course, and "you know
/// 40 words" is not transferable.
///
/// So [UserProgress] keeps this slice inline for the language being
/// learned right now, and parks a copy of it per language for the rest.
/// Switching is then a park-then-restore, which is exactly what the
/// learner is promised: leave Spanish at Unit 2 Lesson 3 with 900 XP and
/// a 7-day streak, come back to Unit 2 Lesson 3 with 900 XP and a 7-day
/// streak.
///
/// What stays on the account: hearts (a per-session
/// attempt budget), the Pro entitlement (a purchase), and the daily XP
/// target (a setting the learner chose once).
class LanguageProgress {
  final int unlockedUnitIndex;
  final Set<String> completedLessonIds;
  final Set<String> perfectLessonIds;
  final int totalLessonsCompleted;
  final Map<String, int> mistakeBank;
  final Map<String, int> vocabStrength;
  final Set<String> previewedLevelIds;

  /// Where the learner stopped, so returning to this language resumes
  /// the lesson (or Fun round) they abandoned rather than the start.
  final LastActivity? lastActivity;

  /// When this language was last studied. Drives the language list's
  /// ordering and its "last studied" line.
  final DateTime? lastStudiedAt;

  /// XP earned in this language — what Home shows as Total XP, and what
  /// the XP level is derived from.
  final int xpEarned;

  final int dailyXp;
  final DateTime? dailyGoalDate;

  final int weeklyXp;
  final String? weekId;
  final LeagueTier leagueTier;

  final int streakCount;
  final DateTime? lastStreakDate;
  final bool streakFreezeAvailable;

  final Set<String> unlockedAchievementIds;

  final int totalTimeSpentSeconds;
  final int lessonsCompletedToday;
  final DateTime? lessonsCompletedTodayDate;

  const LanguageProgress({
    this.unlockedUnitIndex = 0,
    this.completedLessonIds = const {},
    this.perfectLessonIds = const {},
    this.totalLessonsCompleted = 0,
    this.mistakeBank = const {},
    this.vocabStrength = const {},
    this.previewedLevelIds = const {},
    this.lastActivity,
    this.lastStudiedAt,
    this.xpEarned = 0,
    this.dailyXp = 0,
    this.dailyGoalDate,
    this.weeklyXp = 0,
    this.weekId,
    this.leagueTier = LeagueTier.bronze,
    this.streakCount = 0,
    this.lastStreakDate,
    this.streakFreezeAvailable = false,
    this.unlockedAchievementIds = const {},
    this.totalTimeSpentSeconds = 0,
    this.lessonsCompletedToday = 0,
    this.lessonsCompletedTodayDate,
  });

  /// A language the learner has never opened. Every field is at its zero
  /// value, which is what makes a new language start at Unit 1 Lesson 1
  /// with no history — no special-casing needed at the call site, an
  /// absent slice and a fresh one are the same thing.
  static const LanguageProgress fresh = LanguageProgress();

  /// True when nothing has been done here yet, so the UI can say "Not
  /// started" rather than "0 lessons · Unit 1".
  bool get isUntouched =>
      completedLessonIds.isEmpty &&
      totalLessonsCompleted == 0 &&
      xpEarned == 0 &&
      lastActivity == null;

  LanguageProgress copyWith({
    int? unlockedUnitIndex,
    Set<String>? completedLessonIds,
    Set<String>? perfectLessonIds,
    int? totalLessonsCompleted,
    Map<String, int>? mistakeBank,
    Map<String, int>? vocabStrength,
    Set<String>? previewedLevelIds,
    LastActivity? lastActivity,
    DateTime? lastStudiedAt,
    int? xpEarned,
    int? dailyXp,
    DateTime? dailyGoalDate,
    int? weeklyXp,
    String? weekId,
    LeagueTier? leagueTier,
    int? streakCount,
    DateTime? lastStreakDate,
    bool? streakFreezeAvailable,
    Set<String>? unlockedAchievementIds,
    int? totalTimeSpentSeconds,
    int? lessonsCompletedToday,
    DateTime? lessonsCompletedTodayDate,
  }) {
    return LanguageProgress(
      unlockedUnitIndex: unlockedUnitIndex ?? this.unlockedUnitIndex,
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
      perfectLessonIds: perfectLessonIds ?? this.perfectLessonIds,
      totalLessonsCompleted:
          totalLessonsCompleted ?? this.totalLessonsCompleted,
      mistakeBank: mistakeBank ?? this.mistakeBank,
      vocabStrength: vocabStrength ?? this.vocabStrength,
      previewedLevelIds: previewedLevelIds ?? this.previewedLevelIds,
      lastActivity: lastActivity ?? this.lastActivity,
      lastStudiedAt: lastStudiedAt ?? this.lastStudiedAt,
      xpEarned: xpEarned ?? this.xpEarned,
      dailyXp: dailyXp ?? this.dailyXp,
      dailyGoalDate: dailyGoalDate ?? this.dailyGoalDate,
      weeklyXp: weeklyXp ?? this.weeklyXp,
      weekId: weekId ?? this.weekId,
      leagueTier: leagueTier ?? this.leagueTier,
      streakCount: streakCount ?? this.streakCount,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
      streakFreezeAvailable:
          streakFreezeAvailable ?? this.streakFreezeAvailable,
      unlockedAchievementIds:
          unlockedAchievementIds ?? this.unlockedAchievementIds,
      totalTimeSpentSeconds:
          totalTimeSpentSeconds ?? this.totalTimeSpentSeconds,
      lessonsCompletedToday:
          lessonsCompletedToday ?? this.lessonsCompletedToday,
      lessonsCompletedTodayDate:
          lessonsCompletedTodayDate ?? this.lessonsCompletedTodayDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'unlockedUnitIndex': unlockedUnitIndex,
        'completedLessonIds': completedLessonIds.toList(),
        'perfectLessonIds': perfectLessonIds.toList(),
        'totalLessonsCompleted': totalLessonsCompleted,
        'mistakeBank': mistakeBank,
        'vocabStrength': vocabStrength,
        'previewedLevelIds': previewedLevelIds.toList(),
        'lastActivity': lastActivity?.toJson(),
        'lastStudiedAt': lastStudiedAt?.toIso8601String(),
        'xpEarned': xpEarned,
        'dailyXp': dailyXp,
        'dailyGoalDate': dailyGoalDate?.toIso8601String(),
        'weeklyXp': weeklyXp,
        'weekId': weekId,
        'leagueTier': leagueTier.name,
        'streakCount': streakCount,
        'lastStreakDate': lastStreakDate?.toIso8601String(),
        'streakFreezeAvailable': streakFreezeAvailable,
        'unlockedAchievementIds': unlockedAchievementIds.toList(),
        'totalTimeSpentSeconds': totalTimeSpentSeconds,
        'lessonsCompletedToday': lessonsCompletedToday,
        'lessonsCompletedTodayDate':
            lessonsCompletedTodayDate?.toIso8601String(),
      };

  factory LanguageProgress.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) => json[key] == null
        ? null
        : DateTime.parse(json[key] as String);

    return LanguageProgress(
      unlockedUnitIndex: json['unlockedUnitIndex'] as int? ?? 0,
      completedLessonIds:
          (json['completedLessonIds'] as List? ?? []).cast<String>().toSet(),
      perfectLessonIds:
          (json['perfectLessonIds'] as List? ?? []).cast<String>().toSet(),
      totalLessonsCompleted: json['totalLessonsCompleted'] as int? ?? 0,
      mistakeBank: (json['mistakeBank'] as Map? ?? {})
          .map((k, v) => MapEntry(k as String, v as int)),
      vocabStrength: (json['vocabStrength'] as Map? ?? {})
          .map((k, v) => MapEntry(k as String, v as int)),
      previewedLevelIds:
          (json['previewedLevelIds'] as List? ?? []).cast<String>().toSet(),
      lastActivity:
          LastActivity.fromJson(json['lastActivity'] as Map<String, dynamic>?),
      lastStudiedAt: date('lastStudiedAt'),
      xpEarned: json['xpEarned'] as int? ?? 0,
      dailyXp: json['dailyXp'] as int? ?? 0,
      dailyGoalDate: date('dailyGoalDate'),
      weeklyXp: json['weeklyXp'] as int? ?? 0,
      weekId: json['weekId'] as String?,
      leagueTier: LeagueTier.values.byName(
        json['leagueTier'] as String? ?? 'bronze',
      ),
      streakCount: json['streakCount'] as int? ?? 0,
      lastStreakDate: date('lastStreakDate'),
      streakFreezeAvailable: json['streakFreezeAvailable'] as bool? ?? false,
      unlockedAchievementIds: (json['unlockedAchievementIds'] as List? ?? [])
          .cast<String>()
          .toSet(),
      totalTimeSpentSeconds: json['totalTimeSpentSeconds'] as int? ?? 0,
      lessonsCompletedToday: json['lessonsCompletedToday'] as int? ?? 0,
      lessonsCompletedTodayDate: date('lessonsCompletedTodayDate'),
    );
  }
}
