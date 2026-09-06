import '../../core/constants/app_enums.dart';

class Achievement {
  final AchievementId id;
  final String title;
  final String description;
  final String icon; // material icon codepoint name, resolved in UI layer
  final int target;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.target,
  });
}

/// Static achievement catalog — original copy, not Duolingo's.
const List<Achievement> achievementCatalog = [
  Achievement(
    id: AchievementId.firstLesson,
    title: 'First Steps',
    description: 'Complete your first lesson',
    icon: 'flag',
    target: 1,
  ),
  Achievement(
    id: AchievementId.streak3,
    title: 'Warming Up',
    description: 'Reach a 3-day streak',
    icon: 'local_fire_department',
    target: 3,
  ),
  Achievement(
    id: AchievementId.streak7,
    title: 'Committed',
    description: 'Reach a 7-day streak',
    icon: 'local_fire_department',
    target: 7,
  ),
  Achievement(
    id: AchievementId.streak30,
    title: 'Unstoppable',
    description: 'Reach a 30-day streak',
    icon: 'local_fire_department',
    target: 30,
  ),
  Achievement(
    id: AchievementId.xp100,
    title: 'Rising Star',
    description: 'Earn 100 total XP',
    icon: 'bolt',
    target: 100,
  ),
  Achievement(
    id: AchievementId.xp500,
    title: 'Dedicated Learner',
    description: 'Earn 500 total XP',
    icon: 'bolt',
    target: 500,
  ),
  Achievement(
    id: AchievementId.xp1000,
    title: 'XP Master',
    description: 'Earn 1000 total XP',
    icon: 'bolt',
    target: 1000,
  ),
  Achievement(
    id: AchievementId.perfectLesson,
    title: 'Flawless',
    description: 'Finish a lesson with 100% accuracy',
    icon: 'star',
    target: 1,
  ),
  Achievement(
    id: AchievementId.fiveLessonsInADay,
    title: 'On a Roll',
    description: 'Complete 5 lessons in a single day',
    icon: 'whatshot',
    target: 5,
  ),
  Achievement(
    id: AchievementId.unitComplete,
    title: 'Unit Champion',
    description: 'Complete every lesson in a unit',
    icon: 'military_tech',
    target: 1,
  ),
  Achievement(
    id: AchievementId.courseComplete,
    title: 'Course Graduate',
    description: 'Complete an entire course',
    icon: 'emoji_events',
    target: 1,
  ),
  Achievement(
    id: AchievementId.wordMaster,
    title: 'Word Master',
    description: 'Learn 100 words',
    icon: 'menu_book',
    target: 100,
  ),
  Achievement(
    id: AchievementId.phraseMaster,
    title: 'Phrase Master',
    description: 'Learn 50 phrases',
    icon: 'record_voice_over',
    target: 50,
  ),
  Achievement(
    id: AchievementId.speedLearner,
    title: 'Speed Learner',
    description: 'Answer 20 questions in a row under 2 seconds each',
    icon: 'speed',
    target: 1,
  ),
  Achievement(
    id: AchievementId.perfectRound,
    title: 'Perfect Round',
    description: 'Complete a Fun round without a single mistake',
    icon: 'verified',
    target: 1,
  ),
];
