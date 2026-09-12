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
import '../application/fun_sentence_builder_session_controller.dart';
import 'widgets/fun_results_shell.dart';

class FunSentenceBuilderResultsScreen extends ConsumerStatefulWidget {
  const FunSentenceBuilderResultsScreen({super.key});

  @override
  ConsumerState<FunSentenceBuilderResultsScreen> createState() =>
      _FunSentenceBuilderResultsScreenState();
}

class _FunSentenceBuilderResultsScreenState
    extends ConsumerState<FunSentenceBuilderResultsScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(funSentenceBuilderSessionProvider);
      if (session != null && !session.failed) _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _playAgain(FunSentenceBuilderState session) async {
    final languageId = ref.read(userProvider).selectedLanguageId;
    if (languageId == null) return;
    final phrases = await ref.read(funPhrasesProvider(languageId).future);
    ref.read(funSentenceBuilderSessionProvider.notifier).start(
          pool: phrases,
          totalRounds: session.totalRounds,
          random: Random(),
        );
    if (!mounted) return;
    final roundPhrases = ref.read(funSentenceBuilderSessionProvider)!.pool;
    pushRetryPreview(
      context,
      items: [
        for (final p in roundPhrases)
          VocabPreviewBuilder.fromPhrase(p, languageId: languageId),
      ],
      levelLabel: 'Sentence Builder',
      onStartRoute: AppRoutes.funSentenceBuilderPlay,
    );
  }

  void _done() {
    ref.read(funSentenceBuilderSessionProvider.notifier).reset();
    context.go(AppRoutes.fun);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(funSentenceBuilderSessionProvider);
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
