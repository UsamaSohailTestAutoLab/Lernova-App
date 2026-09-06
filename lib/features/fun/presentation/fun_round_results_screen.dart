import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/spark_mascot.dart';
import '../../../data/repositories/fun_content_providers.dart';
import '../../onboarding/application/user_controller.dart';
import '../../progress/application/progress_controller.dart';
import '../application/falling_word_session_controller.dart';
import '../application/fun_level_catalog.dart';
import '../application/fun_progress_controller.dart';
import '../application/fun_question_generator.dart';

class FunRoundResultsScreen extends ConsumerStatefulWidget {
  const FunRoundResultsScreen({super.key});

  @override
  ConsumerState<FunRoundResultsScreen> createState() => _FunRoundResultsScreenState();
}

class _FunRoundResultsScreenState extends ConsumerState<FunRoundResultsScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(fallingWordSessionProvider);
      if (session != null && !session.failed) _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _playAgain(FallingWordSessionState session) async {
    final languageId = ref.read(userProvider).selectedLanguageId;
    if (languageId == null) return;
    final level = ref.read(funProgressProvider).levelFor(session.mode.name);
    final levelConfig = FunLevelCatalog.configFor(level, mode: session.mode);

    final questions = FunQuestionGenerator.generateRound(
      words: await ref.read(funVocabWordsProvider(languageId).future),
      phrases: await ref.read(funPhrasesProvider(languageId).future),
      level: levelConfig,
      vocabStrength: ref.read(progressProvider).vocabStrength,
      random: Random(),
    );

    ref.read(fallingWordSessionProvider.notifier).start(
          mode: session.mode,
          questions: questions,
          levelConfig: levelConfig,
        );
    if (mounted) context.pushReplacement(AppRoutes.funGamePlay);
  }

  Future<void> _practiceMistakes(FallingWordSessionState session) async {
    final languageId = ref.read(userProvider).selectedLanguageId;
    if (languageId == null) return;
    final words = await ref.read(funVocabWordsProvider(languageId).future);
    final missedIds =
        session.vocabDeltas.entries.where((e) => e.value < 0).map((e) => e.key).toList();
    final questions = FunQuestionGenerator.generatePracticeRound(
      words: words,
      vocabIds: missedIds,
      choiceCount: session.levelConfig.bubbleOptionCount,
      random: Random(),
    );
    if (questions.isEmpty) {
      await _playAgain(session);
      return;
    }
    ref.read(fallingWordSessionProvider.notifier).start(
          mode: session.mode,
          questions: questions,
          levelConfig: session.levelConfig,
        );
    if (mounted) context.pushReplacement(AppRoutes.funGamePlay);
  }

  void _done() {
    ref.read(fallingWordSessionProvider.notifier).reset();
    context.go(AppRoutes.fun);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(fallingWordSessionProvider);
    final theme = Theme.of(context);

    if (session == null || session.result == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final result = session.result!;
    final missedWordCount =
        session.vocabDeltas.entries.where((e) => e.value < 0).length;

    return Scaffold(
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  const Spacer(),
                  SparkMascot(
                    size: 120,
                    mood: session.failed ? SparkMood.sad : SparkMood.celebrate,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    session.failed ? 'Almost there! 💪' : 'Level Complete! 🎉',
                    style: theme.textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (!session.failed && session.funLeveledUp) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      "You've leveled up!",
                      style: theme.textTheme.titleMedium?.copyWith(color: AppColors.accent),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.md,
                    alignment: WrapAlignment.center,
                    children: [
                      _Stat(label: 'XP', value: '+${result.xpEarned}', color: AppColors.accent),
                      _Stat(
                        label: 'Coins',
                        value: '+${session.coinsEarned}',
                        color: AppColors.gem,
                      ),
                      _Stat(
                        label: 'Best combo',
                        value: '${session.bestCombo}',
                        color: AppColors.streak,
                      ),
                      _Stat(
                        label: 'Accuracy',
                        value: '${(session.accuracy * 100).round()}%',
                        color: AppColors.success,
                      ),
                    ],
                  ),
                  if (session.speedAchieved) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text('⚡ Speed Learner bonus!', style: theme.textTheme.bodyMedium),
                  ],
                  if (session.dailyChallengeJustCompleted) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(AppSpacing.xl),
                      ),
                      child: Text(
                        'Daily Challenge Complete! 🎉',
                        style: theme.textTheme.titleSmall?.copyWith(color: AppColors.success),
                      ),
                    ),
                  ],
                  if (missedWordCount > 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      "Let's practice $missedWordCount missed word${missedWordCount == 1 ? '' : 's'}",
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const Spacer(),
                  if (session.failed) ...[
                    if (missedWordCount > 0) ...[
                      PrimaryButton(
                        label: 'Practice Mistakes',
                        onPressed: () => _practiceMistakes(session),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    SecondaryButton(label: 'Try Again', onPressed: () => _playAgain(session)),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextButton(label: 'Back to Fun Zone', onPressed: _done),
                  ] else ...[
                    PrimaryButton(
                      label: session.funLeveledUp ? 'Next Level' : 'Play Again',
                      onPressed: () => _playAgain(session),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SecondaryButton(label: 'Done', onPressed: _done),
                  ],
                ],
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 24,
            maxBlastForce: 18,
            minBlastForce: 6,
            gravity: 0.25,
            colors: const [
              AppColors.primary,
              AppColors.accent,
              AppColors.success,
              AppColors.gem,
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
