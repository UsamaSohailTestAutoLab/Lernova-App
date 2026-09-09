import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../settings/application/settings_controller.dart';
import '../../languages/presentation/leave_session_sheet.dart';
import '../application/fun_word_match_session_controller.dart';
import 'widgets/combo_hud.dart';
import 'widgets/lives_indicator.dart';
import 'widgets/recall_interstitial.dart';

class FunWordMatchScreen extends ConsumerStatefulWidget {
  const FunWordMatchScreen({super.key});

  @override
  ConsumerState<FunWordMatchScreen> createState() => _FunWordMatchScreenState();
}

class _FunWordMatchScreenState extends ConsumerState<FunWordMatchScreen> {
  int? _selectedLeft;
  int? _wrongLeft;
  int? _wrongRight;
  bool _navigatedToResults = false;
  final _random = Random();

  void _feedback({required bool correct}) {
    final settings = ref.read(settingsProvider);
    if (settings.hapticsEnabled) {
      correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    }
    if (settings.soundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  void _tapLeft(int index, FunWordMatchState s) {
    if (s.matched.containsKey(index)) return;
    setState(() => _selectedLeft = index);
  }

  void _tapRight(int rightOriginalIndex, FunWordMatchState s) {
    if (s.matched.containsValue(rightOriginalIndex) || _selectedLeft == null) return;
    final leftIndex = _selectedLeft!;
    final correct = leftIndex == rightOriginalIndex;
    _feedback(correct: correct);
    ref.read(funWordMatchSessionProvider.notifier).attemptPair(leftIndex, rightOriginalIndex, _random);
    setState(() {
      _selectedLeft = null;
      _wrongLeft = correct ? null : leftIndex;
      _wrongRight = correct ? null : rightOriginalIndex;
    });
  }

  /// Leaving mid-round, either for good or to change language. The
  /// round is torn down first either way, so a Spanish round can never
  /// be left running against another language's vocabulary.
  Future<void> _confirmExit() async {
    final router = GoRouter.of(context);
    final choice = await showLeaveSessionSheet(
      context,
      title: 'Quit this round?',
      message: 'Your progress in this round will be lost.',
      exitLabel: 'Quit round',
    );
    if (choice == null || !mounted) return;

    ref.read(funWordMatchSessionProvider.notifier).reset();
    router.pop();
    if (choice == LeaveSessionChoice.switchLanguage) {
      router.push(AppRoutes.languages);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(funWordMatchSessionProvider);
    final theme = Theme.of(context);

    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    if (session.isComplete && !_navigatedToResults) {
      _navigatedToResults = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(funWordMatchSessionProvider.notifier).finishAndApply();
        if (mounted) context.pushReplacement(AppRoutes.funWordMatchResults);
      });
    }

    final words = session.currentRoundWords;

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
                Text('Match the pairs', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Round ${session.currentRoundIndex + 1} of ${session.totalRounds}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                Expanded(
                  child: session.pendingRecall != null
                      ? RecallInterstitial(
                          challenge: session.pendingRecall!,
                          attempts: session.recallAttempts,
                          onSubmit: (typed) => ref
                              .read(funWordMatchSessionProvider.notifier)
                              .submitRecallAnswer(typed),
                          onAcknowledge: () => ref
                              .read(funWordMatchSessionProvider.notifier)
                              .acknowledgeRecall(),
                        )
                      // One scroll view around BOTH columns — scrolling
                      // them independently would let the two sides drift
                      // out of alignment, which is the whole point of a
                      // matching grid. Without it, taller tiles (long
                      // German compounds, wrapped Arabic) overflow.
                      : SingleChildScrollView(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    for (var i = 0; i < words.length; i++)
                                      _MatchTile(
                                        label: words[i].word,
                                        selected: _selectedLeft == i,
                                        matched: session.matched.containsKey(i),
                                        wrong: _wrongLeft == i,
                                        onTap: () => _tapLeft(i, session),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: Column(
                                  children: [
                                    for (final rightIndex in session.rightOrder)
                                      _MatchTile(
                                        label: words[rightIndex].translation,
                                        selected: false,
                                        matched: session.matched.containsValue(rightIndex),
                                        wrong: _wrongRight == rightIndex,
                                        onTap: () => _tapRight(rightIndex, session),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

class _MatchTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool matched;
  final bool wrong;
  final VoidCallback onTap;

  const _MatchTile({
    required this.label,
    required this.selected,
    required this.matched,
    this.wrong = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = matched
        ? AppColors.success
        : wrong
            ? AppColors.error
            : selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: matched ? 0.5 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: matched ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: matched
                  ? AppColors.successLight
                  : wrong
                      ? AppColors.errorLight
                      : selected
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                          : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: selected || matched || wrong ? 2 : 1),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: matched
                    ? AppColors.success
                    : wrong
                        ? AppColors.error
                        : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
