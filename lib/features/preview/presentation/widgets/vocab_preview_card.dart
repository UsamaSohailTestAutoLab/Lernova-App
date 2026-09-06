import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/service_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/vocab_preview_item.dart';

/// One page of the vocabulary preview: the target word/term, its
/// meaning underneath, and a brief pop-in animation each time it
/// becomes the active page.
class VocabPreviewCard extends ConsumerWidget {
  final VocabPreviewItem item;
  const VocabPreviewCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: TweenAnimationBuilder<double>(
          key: ValueKey(item.id),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          builder: (context, t, child) {
            return Opacity(
              opacity: t.clamp(0, 1),
              child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
            );
          },
          child: AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            // Scrolls rather than overflows: the card now carries a
            // Listen button as well as the word, its meaning and an
            // emoji, and a long word in a tall script can exceed a short
            // carousel page.
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.emoji != null) ...[
                    Text(item.emoji!, style: const TextStyle(fontSize: 56)),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text(
                    item.word,
                    style: theme.textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    item.meaning,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Every review card can be heard, not just the ones that
                  // happened to come from an audio question — a learner
                  // reviewing a word they got wrong needs the pronunciation
                  // more than anyone.
                  if (item.canSpeak) ...[
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.tonalIcon(
                      onPressed: () => ref
                          .read(ttsServiceProvider)
                          .speak(item.word, locale: item.ttsLocale),
                      icon: const Icon(Icons.volume_up_rounded),
                      label: const Text('Listen'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
