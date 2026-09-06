import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/lernova_parrot.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/last_activity.dart';
import '../../../data/models/vocab_preview_item.dart';
import '../../../data/models/vocab_preview_nav_args.dart';
import '../../../data/repositories/fun_content_providers.dart';
import '../../onboarding/application/user_controller.dart';
import '../../preview/application/vocab_preview_builder.dart';
import '../../progress/application/progress_controller.dart';
import '../application/falling_word_session_controller.dart';
import '../application/fun_game_nav_args.dart';
import '../application/fun_level_catalog.dart';
import '../application/fun_progress_controller.dart';
import '../application/fun_question_generator.dart';
import '../application/fun_conversation_session_controller.dart';
import '../application/fun_memory_match_session_controller.dart';
import '../application/fun_sentence_builder_session_controller.dart';
import '../application/fun_word_match_session_controller.dart';
import 'widgets/lives_indicator.dart';

class FunGameIntroScreen extends ConsumerWidget {
  final FunGameNavArgs args;
  const FunGameIntroScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = args.mode;
    final user = ref.watch(userProvider);
    final languageId = user.selectedLanguageId;
    final theme = Theme.of(context);

    if (languageId == null) {
      return const Scaffold(
        body: EmptyStateView(
          title: 'Pick a language first',
          message: 'Finish onboarding to unlock the Fun Zone.',
        ),
      );
    }

    final wordsAsync = ref.watch(funVocabWordsProvider(languageId));
    final phrasesAsync = ref.watch(funPhrasesProvider(languageId));
    final conversationsAsync = ref.watch(funConversationsProvider(languageId));
    final funProgress = ref.watch(funProgressProvider);
    final level = funProgress.levelFor(mode.name);
    final levelConfig = FunLevelCatalog.configFor(level, mode: mode);
    final startingLives = switch (mode) {
      FunGameMode.memoryMatch => 5,
      FunGameMode.wordRush => 3,
      _ => levelConfig.maxLives,
    };
    final hasLives = mode != FunGameMode.conversationChallenge;

    // Pushes the shared vocab-preview step (falling back to going
    // straight to gameplay when there's nothing meaningful to preview,
    // e.g. an id that couldn't be resolved into any real content).
    void goToPreview({
      required List<VocabPreviewItem> items,
      required String onStartRoute,
      Object? onStartExtra,
    }) {
      if (items.isEmpty) {
        context.push(onStartRoute, extra: onStartExtra);
        return;
      }
      context.push(
        AppRoutes.vocabPreview,
        extra: VocabPreviewNavArgs(
          items: items,
          levelLabel: 'Level $level',
          onStartRoute: onStartRoute,
          onStartExtra: onStartExtra,
          // Per mode *and* level: reaching a new level means new
          // vocabulary, which is worth one full pass before it can be
          // skipped.
          previewKey: 'fun:${mode.name}:$level',
        ),
      );
    }

