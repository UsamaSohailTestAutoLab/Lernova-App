import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../exercises/application/lesson_attempt.dart';
import '../../exercises/application/lesson_session_controller.dart';

class LessonReviewArgs {
  /// Opens straight into the missed-only view. The filter is still
  /// switchable — this only sets which tab you land on.
  final bool showMissedOnly;
  const LessonReviewArgs({this.showMissedOnly = true});
}

/// What actually happened, question by question: the prompt as it was
/// shown, the answer the learner gave, the answer that was right, and a
/// Listen button for the learning-language text.
///
/// Defaults to the missed questions — that's what a review is for — with
/// an "All" filter for anyone who wants the full transcript.
class LessonReviewScreen extends ConsumerStatefulWidget {
  final Object? extra;
  const LessonReviewScreen({super.key, this.extra});

  @override
  ConsumerState<LessonReviewScreen> createState() => _LessonReviewScreenState();
}

class _LessonReviewScreenState extends ConsumerState<LessonReviewScreen> {
  late bool _missedOnly =
      (widget.extra is LessonReviewArgs) ? (widget.extra! as LessonReviewArgs).showMissedOnly : true;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(lessonSessionProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: const EmptyStateView(
          title: 'Nothing to review',
          message: 'This session has already been cleared.',
        ),
      );
    }

    final all = session.firstAttempts;
    final missed = session.missedAttempts;
    final rows = _missedOnly ? missed : all;

    return Scaffold(
      appBar: AppBar(title: const Text('Review answers')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text('Missed (${missed.length})')),
                  ButtonSegment(value: false, label: Text('All (${all.length})')),
                ],
                selected: {_missedOnly},
                onSelectionChanged: (s) => setState(() => _missedOnly = s.first),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? EmptyStateView(
                      title: _missedOnly ? 'No mistakes' : 'Nothing answered',
                      message: _missedOnly
                          ? 'You answered everything correctly on the first try.'
                          : 'This attempt ended before any question was graded.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, i) => _ReviewRow(attempt: rows[i]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Done',
                  onPressed: () => context.pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends ConsumerWidget {
  final LessonAttempt attempt;
  const _ReviewRow({required this.attempt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ok = attempt.wasCorrect;
    final accent = ok ? AppColors.success : AppColors.error;
    final spoken = attempt.spokenText;

    return AppCard(
      variant: AppCardVariant.tinted,
      tint: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  attempt.promptLabel,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (spoken != null && spoken.isNotEmpty)
                IconButton.filledTonal(
                  onPressed: () => ref
                      .read(ttsServiceProvider)
                      .speak(spoken, locale: attempt.ttsLocale),
                  icon: const Icon(Icons.volume_up_rounded),
                  tooltip: 'Listen',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _AnswerLine(
            label: 'Your answer',
            value: attempt.userAnswerLabel,
            color: ok ? AppColors.success : AppColors.error,
          ),
          if (!ok) ...[
            const SizedBox(height: AppSpacing.xs),
            _AnswerLine(
              label: 'Correct answer',
              value: attempt.correctLabel,
              color: AppColors.success,
            ),
          ],
        ],
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnswerLine({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
