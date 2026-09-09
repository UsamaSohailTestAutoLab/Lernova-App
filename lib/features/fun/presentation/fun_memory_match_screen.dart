import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decor.dart';
import '../../../core/theme/app_spacing.dart';
import '../../settings/application/settings_controller.dart';
import '../../languages/presentation/leave_session_sheet.dart';
import '../application/fun_memory_match_session_controller.dart';
import 'widgets/combo_hud.dart';
import 'widgets/lives_indicator.dart';

class FunMemoryMatchScreen extends ConsumerStatefulWidget {
  const FunMemoryMatchScreen({super.key});

  @override
  ConsumerState<FunMemoryMatchScreen> createState() => _FunMemoryMatchScreenState();
}

class _FunMemoryMatchScreenState extends ConsumerState<FunMemoryMatchScreen> {
  bool _navigatedToResults = false;
  bool _resolvingMismatch = false;

  /// Ticks down the memorise phase so the player can see how long they
  /// have left to place the board, rather than having it vanish on them.
  Timer? _memoriseTimer;
  int _secondsLeft = 0;
  int _memoriseSeconds = 0;

  /// True while a wrong pair is still showing, before it turns back over.
  bool _showingWrongPair = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMemorisePhase());
  }

  @override
  void dispose() {
    _memoriseTimer?.cancel();
    super.dispose();
  }

  void _startMemorisePhase() {
    final session = ref.read(funMemoryMatchSessionProvider);
    if (!mounted || session == null) return;
    if (session.phase != MemoryMatchPhase.memorising) return;

    final total = FunMemoryMatchSessionController.memoriseDuration(session.pairCount);
    setState(() {
      _memoriseSeconds = total.inSeconds;
      _secondsLeft = total.inSeconds;
    });
    _memoriseTimer?.cancel();
    _memoriseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _secondsLeft - 1;
      if (remaining <= 0) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        ref.read(funMemoryMatchSessionProvider.notifier).beginPlay();
        return;
      }
      setState(() => _secondsLeft = remaining);
    });
  }

  /// Lets an impatient player skip the countdown rather than sitting
  /// through it once they've already placed the board.
  void _startNow() {
    _memoriseTimer?.cancel();
    setState(() => _secondsLeft = 0);
    ref.read(funMemoryMatchSessionProvider.notifier).beginPlay();
  }

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
        setState(() => _showingWrongPair = true);
        // Long enough to register as "those two, wrong", short enough
        // that it doesn't interrupt the board you are holding in mind.
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          ref.read(funMemoryMatchSessionProvider.notifier).resolveMismatch();
          setState(() => _showingWrongPair = false);
          _resolvingMismatch = false;
        });
      }
    }
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

    ref.read(funMemoryMatchSessionProvider.notifier).reset();
    router.pop();
    if (choice == LeaveSessionChoice.switchLanguage) {
      router.push(AppRoutes.languages);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(funMemoryMatchSessionProvider);

    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final memorising = session.phase == MemoryMatchPhase.memorising;
    final showingWrongPair = _showingWrongPair && session.flippedIndices.length == 2;

    final pairColors = memoryPairColors(session.cards);

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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PhaseBanner(
                  memorising: memorising,
                  secondsLeft: _secondsLeft,
                  totalSeconds: _memoriseSeconds,
                  pairsLeft: session.pairCount - session.matchesFound,
                  onStartNow: _startNow,
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: GridView.builder(
                    physics: memorising
                        ? const NeverScrollableScrollPhysics()
                        : const AlwaysScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: session.cards.length,
                    itemBuilder: (context, i) {
                      // Everything is face up while memorising — that
                      // is the whole point of the phase.
                      final faceUp = memorising ||
                          session.flippedIndices.contains(i) ||
                          session.matchedIndices.contains(i);
                      return _FlipCard(
                        faceUp: faceUp,
                        matched: session.matchedIndices.contains(i),
                        // A wrong pair is left flipped for a beat
                        // before it turns back — both cards go red so
                        // the miss reads instantly, with no dialog to
                        // dismiss and no board hidden behind it.
                        wrong: showingWrongPair && session.flippedIndices.contains(i),
                        // While memorising, the two halves of a pair
                        // share a colour. Drawing lines between them
                        // instead meant the links crossed the very words
                        // they were pointing at.
                        pairColor: memorising ? pairColors[i] : null,
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

/// Tells the player which half of the round they are in and what to do
/// in it — the memorise phase is meaningless without the instruction,
/// and the play phase used to open with no guidance at all.
class _PhaseBanner extends StatelessWidget {
  final bool memorising;
  final int secondsLeft;
  final int totalSeconds;
  final int pairsLeft;
  final VoidCallback onStartNow;

  const _PhaseBanner({
    required this.memorising,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.pairsLeft,
    required this.onStartNow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!memorising) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Find the matching pairs', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Tap two cards to pair a word with its meaning · $pairsLeft to go',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    // Text colour is pinned to the surface ink rather than left to the
    // theme's default: the banner keeps a warm tint in both themes, and
    // the inherited body colour vanished into it in dark mode.
    final onBanner = theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        // decor.tint() rather than the raw accentLight literal, which is
        // a pale cream that light text disappears into in dark mode.
        color: context.decor.tint(AppColors.accent),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_rounded, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Memorise the pairs',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: onBanner,
                      ),
                    ),
                    Text(
                      'Cards in the same colour go together. Remember where they are.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: onBanner.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // A countdown you can watch, not just a number that jumps:
              // the ring drains while the seconds tick.
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      key: ValueKey(secondsLeft),
                      tween: Tween(
                        begin: totalSeconds == 0 ? 0 : secondsLeft / totalSeconds,
                        end: totalSeconds == 0
                            ? 0
                            : (secondsLeft - 1).clamp(0, totalSeconds) / totalSeconds,
                      ),
                      duration: const Duration(seconds: 1),
                      builder: (context, value, _) => SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 4,
                          backgroundColor: AppColors.accent.withValues(alpha: 0.25),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(AppColors.accent),
                        ),
                      ),
                    ),
                    Text(
                      '$secondsLeft',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onStartNow, child: const Text("I'm ready")),
          ),
        ],
      ),
    );
  }
}


