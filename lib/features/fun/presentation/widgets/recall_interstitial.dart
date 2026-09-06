import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/service_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/type_answer_field.dart';
import '../../domain/recall_challenge.dart';

/// The feedback card shown after a wrong answer in any Fun mode.
///
/// It leads with what actually happened — your answer against the right
/// one — because that comparison is the whole lesson of a mistake. Then
/// it offers the pronunciation, then an optional active-recall step
/// (type the meaning), and finally Continue.
///
/// Contrast is deliberate: white card, a solid red header band, and body
/// text in the theme's normal on-surface ink. The previous version put
/// pale text on a pale red wash, which was close to unreadable and read
/// as a scolding rather than as teaching. Continue is *always* available
/// — the typed step is practice offered, never a gate.
class RecallInterstitial extends ConsumerStatefulWidget {
  final RecallChallenge challenge;

  /// How many wrong recall attempts have been made so far for this
  /// challenge (0 = first time shown). At 2, the typed step gives way to
  /// the revealed answer.
  final int attempts;
  final ValueChanged<String> onSubmit;
  final VoidCallback onAcknowledge;

  const RecallInterstitial({
    super.key,
    required this.challenge,
    required this.attempts,
    required this.onSubmit,
    required this.onAcknowledge,
  });

  @override
  ConsumerState<RecallInterstitial> createState() => _RecallInterstitialState();
}

class _RecallInterstitialState extends ConsumerState<RecallInterstitial> {
  TypeAnswerFeedback _fieldFeedback = TypeAnswerFeedback.none;

  @override
  void didUpdateWidget(covariant RecallInterstitial oldWidget) {
    super.didUpdateWidget(oldWidget);
    final revealMode = widget.attempts >= 2;
    if (widget.attempts != oldWidget.attempts && !revealMode) {
      // A wrong recall guess just landed — flash the field red briefly,
      // then clear it so the player can try again.
      setState(() => _fieldFeedback = TypeAnswerFeedback.incorrect);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _fieldFeedback = TypeAnswerFeedback.none);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Some hosts give this a bounded slot (an Expanded in Word Match and
    // Memory Match), others drop it into a plain Column (Sentence
    // Builder). Scroll only where there is a height to scroll within —
    // a SingleChildScrollView under unbounded constraints throws.
    return LayoutBuilder(
      builder: (context, constraints) {
        final card = _card(context, ref);
        return constraints.hasBoundedHeight
            ? SingleChildScrollView(child: card)
            : card;
      },
    );
  }

  Widget _card(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final challenge = widget.challenge;
    final revealMode = widget.attempts >= 2;
    final listenText = challenge.listenText;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.45),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solid header band: white on red is unambiguous, and it
          // keeps the body of the card on a plain readable surface.
          Container(
            width: double.infinity,
            color: AppColors.error,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.highlight_off_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Not quite!',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (challenge.userAnswer != null) ...[
                  _AnswerRow(
                    label: 'You selected',
                    value: challenge.userAnswer!,
                    color: AppColors.error,
                    icon: Icons.close_rounded,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                _AnswerRow(
                  label: 'Correct answer',
                  value: challenge.correctMeaning,
                  color: AppColors.success,
                  icon: Icons.check_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    if (challenge.emoji != null) ...[
                      Text(
                        challenge.emoji!,
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Text(
                        '${challenge.promptWord} = ${challenge.correctMeaning}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (listenText != null && listenText.isNotEmpty)
                      FilledButton.tonalIcon(
                        onPressed: () => ref
                            .read(ttsServiceProvider)
                            .speak(listenText, locale: challenge.ttsLocale),
                        icon: const Icon(Icons.volume_up_rounded, size: 20),
                        label: const Text('Listen'),
                      ),
                  ],
                ),
                if (!revealMode) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Write the meaning of “${challenge.promptWord}” to lock it in:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TypeAnswerField(
                    hintText: 'Type the meaning',
                    feedback: _fieldFeedback,
                    onSubmit: widget.onSubmit,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: 'Continue',
                    onPressed: widget.onAcknowledge,
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

class _AnswerRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _AnswerRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
