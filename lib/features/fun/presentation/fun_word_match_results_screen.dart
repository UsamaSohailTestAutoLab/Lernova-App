import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/fun_content_providers.dart';
import '../../onboarding/application/user_controller.dart';
import '../../progress/application/progress_controller.dart';
import '../application/fun_word_match_session_controller.dart';
import 'widgets/fun_results_shell.dart';

class FunWordMatchResultsScreen extends ConsumerStatefulWidget {
  const FunWordMatchResultsScreen({super.key});

  @override
  ConsumerState<FunWordMatchResultsScreen> createState() => _FunWordMatchResultsScreenState();
}

class _FunWordMatchResultsScreenState extends ConsumerState<FunWordMatchResultsScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(funWordMatchSessionProvider);
      if (session != null && !session.failed) _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _playAgain(FunWordMatchState session) async {
    final languageId = ref.read(userProvider).selectedLanguageId;
    if (languageId == null) return;
    final words = await ref.read(funVocabWordsProvider(languageId).future);
    ref.read(funWordMatchSessionProvider.notifier).start(
          words: words,
          vocabStrength: ref.read(progressProvider).vocabStrength,
          totalRounds: session.totalRounds,
          pairsPerRound: session.pairsPerRound,
          random: Random(),
        );
    if (mounted) context.pushReplacement(AppRoutes.funWordMatchPlay);
  }

  void _done() {
    ref.read(funWordMatchSessionProvider.notifier).reset();
    context.go(AppRoutes.fun);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(funWordMatchSessionProvider);
    if (session == null || session.result == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final result = session.result!;

    return FunResultsShell(
      success: !session.failed,
      leveledUp: session.funLeveledUp,
      dailyChallengeJustCompleted: session.dailyChallengeJustCompleted,
      confettiController: _confetti,
      stats: [
        FunResultStat(label: 'XP', value: '+${result.xpEarned}', color: AppColors.accent),
        FunResultStat(label: 'Coins', value: '+${session.coinsEarned}', color: AppColors.gem),
        FunResultStat(
          label: 'Best combo',
          value: '${session.bestCombo}',
          color: AppColors.streak,
        ),
        FunResultStat(
          label: 'Accuracy',
          value: '${(session.accuracy * 100).round()}%',
          color: AppColors.success,
        ),
      ],
      primaryLabel: session.funLeveledUp ? 'Next Level' : 'Play Again',
      onPrimary: () => _playAgain(session),
      onDone: _done,
    );
  }
}
