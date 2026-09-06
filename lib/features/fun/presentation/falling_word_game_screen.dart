import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../data/models/fun/fun_question.dart';
import '../../settings/application/settings_controller.dart';
import '../application/falling_word_session_controller.dart';
import 'widgets/bubble_field.dart';
import '../../../core/widgets/cartoon_character.dart';
import 'widgets/combo_hud.dart';
import 'widgets/lives_indicator.dart';
import 'widgets/miss_banner.dart';
import 'widgets/pause_overlay.dart';
import 'widgets/water_bubble.dart';
import 'widgets/water_survival_arena.dart';

class FallingWordGameScreen extends ConsumerStatefulWidget {
  const FallingWordGameScreen({super.key});

  @override
  ConsumerState<FallingWordGameScreen> createState() => _FallingWordGameScreenState();
}

class _FallingWordGameScreenState extends ConsumerState<FallingWordGameScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fallController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..addStatusListener(_onFallStatus);
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 500));

  String? _lastQuestionId;
  int? _tappedIndex;
  BubbleVisualState _tappedState = BubbleVisualState.idle;
  bool _answeredThisQuestion = false;
  bool _navigatedToResults = false;
  CartoonCharacterMood _mascotMood = CartoonCharacterMood.happy;

  /// Round clock stopped by the player. Blocks answering as well as the
  /// timer, so a paused board can't be played.
  bool _paused = false;

  /// Auto-dismiss for the miss banner, so a wrong answer doesn't require
  /// a tap to get back into the game.
  Timer? _missTimer;

  /// Settles the character back to its resting mood after a reaction.
  Timer? _moodTimer;

  /// Long enough to read the answer, short enough not to feel like a
  /// stoppage.
  static const _missBannerDuration = Duration(milliseconds: 2600);

  void _onFallStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_answeredThisQuestion) {
      _answeredThisQuestion = true;
      _fallController.stop();
      _feedback(correct: false);
      setState(() => _tappedState = BubbleVisualState.incorrect);
      _flashMood(CartoonCharacterMood.worried);
      ref.read(fallingWordSessionProvider.notifier).questionTimedOut();
      _armMissDismiss();
    }
  }

  /// Starts (or restarts) the countdown that clears the miss banner.
  void _armMissDismiss() {
    _missTimer?.cancel();
    if (_paused) return; // re-armed on resume instead
    _missTimer = Timer(_missBannerDuration, _dismissMiss);
  }

  void _dismissMiss() {
    _missTimer?.cancel();
    _missTimer = null;
    if (!mounted) return;
    if (ref.read(fallingWordSessionProvider)?.pendingRecall == null) return;
    ref.read(fallingWordSessionProvider.notifier).acknowledgeRecall();
  }

  void _togglePause() {
    final pausing = !_paused;
    setState(() => _paused = pausing);

    if (pausing) {
      _fallController.stop();
      _missTimer?.cancel();
      return;
    }

    // Resuming picks up exactly where the clock stopped, rather than
    // restarting the question and handing back time already spent.
    if (ref.read(fallingWordSessionProvider)?.pendingRecall != null) {
      _armMissDismiss();
    } else if (!_answeredThisQuestion) {
      _fallController.forward();
    }
  }

  /// The character's resting mood reflects how many hearts remain — dry
  /// and happy at full health, visibly worried on the last heart,
  /// "drowning" once the round has failed.
  CartoonCharacterMood _baseMoodForLives(int lives) {
    if (lives <= 0) return CartoonCharacterMood.drowning;
    if (lives == 1) return CartoonCharacterMood.worried;
    return CartoonCharacterMood.happy;
  }

  /// Briefly reacts the water-survival character to an answer, then
  /// settles back to whatever its current-hearts mood should be.
  /// Harmless no-op visually for every other level/mode, which don't
  /// render the character at all.
  ///
  /// Held as a cancellable [Timer] rather than a bare `Future.delayed`
  /// so leaving the round tears it down instead of leaving a callback
  /// pending against a disposed screen.
  void _flashMood(CartoonCharacterMood mood) {
    setState(() => _mascotMood = mood);
    _moodTimer?.cancel();
    _moodTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      final lives = ref.read(fallingWordSessionProvider)?.lives ?? 3;
      setState(() => _mascotMood = _baseMoodForLives(lives));
    });
  }

  void _feedback({required bool correct}) {
    final settings = ref.read(settingsProvider);
    if (settings.hapticsEnabled) {
      correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    }
    if (settings.soundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  void _onBubbleTapped(int index, bool correct) {
    if (_answeredThisQuestion || _paused) return;
    _answeredThisQuestion = true;
    _fallController.stop();
    _feedback(correct: correct);
    if (correct) _confetti.play();
    setState(() {
      _tappedIndex = index;
      _tappedState = correct ? BubbleVisualState.correct : BubbleVisualState.incorrect;
    });
    _flashMood(correct ? CartoonCharacterMood.celebrate : CartoonCharacterMood.worried);
    ref.read(fallingWordSessionProvider.notifier).submitAnswer(index);
    if (!correct) _armMissDismiss();
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
      ref.read(fallingWordSessionProvider.notifier).reset();
      context.pop();
    }
  }

  @override
  void dispose() {
    _missTimer?.cancel();
    _moodTimer?.cancel();
    _fallController.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(fallingWordSessionProvider);

    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    if (session.isComplete && !_navigatedToResults) {
      _navigatedToResults = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(fallingWordSessionProvider.notifier).finishAndApply();
        if (mounted) context.pushReplacement(AppRoutes.funRoundResults);
      });
    }

    final question = session.currentQuestion;
    if (question == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_lastQuestionId != question.id) {
      _lastQuestionId = question.id;
      _answeredThisQuestion = false;
      _tappedIndex = null;
      _tappedState = BubbleVisualState.idle;
      _mascotMood = _baseMoodForLives(session.lives);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fallController.duration = session.levelConfig.fallDuration;
        // A question that arrives while paused waits at zero; resuming
        // starts its clock.
        if (_paused) {
          _fallController.value = 0;
        } else {
          _fallController.forward(from: 0);
        }
        if (question.promptIsAudio && !_paused) {
          ref.read(ttsServiceProvider).speak(question.promptText, locale: question.ttsLocale);
        }
      });
    }

    // Every question type now answers with words, never bare emoji —
    // the emoji rides along with the prompt instead.
    // Level 1 of Falling Words gets the themed "rising water" survival
    // presentation; every other level/mode keeps the original falling
    // bubbles untouched.
    final isWaterSurvivalLevel =
        session.mode == FunGameMode.fallingWords && session.levelConfig.level == 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _confirmExit),
          title: LivesIndicator(lives: session.lives, maxLives: session.levelConfig.maxLives),
          actions: [
            Center(
              child: ComboHud(combo: session.combo, enabled: session.levelConfig.comboEnabled),
            ),
            IconButton(
              onPressed: _togglePause,
              icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
              tooltip: _paused ? 'Resume' : 'Pause',
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
        body: Stack(
          alignment: Alignment.topCenter,
          children: [
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.md,
                    ),
                    child: _PromptHeader(question: question),
                  ),
                  // The board stays on screen through a miss — the
                  // feedback appears beneath it rather than replacing it.
                  Expanded(
                    child: isWaterSurvivalLevel
                        ? AnimatedBuilder(
                            animation: _fallController,
                            builder: (context, _) {
                              return WaterSurvivalArena(
                                question: question,
                                lives: session.lives,
                                maxLives: session.levelConfig.maxLives,

                                tappedIndex: _tappedIndex,
                                tappedState: _tappedState,
                                mascotMood: _mascotMood,
                                countdownFraction: 1 - _fallController.value,
                                onSelect: (i) =>
                                    _onBubbleTapped(i, i == question.correctIndex),
                              );
                            },
                          )
                        : AnimatedBuilder(
                            animation: _fallController,
                            builder: (context, _) {
                              return BubbleField(
                                question: question,
                                progress: _fallController.value,
                                tappedIndex: _tappedIndex,
                                tappedState: _tappedState,
                                onSelect: (i) =>
                                    _onBubbleTapped(i, i == question.correctIndex),
                              );
                            },
                          ),
                  ),
                  if (session.pendingRecall != null)
                    MissBanner(
                      challenge: session.pendingRecall!,
                      onNext: _dismissMiss,
                    ),
                ],
              ),
            ),
            ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 16,
              maxBlastForce: 12,
              minBlastForce: 4,
              gravity: 0.3,
              colors: const [AppColors.primary, AppColors.accent, AppColors.success],
            ),
            if (_paused)
              PauseOverlay(
                onResume: _togglePause,
                // Stays paused behind the confirm dialog, so backing out
                // of quitting doesn't silently restart the clock.
                onQuit: _confirmExit,
              ),
          ],
        ),
      ),
    );
  }
}

class _PromptHeader extends ConsumerWidget {
  final FunQuestion question;
  const _PromptHeader({required this.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // The emoji supports the prompt, it never replaces it. This used to
    // return the emoji alone whenever one existed, which silently hid the
    // word the question was actually about and left the player decoding a
    // symbol.
    if (question.promptEmoji != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(question.promptEmoji!, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            question.promptText,
            style: theme.textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (question.promptIsAudio) {
      return GestureDetector(
        onTap: () =>
            ref.read(ttsServiceProvider).speak(question.promptText, locale: question.ttsLocale),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 36),
        ),
      );
    }

    return Text(
      question.promptText,
      style: theme.textTheme.displaySmall,
      textAlign: TextAlign.center,
    );
  }
}
