import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/daily_goal_logic.dart';
import '../../../core/utils/xp_utils.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gamification_indicators.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/utils/icon_mapper.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/widgets/lingoquest_parrot.dart';
import '../../../data/models/achievement.dart';
import '../../../data/models/course.dart';
import '../../../data/models/last_activity.dart';
import '../../../data/models/user_progress.dart';
import '../../../data/repositories/content_providers.dart';
import '../../access/application/entitlements.dart';
import '../../achievements/application/achievement_providers.dart';
import '../../languages/application/language_switch_controller.dart';
import '../../course/application/course_progress.dart';
import '../../fun/application/fun_game_nav_args.dart';
import '../../fun/application/fun_progress_controller.dart';
import '../../lessons/application/lesson_nav_args.dart';
import '../../onboarding/application/user_controller.dart';
import '../../progress/application/progress_controller.dart';
import '../../rewards/application/mistake_review_providers.dart';
import '../application/motivation_messages.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);

    if (user.currentCourseId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final courseAsync = ref.watch(courseByIdProvider(user.currentCourseId!));

    return Scaffold(
      // Transparent so the shell's textured backdrop shows through.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // Home is where someone lands, so it is where the app says what
        // it is. The counters that used to fill this bar said nothing
        // about the app and two of them have no home here any more:
        // hearts are a per-lesson budget that only means anything once a
        // lesson is running, and the gem currency is gone entirely.
        title: Text(
          'LingoQuest',
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          StreakChip(
            streak: progress.streakCount,
            onTap: () => context.push(AppRoutes.statistics),
          ),
          const SizedBox(width: AppSpacing.xs),
          // The flag doubles as the language switcher, the way it does
          // in every app that teaches more than one language: it says
          // what you are learning *and* is the way to change it.
          _LanguageFlagButton(),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: _ProTag(isPremium: progress.isPremium),
          ),
        ],
      ),
      body: SafeArea(
        child: courseAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => ErrorStateView(
            message: 'Could not load your course.',
            onRetry: () => ref.invalidate(courseByIdProvider(user.currentCourseId!)),
          ),
          data: (course) {
            if (course == null) {
              return const EmptyStateView(
                title: 'No course yet',
                message: 'Something went wrong provisioning your course.',
              );
            }
            return _HomeContent(course: course);
          },
        ),
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  final Course course;
  const _HomeContent({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);
    final current = CourseProgress.findCurrentLesson(course, progress);
    final mistakeCount = ref.watch(mistakeExerciseCountProvider);
    final unlockedAchievements = ref.watch(unlockedAchievementsProvider);

    final user = ref.watch(userProvider);
    final lastActivity = progress.lastActivity;
    final resumeFun = lastActivity?.kind == LastActivityKind.funGame
        ? _funModeFor(lastActivity!.funModeName)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GreetingHeader(
            name: user.name,
            courseTitle: course.title,
            progress: progress,
            mistakeCount: mistakeCount,
          ),
          const SizedBox(height: AppSpacing.lg),
          _DashboardGrid(
            progress: progress,
            achievementCount: unlockedAchievements.length,
          ),
          const SizedBox(height: AppSpacing.lg),
          _DailyGoalCard(progress: progress),
          const SizedBox(height: AppSpacing.lg),
          // Whatever was opened last is what gets resumed. Before this,
          // the card was hardwired to the Path, so leaving a Fun round
          // mid-way and coming Home offered a lesson instead.
          if (resumeFun != null)
            _ContinueFunCard(
              mode: resumeFun,
              subtitle: lastActivity!.subtitle,
              pathFallback: current == null
                  ? null
                  : (course: course, unitIndex: current.$1, lessonIndex: current.$2),
            )
          else if (current != null)
            _ContinueLearningCard(course: course, unitIndex: current.$1, lessonIndex: current.$2)
          else
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: AppColors.accent, size: 32),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      "You've completed ${course.title}! Great work.",
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          if (mistakeCount > 0) ...[
            _ReviewMistakesCard(count: mistakeCount),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text('Recent achievements', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          _RecentAchievementsStrip(unlockedIds: unlockedAchievements),
          const SizedBox(height: AppSpacing.lg),
          _VocabProgressCard(progress: progress),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// Resolves a stored mode name back to the enum, tolerating a name that
/// no longer exists (a mode renamed or removed between releases) by
/// returning null so Home falls back to the Path.
FunGameMode? _funModeFor(String? name) {
  if (name == null) return null;
  for (final mode in FunGameMode.values) {
    if (mode.name == name) return mode;
  }
  return null;
}

/// A friendly hello at the top of Home: the LingoQuest parrot beside the
/// learner's name and a line of encouragement that changes. Gives the
/// dashboard a face instead of opening straight into a wall of numbers.
class _GreetingHeader extends StatefulWidget {
  final String name;
  final String courseTitle;
  final UserProgress progress;
  final int mistakeCount;

  const _GreetingHeader({
    required this.name,
    required this.courseTitle,
    required this.progress,
    required this.mistakeCount,
  });

  @override
  State<_GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends State<_GreetingHeader> {
  /// Advances the message. Seeded off the clock so returning to Home —
  /// after a lesson, a Fun round, or tomorrow — lands on a different
  /// line rather than always the first one.
  late int _tick = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  Timer? _rotation;

  /// Long enough to read twice over, short enough that sitting on Home
  /// shows more than one thought.
  static const _interval = Duration(seconds: 9);

  @override
  void initState() {
    super.initState();
    _rotation = Timer.periodic(_interval, (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _rotation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstName = widget.name.trim().split(' ').first;
    final goalMet = DailyGoalLogic.isGoalMet(widget.progress);

    // The card's tinted background flips from a pale green wash (light
    // mode) to a near-black green (dark mode) — see AppDecor.tint. The
    // message was hardcoded to primaryDark, which reads fine on the pale
    // wash and is almost invisible on the dark one.
    final isDark = theme.brightness == Brightness.dark;
    final messageColor = isDark ? AppColors.green100 : AppColors.primaryDark;

    final message = MotivationMessages.at(
      MotivationMessages.forProgress(
        widget.progress,
        courseTitle: widget.courseTitle,
        mistakeCount: widget.mistakeCount,
      ),
      _tick,
    );

    return AppCard(
      variant: AppCardVariant.tinted,
      tint: AppColors.primary,
      child: Row(
        children: [
          // The mascot sits in its own framed tile rather than loose on
          // the card, which gives the row a deliberate "avatar" anchor.
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            child: LingoQuestParrot(
              size: 62,
              // Grinning once today's goal is in the bag.
              mood: goalMet ? LingoQuestParrotMood.celebrate : LingoQuestParrotMood.happy,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  firstName.isEmpty ? 'Hey there!' : 'Hey $firstName!',
                  // Gold on the dark theme: it reads as the premium
                  // accent the rest of the surface is built around, and
                  // it's the same amber family XP and streaks already
                  // use. Light mode keeps the deep green, where gold on
                  // a pale wash would wash out.
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: isDark ? AppColors.goldHeading : AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                // Cross-fades and lifts as it changes, so a new line
                // reads as the mascot saying something rather than as
                // text quietly swapping underneath you.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.35),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  child: Text(
                    message,
                    key: ValueKey(message),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: messageColor,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-right entry point to the subscription screen — or a quiet badge
/// once the learner already has Pro.
/// The flag of the language being learned, tapped to switch.
///
/// Falls back to a translate glyph before onboarding has chosen one, or
/// while the language list is still loading — never to a wrong flag.
class _LanguageFlagButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(activeLanguageProvider);
    return IconButton(
      tooltip: language == null
          ? 'Switch language'
          : 'Learning ${language.name} — tap to switch',
      onPressed: () => context.push(AppRoutes.languages),
      icon: language == null
          ? const Icon(Icons.translate_rounded)
          : Text(language.flagEmoji, style: const TextStyle(fontSize: 22)),
    );
  }
}

/// The Pro pill in the app bar.
///
/// It is two different things wearing one shape. For somebody who has
/// not bought Pro it is the only upsell on the screen, and it glows to
/// earn the tap. For a subscriber it is a membership badge — still a way
/// into the Pro screen, where the plan and the manage link live, but
/// quiet, because pitching a subscription to the person already paying
/// for it is how you make them look for the cancel button.
class _ProTag extends StatelessWidget {
  final bool isPremium;
  const _ProTag({required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final base = isPremium ? AppColors.success : AppColors.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(base, Colors.white, 0.22)!, base],
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // The glow is the upsell's, not the member's.
        boxShadow: isPremium
            ? null
            : [
                BoxShadow(
                  color: base.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: () => context.push(AppRoutes.premium),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPremium ? Icons.verified_rounded : Icons.bolt_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'PRO',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// At-a-glance progress, read live from [UserProgress] and
/// [FunProgress] rather than stored separately.
///
/// Path and Fun each get their own tile. The account level is XP-based
/// and covers both, which reads as a *Path* level when it sits alone
/// next to nothing else — so it is labelled for what it is, and the two
/// halves of the app are counted explicitly beside it.
class _DashboardGrid extends ConsumerWidget {
  final UserProgress progress;
  final int achievementCount;

  const _DashboardGrid({required this.progress, required this.achievementCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final funProgress = ref.watch(funProgressProvider);
    final funLevels = funProgress.levelsCleared;
    final pathLessons = progress.completedLessonIds.length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 2.1,
      children: [
        StatCard(
          icon: Icons.military_tech_rounded,
          emoji: '🎖️',
          color: AppColors.primary,
          label: 'XP level',
          value: '${XpUtils.levelForXp(progress.totalXp)}',
          onTap: () => context.push(AppRoutes.statistics),
        ),
        StatCard(
          icon: Icons.star_rounded,
          emoji: '⭐',
          color: AppColors.accent,
          label: 'Total XP',
          value: '${progress.totalXp}',
          onTap: () => context.push(AppRoutes.statistics),
        ),
        StatCard(
          icon: Icons.route_rounded,
          emoji: '🛤️',
          color: AppColors.success,
          label: pathLessons == 1 ? 'Path lesson' : 'Path lessons',
          value: '$pathLessons',
          onTap: () => context.go(AppRoutes.path),
        ),
        StatCard(
          icon: Icons.sports_esports_rounded,
          emoji: '🎮',
          color: AppColors.violet,
          label: funLevels == 1 ? 'Fun level' : 'Fun levels',
          value: '$funLevels',
          onTap: () => context.go(AppRoutes.fun),
        ),
        StatCard(
          icon: Icons.local_fire_department_rounded,
          emoji: '🔥',
          color: AppColors.streak,
          label: 'Day streak',
          value: '${progress.streakCount}',
          onTap: () => context.push(AppRoutes.statistics),
        ),
        StatCard(
          icon: Icons.emoji_events_rounded,
          emoji: '🏆',
          color: AppColors.teal,
          label: 'Achievements',
          value: '$achievementCount',
          onTap: () => context.push(AppRoutes.achievements),
        ),
      ],
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  final UserProgress progress;
  const _DailyGoalCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final ratio = DailyGoalLogic.progressRatio(progress);
    final met = DailyGoalLogic.isGoalMet(progress);
    return AppCard(
      child: Row(
        children: [
          ProgressRing(
            progress: ratio,
            color: AppColors.accent,
            trackColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            center: Text(met ? '✅' : '⚡', style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily goal', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  met
                      ? "Goal complete for today!"
                      : '${progress.dailyXp} / ${progress.dailyGoalXp} XP today',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Home's primary call to action.
///
/// [findCurrentLesson] keeps pointing at the next lesson in order even
/// when that lesson is behind the subscription — deliberately, because
/// skipping past Pro-locked lessons to find a playable one would march
/// the learner through the course out of sequence. So the card still
/// names the right lesson; only what the button does changes.
class _ContinueLearningCard extends ConsumerWidget {
  final Course course;
  final int unitIndex;
  final int lessonIndex;

  const _ContinueLearningCard({
    required this.course,
    required this.unitIndex,
    required this.lessonIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = course.units[unitIndex].lessons[lessonIndex];
    final requiresPro = Entitlements.resolveLessonAccess(
          course: course,
          unitIndex: unitIndex,
          lessonIndex: lessonIndex,
          progress: ref.watch(progressProvider),
        ) ==
        LessonAccess.requiresPro;

    return AppCard(
      color: Theme.of(context).colorScheme.primary,
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            course.units[unitIndex].title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            lesson.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: requiresPro ? 'Unlock with Pro' : 'Continue learning',
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).colorScheme.primary,
            onPressed: requiresPro
                ? () => context.push(AppRoutes.premium)
                : () => context.push(
                      AppRoutes.lessonIntro,
                      extra: LessonNavArgs(
                        course: course,
                        unitIndex: unitIndex,
                        lessonIndex: lessonIndex,
                        lesson: lesson,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

/// "Continue learning" when the last thing opened was a Fun game.
///
/// Keeps a quiet link to the Path underneath rather than replacing it —
/// resuming Fun shouldn't make the course feel like it disappeared.
class _ContinueFunCard extends StatelessWidget {
  final FunGameMode mode;
  final String subtitle;
  final ({Course course, int unitIndex, int lessonIndex})? pathFallback;

  const _ContinueFunCard({
    required this.mode,
    required this.subtitle,
    required this.pathFallback,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = pathFallback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          color: theme.colorScheme.primary,
          borderColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FUN ZONE · ${subtitle.toUpperCase()}',
                style: theme.textTheme.labelMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                '${mode.emoji}  ${mode.title}',
                style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Continue learning',
                backgroundColor: Colors.white,
                foregroundColor: theme.colorScheme.primary,
                onPressed: () => context.push(
                  AppRoutes.funGameIntro,
                  extra: FunGameNavArgs(mode: mode),
                ),
              ),
            ],
          ),
        ),
        if (path != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () {
              final lesson = path.course.units[path.unitIndex].lessons[path.lessonIndex];
              context.push(
                AppRoutes.lessonIntro,
                extra: LessonNavArgs(
                  course: path.course,
                  unitIndex: path.unitIndex,
                  lessonIndex: path.lessonIndex,
                  lesson: lesson,
                ),
              );
            },
            icon: const Icon(Icons.route_rounded, size: 18),
            label: Text(
              'Or continue the Path: '
              '${path.course.units[path.unitIndex].lessons[path.lessonIndex].title}',
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewMistakesCard extends StatelessWidget {
  final int count;
  const _ReviewMistakesCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(AppRoutes.lessonIntro, extra: 'review'),
      child: Row(
        children: [
          const Icon(Icons.refresh_rounded, color: AppColors.info, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Review mistakes', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '$count word${count == 1 ? '' : 's'} to review',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _RecentAchievementsStrip extends StatelessWidget {
  final Set<String> unlockedIds;
  const _RecentAchievementsStrip({required this.unlockedIds});

  @override
  Widget build(BuildContext context) {
    if (unlockedIds.isEmpty) {
      return AppCard(
        onTap: () => context.push(AppRoutes.achievements),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Complete lessons to unlock achievements',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    final unlocked =
        achievementCatalog.where((a) => unlockedIds.contains(a.id.name)).toList();

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: unlocked.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) {
          final achievement = unlocked[unlocked.length - 1 - i];
          return GestureDetector(
            onTap: () => context.push(AppRoutes.achievements),
            child: Container(
              width: 84,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(achievementIconFor(achievement.icon), color: AppColors.accent, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    achievement.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VocabProgressCard extends StatelessWidget {
  final UserProgress progress;
  const _VocabProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final strengths = progress.vocabStrength.values;
    final mastered = strengths.where((s) => s >= 4).length;
    final learning = strengths.where((s) => s >= 0 && s < 4).length;
    final weak = strengths.where((s) => s < 0).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vocabulary', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _VocabStat(label: 'Mastered', value: mastered, color: AppColors.success),
              _VocabStat(label: 'Learning', value: learning, color: AppColors.accent),
              _VocabStat(label: 'Weak', value: weak, color: AppColors.error),
            ],
          ),
        ],
      ),
    );
  }
}

class _VocabStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _VocabStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
