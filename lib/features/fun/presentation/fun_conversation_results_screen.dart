import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/fun_content_providers.dart';
import '../../onboarding/application/user_controller.dart';
import '../application/fun_conversation_session_controller.dart';
import 'widgets/fun_results_shell.dart';

class FunConversationResultsScreen extends ConsumerStatefulWidget {
  const FunConversationResultsScreen({super.key});

  @override
  ConsumerState<FunConversationResultsScreen> createState() =>
      _FunConversationResultsScreenState();
}

class _FunConversationResultsScreenState extends ConsumerState<FunConversationResultsScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _playAgain(FunConversationState session) async {
    final languageId = ref.read(userProvider).selectedLanguageId;
    if (languageId == null) return;
    final conversations = await ref.read(funConversationsProvider(languageId).future);
    ref.read(funConversationSessionProvider.notifier).start(
          pool: conversations,
          totalConversations: session.totalConversations,
          random: Random(),
        );
    if (!mounted) return;
    // Straight back in: the walkthrough at the head of each dialogue is
    // this mode's review step, so a separate one would just be a card
    // repeating the scenario.
    context.pushReplacement(AppRoutes.funConversationPlay);
  }

  void _done() {
    ref.read(funConversationSessionProvider.notifier).reset();
    context.go(AppRoutes.fun);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(funConversationSessionProvider);
    if (session == null || session.result == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final result = session.result!;

    return FunResultsShell(
      // Conversation Challenge has no lives/fail state — a wrong pick
      // just gets corrected and the dialogue continues, so a completed
      // session is always framed as a success.
      success: true,
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
