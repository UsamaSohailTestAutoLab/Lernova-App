import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/services/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/tts_locales.dart';
import '../../../data/models/fun/conversation.dart';
import '../../settings/application/settings_controller.dart';
import '../../languages/presentation/leave_session_sheet.dart';
import '../application/fun_conversation_session_controller.dart';
import 'widgets/combo_hud.dart';
import 'widgets/conversation_walkthrough.dart';

/// Conversation Challenge runs in three phases per dialogue:
/// **Learn** (English) → **Learn** (learning language, with audio) →
/// **Practice** (pick the reply, with meanings shown and feedback that
/// names both your answer and the expected one).
///
/// The two learn phases are screen-local state rather than session state:
/// they teach, they don't score, and keeping them out of the controller
/// leaves the scoring rules — and their tests — untouched.
class FunConversationScreen extends ConsumerStatefulWidget {
  const FunConversationScreen({super.key});

  @override
  ConsumerState<FunConversationScreen> createState() => _FunConversationScreenState();
}

class _FunConversationScreenState extends ConsumerState<FunConversationScreen> {
  bool _navigatedToResults = false;
  final _random = Random();
  final _scrollController = ScrollController();

  /// null once the walkthrough is done and practice has begun.
  ConversationStage? _stage = ConversationStage.english;

  /// Each new dialogue in a multi-conversation round gets its own
  /// walkthrough, so this resets when the index moves on.
  int _walkthroughForIndex = 0;

  void _choose(int optionIndex) {
    final settings = ref.read(settingsProvider);
    final s = ref.read(funConversationSessionProvider)!;
    final correct = optionIndex == s.currentTurn.correctIndex;
    if (settings.hapticsEnabled) {
      correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    }
    if (settings.soundEnabled) SystemSound.play(SystemSoundType.click);

    ref.read(funConversationSessionProvider.notifier).chooseResponse(optionIndex, _random);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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

    ref.read(funConversationSessionProvider.notifier).reset();
    router.pop();
    if (choice == LeaveSessionChoice.switchLanguage) {
      router.push(AppRoutes.languages);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(funConversationSessionProvider);
    final theme = Theme.of(context);

    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    if (session.isComplete && !_navigatedToResults) {
      _navigatedToResults = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(funConversationSessionProvider.notifier).finishAndApply();
        if (mounted) context.pushReplacement(AppRoutes.funConversationResults);
      });
    }

    final conversation = session.currentConversation;

    // A new dialogue restarts the walkthrough.
    if (session.currentConversationIndex != _walkthroughForIndex) {
      _walkthroughForIndex = session.currentConversationIndex;
      _stage = conversation.hasTranslations ? ConversationStage.english : null;
    }

    // Older content without translations goes straight to practice
    // rather than showing an English walkthrough it can't fill in.
    final stage = conversation.hasTranslations ? _stage : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _confirmExit),
          title: Text(conversation.title, overflow: TextOverflow.ellipsis),
          actions: [
            if (stage == null)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                child: Center(child: ComboHud(combo: session.combo, enabled: true)),
              ),
          ],
        ),
        body: SafeArea(
          child: stage != null
              ? ConversationWalkthrough(
                  conversation: conversation,
                  stage: stage,
                  onContinue: () => setState(() {
                    _stage = stage == ConversationStage.english
                        ? ConversationStage.target
                        : null;
                  }),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        conversation.scenario,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          for (var i = 0; i <= session.currentTurnIndex; i++)
                            if (i < conversation.turns.length)
                              _TurnBubbles(
                                turn: conversation.turns[i],
                                languageId: conversation.languageId,
                                answeredCorrectly: i < session.turnCorrectness.length
                                    ? session.turnCorrectness[i]
                                    : null,
                                chosenIndex: i < session.chosenIndices.length
                                    ? session.chosenIndices[i]
                                    : null,
                                onSelect: i == session.currentTurnIndex ? _choose : null,
                                awaitingRecallConfirmation:
                                    i == session.currentTurnIndex &&
                                        session.awaitingRecallConfirmation,
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TurnBubbles extends ConsumerWidget {
  final ConversationTurn turn;
  final String languageId;
  final bool? answeredCorrectly;
  final int? chosenIndex;
  final ValueChanged<int>? onSelect;
  final bool awaitingRecallConfirmation;

  const _TurnBubbles({
    required this.turn,
    required this.languageId,
    required this.answeredCorrectly,
    required this.chosenIndex,
    required this.onSelect,
    this.awaitingRecallConfirmation = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ttsLocale = TtsLocales.forLanguageId(languageId);
    final maxBubble = MediaQuery.of(context).size.width * 0.78;

    void speak(String text) =>
        ref.read(ttsServiceProvider).speak(text, locale: ttsLocale);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Their line, always with its English meaning underneath — the
          // learner should never have to guess what was just said to them.
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: maxBubble),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(turn.line, style: theme.textTheme.titleSmall)),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => speak(turn.line),
                        icon: const Icon(Icons.volume_up_rounded, size: 18),
                        tooltip: 'Listen',
                      ),
                    ],
                  ),
                  if (turn.lineEnglish != null)
                    Text(
                      turn.lineEnglish!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (answeredCorrectly != null)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: BoxConstraints(maxWidth: maxBubble),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: answeredCorrectly! ? AppColors.primary : AppColors.error,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          answeredCorrectly! ? Icons.check_rounded : Icons.close_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            turn.correctResponse,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    if (turn.correctResponseEnglish != null)
                      Text(
                        turn.correctResponseEnglish!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                      ),
                  ],
                ),
              ),
            ),
          // A wrong pick names what the learner said, what was expected,
          // and what it means — then offers the audio, rather than just
          // flashing red and moving on.
          if (answeredCorrectly == false) ...[
            const SizedBox(height: AppSpacing.sm),
            _MissFeedback(
              said: chosenIndex != null && chosenIndex! < turn.options.length
                  ? turn.options[chosenIndex!]
                  : null,
              saidEnglish:
                  chosenIndex != null ? turn.englishFor(chosenIndex!) : null,
              expected: turn.correctResponse,
              expectedEnglish: turn.correctResponseEnglish,
              onListen: () => speak(turn.correctResponse),
            ),
          ],
          if (awaitingRecallConfirmation) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Now tap the correct response:',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
              ),
            ),
          ],
          if (answeredCorrectly == null || awaitingRecallConfirmation) ...[
            const SizedBox(height: AppSpacing.sm),
            // Options carry their English meaning, so the choice is
            // "which reply fits" rather than "which string looks right".
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < turn.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: OutlinedButton(
                      onPressed: () => onSelect?.call(i),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(turn.options[i], style: theme.textTheme.titleSmall),
                          if (turn.englishFor(i) != null)
                            Text(
                              turn.englishFor(i)!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.outline),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MissFeedback extends StatelessWidget {
  final String? said;
  final String? saidEnglish;
  final String expected;
  final String? expectedEnglish;
  final VoidCallback onListen;

  const _MissFeedback({
    required this.said,
    required this.saidEnglish,
    required this.expected,
    required this.expectedEnglish,
    required this.onListen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✗ Not quite',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (said != null)
            Text(
              'You said: $said${saidEnglish != null ? ' — $saidEnglish' : ''}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurface),
            ),
          Text(
            'Expected: $expected${expectedEnglish != null ? ' — $expectedEnglish' : ''}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: onListen,
              icon: const Icon(Icons.volume_up_rounded, size: 20),
              label: const Text('Listen'),
            ),
          ),
        ],
      ),
    );
  }
}