/// One colour per pair, indexed by card position, for the memorise
/// phase.
///
/// This replaced connector lines drawn between matching cards: the lines
/// had to cross the board to reach their partner, which meant they ran
/// straight through the words they were pointing at. Two cards in the
/// same colour say the same thing without covering anything.
List<Color> memoryPairColors(List<MemoryCard> cards) {
  const palette = [
    Color(0xFF2E90FA), // blue
    Color(0xFF7C5CFF), // violet
    Color(0xFFE8811B), // amber
    Color(0xFF12B76A), // green
    Color(0xFFD6336C), // pink
    Color(0xFF0EA5A5), // teal
  ];

  final colorByPair = <String, Color>{};
  return [
    for (final card in cards)
      colorByPair.putIfAbsent(
        card.pairId,
        () => palette[colorByPair.length % palette.length],
      ),
  ];
}

class _FlipCard extends StatelessWidget {
  final bool faceUp;
  final bool matched;

  /// Part of a pair that was just picked wrong — the whole of the "you
  /// missed" feedback in this mode.
  final bool wrong;

  /// Set only during the memorise phase: the shared colour that marks
  /// this card and its partner as a pair. Null the rest of the round.
  final Color? pairColor;

  final String label;
  final VoidCallback onTap;

  const _FlipCard({
    required this.faceUp,
    required this.matched,
    this.wrong = false,
    this.pairColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = context.decor;
    // Tinted through the theme so the face reads correctly in dark mode;
    // the ink is the brand colour itself, which stays legible on both.
    final (face, ink) = switch ((wrong, matched, pairColor)) {
      (true, _, _) => (decor.tint(AppColors.error), AppColors.error),
      (_, true, _) => (decor.tint(AppColors.success), AppColors.success),
      // A pair colour is a one-off hue with no curated dark-mode tint,
      // so the face is a low-alpha wash of it — which reads on either
      // ground — rather than a fixed pale literal.
      (_, _, final Color pair) => (pair.withValues(alpha: 0.18), pair),
      _ => (decor.tint(AppColors.primary), AppColors.primary),
    };

    return GestureDetector(
      onTap: faceUp ? null : onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: faceUp
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                key: const ValueKey('front'),
                decoration: BoxDecoration(
                  color: face,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ink, width: wrong ? 2.5 : 1),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: ink,
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
