import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/fun_content_providers.dart';
import '../../onboarding/application/user_controller.dart';
import '../../preview/application/retry_preview.dart';
import '../../preview/application/vocab_preview_builder.dart';
import '../../progress/application/progress_controller.dart';
import '../application/fun_memory_match_session_controller.dart';
import 'widgets/fun_results_shell.dart';

class FunMemoryMatchResultsScreen extends ConsumerStatefulWidget {
  const FunMemoryMatchResultsScreen({super.key});

  @override
  ConsumerState<FunMemoryMatchResultsScreen> createState() =>
      _FunMemoryMatchResultsScreenState();
}

class _FunMemoryMatchResultsScreenState extends ConsumerState<FunMemoryMatchResultsScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(funMemoryMatchSessionProvider);
      if (session != null && !session.failed) _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _playAgain(FunMemoryMatchState session) async {
    final languageId = ref.read(userProvider).selectedLanguageId;
    if (languageId == null) return;
    final words = await ref.read(funVocabWordsProvider(languageId).future);
    ref.read(funMemoryMatchSessionProvider.notifier).start(
          words: words,
          vocabStrength: ref.read(progressProvider).vocabStrength,
          pairCount: session.pairCount,
          random: Random(),
        );
    if (!mounted) return;
    final sourceWords = ref.read(funMemoryMatchSessionProvider)!.sourceWords;
    pushRetryPreview(
      context,
      items: VocabPreviewBuilder.fromVocabWords(sourceWords, languageId: languageId),
      levelLabel: 'Memory Match',
      onStartRoute: AppRoutes.funMemoryMatchPlay,
    );
  }

  void _done() {
    ref.read(funMemoryMatchSessionProvider.notifier).reset();
    context.go(AppRoutes.fun);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(funMemoryMatchSessionProvider);
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
          label: 'Pairs found',
          value: '${session.matchesFound}',
          color: AppColors.success,
        ),
      ],
      primaryLabel: session.funLeveledUp ? 'Next Level' : 'Play Again',
      onPrimary: () => _playAgain(session),
      onDone: _done,
    );
  }
}
