import '../../core/constants/app_enums.dart';
import 'last_activity.dart';

/// Single source of truth for everything that makes the game feel alive:
/// XP, hearts, streak, daily goal, unlocks, mistake bank and vocab
/// strength. Persisted as one JSON blob by [LocalStorageService].
class UserProgress {
  final int totalXp;
  final int gems;

  final int hearts;
  final DateTime? lastHeartLostAt;
  final bool isPremium;

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

  final int weeklyXp;
  final String weekId;
  final LeagueTier leagueTier;

  /// The last activity the learner opened, Path or Fun. Null until they
  /// start something. Drives Home's "Continue learning" card.
  final LastActivity? lastActivity;

  const UserProgress({
    this.totalXp = 0,
    this.gems = 100,
    this.hearts = 5,
    this.lastHeartLostAt,
    this.isPremium = false,
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
    this.weeklyXp = 0,
    required this.weekId,
    this.leagueTier = LeagueTier.bronze,
    this.lastActivity,
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
    int? gems,
    int? hearts,
    DateTime? lastHeartLostAt,
    bool clearLastHeartLostAt = false,
    bool? isPremium,
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
    int? weeklyXp,
    String? weekId,
    LeagueTier? leagueTier,
    LastActivity? lastActivity,
  }) {
    return UserProgress(
      totalXp: totalXp ?? this.totalXp,
      gems: gems ?? this.gems,
      hearts: hearts ?? this.hearts,
      lastHeartLostAt: clearLastHeartLostAt
          ? null
          : (lastHeartLostAt ?? this.lastHeartLostAt),
      isPremium: isPremium ?? this.isPremium,
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
      weeklyXp: weeklyXp ?? this.weeklyXp,
      weekId: weekId ?? this.weekId,
      leagueTier: leagueTier ?? this.leagueTier,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalXp': totalXp,
        'gems': gems,
        'hearts': hearts,
        'lastHeartLostAt': lastHeartLostAt?.toIso8601String(),
        'isPremium': isPremium,
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
        'weeklyXp': weeklyXp,
        'weekId': weekId,
        'leagueTier': leagueTier.name,
        'lastActivity': lastActivity?.toJson(),
      };

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      totalXp: json['totalXp'] as int? ?? 0,
      gems: json['gems'] as int? ?? 100,
      hearts: json['hearts'] as int? ?? 5,
      lastHeartLostAt: json['lastHeartLostAt'] != null
          ? DateTime.parse(json['lastHeartLostAt'] as String)
          : null,
      isPremium: json['isPremium'] as bool? ?? false,
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
      weeklyXp: json['weeklyXp'] as int? ?? 0,
      weekId: json['weekId'] as String,
      leagueTier: LeagueTier.values.byName(
        json['leagueTier'] as String? ?? 'bronze',
      ),
      lastActivity: LastActivity.fromJson(
        json['lastActivity'] as Map<String, dynamic>?,
      ),
    );
  }
}
