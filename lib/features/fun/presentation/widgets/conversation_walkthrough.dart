import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/service_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/tts_locales.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../data/models/fun/conversation.dart';

/// The two teaching steps that now open Conversation Challenge.
///
/// Step 1 shows the whole exchange in **English**, so the learner knows
/// what is being said before anything is asked of them. Step 2 shows the
/// same exchange in the language being learned, each line paired with its
/// English meaning and a Listen button.
///
/// Practising a dialogue you don't understand isn't conversation
/// practice — it's guessing which Spanish string the app wants.
enum ConversationStage { english, target }

class ConversationWalkthrough extends ConsumerWidget {
  final Conversation conversation;
  final ConversationStage stage;
  final VoidCallback onContinue;

  const ConversationWalkthrough({
    super.key,
    required this.conversation,
    required this.stage,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isEnglish = stage == ConversationStage.english;
    final ttsLocale = TtsLocales.forLanguageId(conversation.languageId);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            children: [
              Text(
                isEnglish ? 'Step 1 · Learn the conversation' : 'Step 2 · Now in Spanish',
                style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isEnglish
                    ? "Here's what this exchange means."
                    : 'The same exchange, in the language you\'re learning. Tap 🔊 to hear it.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final turn in conversation.turns) ...[
                _Line(
                  fromThem: true,
                  primary: isEnglish ? (turn.lineEnglish ?? turn.line) : turn.line,
                  secondary: isEnglish ? null : turn.lineEnglish,
                  onListen: isEnglish
                      ? null
                      : () => ref
                          .read(ttsServiceProvider)
                          .speak(turn.line, locale: ttsLocale),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Line(
                  fromThem: false,
                  primary: isEnglish
                      ? (turn.correctResponseEnglish ?? turn.correctResponse)
                      : turn.correctResponse,
                  secondary: isEnglish ? null : turn.correctResponseEnglish,
                  onListen: isEnglish
                      ? null
                      : () => ref
                          .read(ttsServiceProvider)
                          .speak(turn.correctResponse, locale: ttsLocale),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: isEnglish ? 'Show it in Spanish' : "Practice it",
              onPressed: onContinue,
            ),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  final bool fromThem;
  final String primary;
  final String? secondary;
  final VoidCallback? onListen;

  const _Line({
    required this.fromThem,
    required this.primary,
    required this.secondary,
    required this.onListen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = fromThem ? theme.colorScheme.surfaceContainerHighest : AppColors.primaryLight;

    return Align(
      alignment: fromThem ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(fromThem ? 4 : 18),
            topRight: Radius.circular(fromThem ? 18 : 4),
            bottomLeft: const Radius.circular(18),
            bottomRight: const Radius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              fromThem ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    primary,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (onListen != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    onPressed: onListen,
                    icon: const Icon(Icons.volume_up_rounded, size: 18),
                    tooltip: 'Listen',
                  ),
                ],
              ],
            ),
            if (secondary != null) ...[
              const SizedBox(height: 2),
              Text(
                secondary!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