    // Which content pool actually gates "can this mode even start" varies
    // per mode: Phrase Builder/Sentence Builder need phrases, Conversation
    // Challenge needs conversations, everything else needs the vocab pool.
    final contentReady = switch (mode) {
      FunGameMode.phraseBuilder || FunGameMode.sentenceBuilder => phrasesAsync,
      FunGameMode.conversationChallenge => conversationsAsync,
      _ => wordsAsync,
    };

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              LernovaParrot(size: 110, mood: LernovaParrotMood.happy),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '${mode.emoji}  ${mode.title}',
                style: theme.textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(mode.blurb, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  _InfoChip(icon: Icons.military_tech_rounded, label: 'Level $level'),
                  _InfoChip(
                    icon: Icons.checklist_rounded,
                    label: '${levelConfig.wordCount} words',
                  ),
                  if (hasLives)
                    _InfoChip(icon: Icons.favorite_rounded, label: '$startingLives lives')
                  else
                    const _InfoChip(
                      icon: Icons.emoji_emotions_outlined,
                      label: 'No lives — just practice',
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (hasLives) LivesIndicator(lives: startingLives, maxLives: startingLives),
              const Spacer(),
              contentReady.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, st) => ErrorStateView(
                  message: 'Could not load Fun content.',
                  onRetry: () => ref.invalidate(funVocabWordsProvider(languageId)),
                ),
                data: (content) {
                  if ((content as List).isEmpty) {
                    return const EmptyStateView(
                      title: 'Not available yet',
                      message: "This language doesn't have this mode's content yet.",
                    );
                  }
                  return PrimaryButton(
                    label: 'Start',
                    onPressed: () {
                      // One place for every Fun mode: whatever the player
                      // starts here is what Home offers to resume, so
                      // leaving a Fun round mid-way no longer sends them
                      // back to the Path.
                      ref.read(progressProvider.notifier).noteActivityStarted(
                            LastActivity.funGame(
                              at: DateTime.now(),
                              funModeName: mode.name,
                              funLevel: level,
                              title: mode.title,
                              subtitle: 'Level $level',
                            ),
                          );

                      if (mode == FunGameMode.wordMatch) {
                        final pairsPerRound = levelConfig.choiceCount;
                        final totalRounds =
                            (levelConfig.wordCount / pairsPerRound).ceil().clamp(1, 10);
                        ref.read(funWordMatchSessionProvider.notifier).start(
                              words: wordsAsync.value ?? const [],
                              vocabStrength: ref.read(progressProvider).vocabStrength,
                              totalRounds: totalRounds,
                              pairsPerRound: pairsPerRound,
                              random: Random(),
                            );
                        final roundWords =
                            ref.read(funWordMatchSessionProvider)!.currentRoundWords;
                        goToPreview(
                          items: VocabPreviewBuilder.fromVocabWords(roundWords, languageId: languageId),
                          onStartRoute: AppRoutes.funWordMatchPlay,
                        );
                        return;
                      }

                      if (mode == FunGameMode.sentenceBuilder) {
                        ref.read(funSentenceBuilderSessionProvider.notifier).start(
                              pool: phrasesAsync.value ?? const [],
                              totalRounds: levelConfig.wordCount.clamp(3, 8),
                              random: Random(),
                            );
                        final currentPhrase =
                            ref.read(funSentenceBuilderSessionProvider)!.currentPhrase;
                        goToPreview(
                          items: [VocabPreviewBuilder.fromPhrase(currentPhrase, languageId: languageId)],
                          onStartRoute: AppRoutes.funSentenceBuilderPlay,
                        );
                        return;
                      }

                      if (mode == FunGameMode.memoryMatch) {
                        ref.read(funMemoryMatchSessionProvider.notifier).start(
                              words: wordsAsync.value ?? const [],
                              vocabStrength: ref.read(progressProvider).vocabStrength,
                              pairCount: levelConfig.choiceCount,
                              random: Random(),
                            );
                        final sourceWords =
                            ref.read(funMemoryMatchSessionProvider)!.sourceWords;
                        goToPreview(
                          items: VocabPreviewBuilder.fromVocabWords(sourceWords, languageId: languageId),
                          onStartRoute: AppRoutes.funMemoryMatchPlay,
                        );
                        return;
                      }

                      if (mode == FunGameMode.conversationChallenge) {
                        ref.read(funConversationSessionProvider.notifier).start(
                              pool: conversationsAsync.value ?? const [],
                              totalConversations: 2,
                              random: Random(),
                            );
                        final currentConversation =
                            ref.read(funConversationSessionProvider)!.currentConversation;
                        goToPreview(
                          items: [VocabPreviewBuilder.fromConversation(currentConversation)],
                          onStartRoute: AppRoutes.funConversationPlay,
                        );
                        return;
                      }

                      final questions = FunQuestionGenerator.generateRound(
                        words: wordsAsync.value ?? const [],
                        phrases: phrasesAsync.value ?? const [],
                        level: levelConfig,
                        vocabStrength: ref.read(progressProvider).vocabStrength,
                        random: Random(),
                      );
                      ref.read(fallingWordSessionProvider.notifier).start(
                            mode: mode,
                            questions: questions,
                            levelConfig: levelConfig,
                          );
                      final items = VocabPreviewBuilder.fromFunQuestions(
                        questions,
                        wordPool: wordsAsync.value ?? const [],
                        phrasePool: phrasesAsync.value ?? const [],
                        languageId: languageId,
                      );
                      goToPreview(
                        items: items,
                        onStartRoute: AppRoutes.funGamePlay,
                        onStartExtra: args,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
