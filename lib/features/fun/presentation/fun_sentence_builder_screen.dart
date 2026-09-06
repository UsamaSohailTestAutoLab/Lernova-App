import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../settings/application/settings_controller.dart';
import '../application/fun_sentence_builder_session_controller.dart';
import 'widgets/combo_hud.dart';
import 'widgets/lives_indicator.dart';
import 'widgets/recall_interstitial.dart';

class FunSentenceBuilderScreen extends ConsumerStatefulWidget {
  const FunSentenceBuilderScreen({super.key});

  @override
  ConsumerState<FunSentenceBuilderScreen> createState() => _FunSentenceBuilderScreenState();
}

class _FunSentenceBuilderScreenState extends ConsumerState<FunSentenceBuilderScreen> {
  bool _navigatedToResults = false;
  final _random = Random();

  void _submit() {
    final settings = ref.read(settingsProvider);
    final s = ref.read(funSentenceBuilderSessionProvider)!;
    final built = s.chosenIndices.map((i) => s.shuffledTokens[i]).join(' ');
    final correct = built == s.currentPhrase.phrase;

    if (settings.hapticsEnabled) {
      correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    }
    if (settings.soundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
    ref.read(funSentenceBuilderSessionProvider.notifier).submitSentence(_random);
  }

  Future<void> _confirmExit() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Quit this round?',
      message: 'Your progress in this round will be lost.',
      confirmLabel: 'Quit',
      isDestructive: true,
    );
    if (confirmed && mounted) {
      ref.read(funSentenceBuilderSessionProvider.notifier).reset();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(funSentenceBuilderSessionProvider);
    final theme = Theme.of(context);

    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    if (session.isComplete && !_navigatedToResults) {
      _navigatedToResults = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(funSentenceBuilderSessionProvider.notifier).finishAndApply();
        if (mounted) context.pushReplacement(AppRoutes.funSentenceBuilderResults);
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _confirmExit),
          title: LivesIndicator(lives: session.lives, maxLives: 3),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Center(child: ComboHud(combo: session.combo, enabled: true)),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Build the sentence', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Round ${session.currentRoundIndex + 1} of ${session.totalRounds} · "${session.currentPhrase.meaning}"',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                if (session.pendingRecall != null)
                  RecallInterstitial(
                    challenge: session.pendingRecall!,
                    attempts: session.recallAttempts,
                    onSubmit: (typed) => ref
                        .read(funSentenceBuilderSessionProvider.notifier)
                        .submitRecallAnswer(typed, _random),
                    onAcknowledge: () => ref
                        .read(funSentenceBuilderSessionProvider.notifier)
                        .acknowledgeRecall(_random),
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (var i = 0; i < session.chosenIndices.length; i++)
                          _WordChip(
                            label: session.shuffledTokens[session.chosenIndices[i]],
                            filled: true,
                            onTap: () => ref
                                .read(funSentenceBuilderSessionProvider.notifier)
                                .removeToken(i),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final i in session.availableIndices)
                        _WordChip(
                          label: session.shuffledTokens[i],
                          filled: false,
                          onTap: () => ref
                              .read(funSentenceBuilderSessionProvider.notifier)
                              .chooseToken(i),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Check',
                    onPressed: session.sentenceReady ? _submit : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _WordChip({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary.withValues(alpha: 0.12) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? AppColors.primary : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(label, style: theme.textTheme.titleSmall),
      ),
    );
  }
}
