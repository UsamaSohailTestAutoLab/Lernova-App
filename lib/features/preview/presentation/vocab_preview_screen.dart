import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/lingoquest_parrot.dart';
import '../../../core/widgets/swipe_carousel.dart';
import '../../../data/models/vocab_preview_nav_args.dart';
import '../../progress/application/progress_controller.dart';
import 'widgets/vocab_preview_card.dart';

/// Shared "see the words before you're tested on them" step, inserted
/// between any level's intro screen and its actual gameplay/lesson
/// screen. Mode-agnostic by design — it only knows [VocabPreviewNavArgs],
/// so any future level type gets this step automatically just by
/// producing a `List<VocabPreviewItem>` and a route to continue to.
///
/// The first time through a level the review is compulsory: a beginner
/// meeting this vocabulary for the first time should see all of it.
/// Once a level has been reviewed end to end, every later attempt offers
/// **Skip** — by then the words are familiar and re-reading them is
/// friction rather than teaching.
class VocabPreviewScreen extends ConsumerStatefulWidget {
  final VocabPreviewNavArgs args;
  const VocabPreviewScreen({super.key, required this.args});

  @override
  ConsumerState<VocabPreviewScreen> createState() => _VocabPreviewScreenState();
}

class _VocabPreviewScreenState extends ConsumerState<VocabPreviewScreen> {
  /// Read once, before this visit can mark the level as reviewed —
  /// otherwise finishing the very first review would make Skip appear
  /// retroactively on that same screen.
  late final bool _canSkip = _resolveCanSkip();

  bool _resolveCanSkip() {
    final key = widget.args.previewKey;
    if (key == null) return false;
    return ref.read(progressProvider).previewedLevelIds.contains(key);
  }

  void _start() {
    final key = widget.args.previewKey;
    if (key != null) {
      ref.read(progressProvider.notifier).markLevelPreviewed(key);
    }
    context.pushReplacement(
      widget.args.onStartRoute,
      extra: widget.args.onStartExtra,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.args.items;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.levelLabel),
        actions: [
          if (_canSkip)
            TextButton(
              onPressed: _start,
              child: const Text('Skip'),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            children: [
              LingoQuestParrot(size: 76, mood: LingoQuestParrotMood.teaching),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Review Words',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: SwipeCarouselScaffold(
                  itemCount: items.length,
                  itemBuilder: (context, index) => VocabPreviewCard(item: items[index]),
                  bottomBuilder: (context, index, goNext) {
                    final isLast = index >= items.length - 1;
                    if (!isLast) {
                      return IconButton.filled(
                        onPressed: goNext,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Ready?', style: theme.textTheme.headlineSmall),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            label: 'Start Level',
                            onPressed: _start,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
