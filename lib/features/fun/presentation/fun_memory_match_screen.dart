import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../settings/application/settings_controller.dart';
import '../application/fun_memory_match_session_controller.dart';
import 'widgets/combo_hud.dart';
import 'widgets/lives_indicator.dart';
import 'widgets/recall_interstitial.dart';

class FunMemoryMatchScreen extends ConsumerStatefulWidget {
  const FunMemoryMatchScreen({super.key});

  @override
  ConsumerState<FunMemoryMatchScreen> createState() => _FunMemoryMatchScreenState();
}

class _FunMemoryMatchScreenState extends ConsumerState<FunMemoryMatchScreen> {
  bool _navigatedToResults = false;
  bool _resolvingMismatch = false;

  void _tapCard(int index, FunMemoryMatchState s) {
    if (_resolvingMismatch) return;
    if (s.flippedIndices.contains(index) || s.matchedIndices.contains(index)) return;

    final aboutToResolve = s.flippedIndices.length == 1;
    ref.read(funMemoryMatchSessionProvider.notifier).flipCard(index);

    if (aboutToResolve) {
      final settings = ref.read(settingsProvider);
      final after = ref.read(funMemoryMatchSessionProvider)!;
      final matched = after.matchedIndices.length > s.matchedIndices.length;
      if (settings.hapticsEnabled) {
        matched ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
      }
      if (settings.soundEnabled) SystemSound.play(SystemSoundType.click);

      if (!matched) {
        _resolvingMismatch = true;
        Future.delayed(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          ref.read(funMemoryMatchSessionProvider.notifier).resolveMismatch();
          _resolvingMismatch = false;
        });
      }
    }
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
      ref.read(funMemoryMatchSessionProvider.notifier).reset();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(funMemoryMatchSessionProvider);
    final theme = Theme.of(context);

    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    if (session.isComplete && !_navigatedToResults) {
      _navigatedToResults = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(funMemoryMatchSessionProvider.notifier).finishAndApply();
        if (mounted) context.pushReplacement(AppRoutes.funMemoryMatchResults);
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
          title: LivesIndicator(lives: session.lives, maxLives: 5),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Center(child: ComboHud(combo: session.combo, enabled: true)),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Find the matching pairs', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: session.pendingRecall != null
                      ? RecallInterstitial(
                          challenge: session.pendingRecall!,
                          attempts: session.recallAttempts,
                          onSubmit: (typed) => ref
                              .read(funMemoryMatchSessionProvider.notifier)
                              .submitRecallAnswer(typed),
                          onAcknowledge: () => ref
                              .read(funMemoryMatchSessionProvider.notifier)
                              .acknowledgeRecall(),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: session.cards.length,
                          itemBuilder: (context, i) {
                            final faceUp = session.flippedIndices.contains(i) ||
                                session.matchedIndices.contains(i);
                            return _FlipCard(
                              faceUp: faceUp,
                              matched: session.matchedIndices.contains(i),
                              label: session.cards[i].label,
                              onTap: () => _tapCard(i, session),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlipCard extends StatelessWidget {
  final bool faceUp;
  final bool matched;
  final String label;
  final VoidCallback onTap;

  const _FlipCard({
    required this.faceUp,
    required this.matched,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: faceUp ? null : onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: faceUp
            ? Container(
                key: const ValueKey('front'),
                decoration: BoxDecoration(
                  color: matched ? AppColors.successLight : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: matched ? AppColors.success : AppColors.primary),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: matched ? AppColors.success : AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : Container(
                key: const ValueKey('back'),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
              ),
      ),
    );
  }
}
