import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/service_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decor.dart';
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
    final languageName = _languageName(conversation.languageId);

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
                isEnglish
                    ? 'Step 1 of 3 · Read it in English'
                    : 'Step 2 of 3 · Now in $languageName',
                style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isEnglish
                    ? conversation.scenario
                    : 'The same exchange in $languageName, with the meaning under '
                        'each line. Tap 🔊 to hear how it sounds.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              // Step 1 doubles as this mode's "how it works" screen —
              // it replaced a Review Words step whose cards only
              // repeated this same scenario blurb.
              if (isEnglish) ...[
                const SizedBox(height: AppSpacing.md),
                _HowItWorks(languageName: languageName),
              ] else ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "Next: you'll pick the right reply at each turn.",
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
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
                  speaker: 'They say',
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
                  // Naming the sides is what makes this readable as a
                  // conversation rather than a list of sentences — and
                  // it flags which lines are the ones you'll be asked for.
                  speaker: 'You say',
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
              label: isEnglish ? 'Show it in $languageName' : 'Practice it',
              onPressed: onContinue,
            ),
          ),
        ),
      ],
    );
  }
}

/// The three beats of a Conversation Challenge, spelled out once on the
/// first screen.
///
/// This mode has no vocabulary list, so it used to open on a Review
/// Words step whose only card repeated the scenario blurb — a screen
/// that cost a tap and taught nothing. Saying plainly what the next
/// three screens will ask of you is what that step should have been.
class _HowItWorks extends StatelessWidget {
  final String languageName;
  const _HowItWorks({required this.languageName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = [
      ('1', 'Read the whole conversation in English, below.'),
      ('2', 'See the same lines in $languageName, and hear them.'),
      ('3', 'Take one side of it — pick the right reply each turn.'),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.decor.tint(AppColors.primary),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How this works',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final (number, text) in steps) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    number,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurface),
                  ),
                ),
              ],
            ),
            if (number != '3') const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

/// Which language this course teaches, for the step copy. Falls back to
/// a neutral phrase rather than guessing at an unknown code.
String _languageName(String languageId) => switch (languageId) {
      'es' => 'Spanish',
      'fr' => 'French',
      _ => 'your new language',
    };

class _Line extends StatelessWidget {
  final bool fromThem;

  /// "They say" / "You say" — see the call site.
  final String speaker;
  final String primary;
  final String? secondary;
  final VoidCallback? onListen;

  const _Line({
    required this.fromThem,
    required this.speaker,
    required this.primary,
    required this.secondary,
    required this.onListen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Your own replies used the raw primaryLight literal — a pale green
    // that the theme's near-white body text was invisible against in
    // dark mode, so half the conversation couldn't be read at all.
    // decor.tint() resolves to green900 there and green100 in light.
    final bg = fromThem
        ? theme.colorScheme.surfaceContainerHighest
        : context.decor.tint(AppColors.primary);

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
            Text(
              speaker,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
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
                  // onSurfaceVariant, not outline — outline is a border
                  // colour and is too faint to read a translation in.
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
