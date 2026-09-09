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
import '../../../data/models/exercise.dart';
import '../../../data/models/vocab_preview_item.dart';
import '../../../data/models/vocab_preview_nav_args.dart';
import '../../../data/repositories/fun_content_providers.dart';
import '../../exercises/application/lesson_session_controller.dart';
import '../../preview/application/vocab_preview_builder.dart';
import '../../progress/application/progress_controller.dart';
import '../../rewards/application/mistake_review_providers.dart';
import '../application/lesson_nav_args.dart';
import '../application/lesson_variant_generator.dart';

class LessonIntroScreen extends ConsumerWidget {
  final Object? extra;
  const LessonIntroScreen({super.key, this.extra});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (extra == 'review') {
      final reviewLesson = ref.watch(reviewLessonProvider);
      final reviewCourse = ref.watch(reviewCourseProvider);
      return reviewLesson.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, st) => Scaffold(
          body: ErrorStateView(
            message: 'Could not build a review session.',
            onRetry: () => ref.invalidate(reviewLessonProvider),
          ),
        ),
        data: (lesson) {
          if (lesson == null || reviewCourse.value == null) {
            return const Scaffold(
              body: EmptyStateView(
                title: 'Nothing to review',
                message: 'You have no outstanding mistakes right now.',
              ),
            );
          }
          return _LessonIntroBody(
            args: LessonNavArgs(
              course: reviewCourse.value!,
              unitIndex: -1,
              lessonIndex: -1,
              lesson: lesson,
              isReviewSession: true,
            ),
          );
        },
      );
    }

    final args = extra as LessonNavArgs;
    return _LessonIntroBody(args: args);
  }
}

class _LessonIntroBody extends ConsumerStatefulWidget {
  final LessonNavArgs args;
  const _LessonIntroBody({required this.args});

  @override
  ConsumerState<_LessonIntroBody> createState() => _LessonIntroBodyState();
}

class _LessonIntroBodyState extends ConsumerState<_LessonIntroBody> {
  bool _isBuildingPreview = false;

  LessonNavArgs get args => widget.args;

  Future<void> _startLesson() async {
    setState(() => _isBuildingPreview = true);
    final words = await ref.read(funVocabWordsProvider(args.course.languageId).future);
    final phrases = await ref.read(funPhrasesProvider(args.course.languageId).future);

    final languageId = args.course.languageId;

    // Collected across every exercise, then de-duplicated once by word.
    // A lesson reaches the same word through several exercise types (an
    // MCQ, a listening item, and again inside the word-matching set), and
    // each of those used to produce its own review card.
    final raw = <VocabPreviewItem>[];
    for (final exercise in args.lesson.exercises) {
      if (exercise.type == ExerciseType.wordMatching) {
        final payload = exercise.payload as WordMatchingPayload;
        raw.addAll(VocabPreviewBuilder.fromWordMatchingPairs(
          payload.pairs,
          languageId: languageId,
        ));
        continue;
      }
      raw.addAll(VocabPreviewBuilder.fromVocabIds(
        vocabIds: [exercise.vocabId],
        wordPool: words,
        phrasePool: phrases,
        languageId: languageId,
      ));
    }
    // The supporting words the lesson's sentences lean on. Without these
    // a question could be the learner's first sighting of a word — and
    // it would be a graded sighting.
    raw.addAll(VocabPreviewBuilder.fromVocabIds(
      vocabIds: args.lesson.reviewVocabIds,
      wordPool: words,
      phrasePool: phrases,
      languageId: languageId,
    ));
    final items = VocabPreviewBuilder.dedupe(raw);

    // A fresh arrangement every attempt: the order is reshuffled, some
    // words are asked through a different exercise type than last time,
    // and anything previously got wrong leads the round.
    final playable = LessonVariantGenerator.buildSession(
      lesson: args.lesson,
      words: words,
      languageId: languageId,
      random: Random(),
      prioritizeIds: ref.read(progressProvider).mistakeBank.keys.toSet(),
    );

    ref.read(lessonSessionProvider.notifier).start(
          course: args.course,
          unitIndex: args.unitIndex,
          lesson: playable,
          isReviewSession: args.isReviewSession,
        );

    if (!mounted) return;
    setState(() => _isBuildingPreview = false);

    if (items.isEmpty) {
      context.push(AppRoutes.lessonPlayer);
      return;
    }
    context.push(
      AppRoutes.vocabPreview,
      extra: VocabPreviewNavArgs(
        items: items,
        levelLabel: args.isReviewSession ? 'Review Mistakes' : args.lesson.title,
        onStartRoute: AppRoutes.lessonPlayer,
        // A mistake-review session is already the remedial path, so its
        // word list stays compulsory; ordinary lessons become skippable
        // once reviewed.
        previewKey: args.isReviewSession ? null : 'path:${args.lesson.id}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              LernovaParrot(size: 120, mood: LernovaParrotMood.happy),
              const SizedBox(height: AppSpacing.xl),
              Text(
                args.isReviewSession ? 'Review Mistakes' : args.lesson.title,
                style: theme.textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                args.lesson.subtitle,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist_rounded, size: 18, color: theme.colorScheme.outline),
                  const SizedBox(width: 6),
                  Text(
                    '${args.lesson.exercises.length} exercises',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const Spacer(),
              // Hearts refill when the lesson starts, so there is never a
              // locked-out state here to explain or sell a way out of.
              PrimaryButton(
                label: 'Start lesson',
                isLoading: _isBuildingPreview,
                onPressed: _startLesson,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
