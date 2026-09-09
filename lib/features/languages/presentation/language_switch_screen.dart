import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decor.dart';
import '../../../core/theme/app_radius_ext.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/lernova_parrot.dart';
import '../../../core/widgets/state_views.dart';
import '../application/language_switch_controller.dart';

/// Picks which language to learn, and shows what is waiting in each.
///
/// The per-language "Unit 2 · Lesson 3" line is the point of the
/// screen, not decoration: switching only feels safe if you can see,
/// before you tap, that the course you are leaving will still be there
/// when you come back.
class LanguageSwitchScreen extends ConsumerStatefulWidget {
  const LanguageSwitchScreen({super.key});

  @override
  ConsumerState<LanguageSwitchScreen> createState() =>
      _LanguageSwitchScreenState();
}

class _LanguageSwitchScreenState extends ConsumerState<LanguageSwitchScreen> {
  /// Guards against a second tap while the first switch is still
  /// parking progress — two overlapping park/restores would file one
  /// language's slice under the other.
  bool _switching = false;

  /// Closes the screen back to whatever opened it, or Home when it was
  /// reached in a way that left nothing to pop (straight after a switch,
  /// or out of a lesson that was torn down behind us).
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _select(LanguageSummary summary) async {
    if (_switching) return;

    // Tapping the language you are already learning means "carry on with
    // this one", so it closes the screen. It used to do nothing at all,
    // which read as the tap being ignored.
    if (summary.isActive) {
      _leave();
      return;
    }

    if (!summary.isAvailable) {
      AppSnackBar.show(context, '${summary.language.name} is coming soon.');
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Learn ${summary.language.name}?',
      message: summary.hasStarted
          ? 'You will pick up ${summary.language.name} at '
              '${summary.positionLabel}. Your current progress is saved.'
          : 'You will start ${summary.language.name} from Unit 1, Lesson 1. '
              'Your current progress is saved.',
      confirmLabel: summary.hasStarted ? 'Continue' : 'Start',
    );
    if (!confirmed || !mounted) return;

    setState(() => _switching = true);
    try {
      final outcome = await ref
          .read(languageSwitchControllerProvider)
          .switchTo(summary.language.id);
      if (!mounted) return;
      AppSnackBar.show(
        context,
        outcome.isFirstTime
            ? 'Starting ${outcome.language.name} from the beginning.'
            : 'Welcome back to ${outcome.language.name}.',
      );
      context.go(AppRoutes.home);
    } catch (_) {
      if (!mounted) return;
      setState(() => _switching = false);
      AppSnackBar.show(context, 'Could not switch to ${summary.language.name}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summariesAsync = ref.watch(languageSummariesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Switch language'),
        // Explicit rather than automatic: this screen is opened from
        // Home, from Settings, and from inside a lesson that gets torn
        // down on the way here — the last of which can leave nothing to
        // pop and so no arrow at all.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: _leave,
        ),
      ),
      // The header stays put while the list scrolls under it. With ten
      // languages the list is the screen; a mascot that scrolls away
      // takes the explanation of what the screen does with it.
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                const LernovaParrot(size: 56),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Every language keeps its own progress',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Switch whenever you like — you come back to exactly '
                  'where you stopped.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: summariesAsync.when(
              data: (summaries) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                itemCount: summaries.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) => _LanguageCard(
                  summary: summaries[i],
                  busy: _switching,
                  onTap: () => _select(summaries[i]),
                ),
              ),
              loading: () => ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                children: List.generate(
                  5,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: SkeletonBox(height: 92),
                  ),
                ),
              ),
              error: (e, st) => ErrorStateView(
                message: 'Could not load languages.',
                onRetry: () => ref.invalidate(languageSummariesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final LanguageSummary summary;
  final bool busy;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.summary,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = context.decor;
    final surfaceColors = context.surfaceColors;
    final active = summary.isActive;
    final available = summary.isAvailable;

    return Opacity(
      opacity: available ? 1 : 0.55,
      child: Material(
        color: active ? decor.tint(AppColors.primary) : surfaceColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: active ? AppColors.primary : surfaceColors.border,
                width: active ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  summary.language.flagEmoji,
                  style: const TextStyle(fontSize: 34),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              summary.language.name,
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (active) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const AppPill(
                              label: 'Learning now',
                              color: AppColors.primary,
                              filled: true,
                              size: 0.85,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        summary.language.nativeName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        summary.positionLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: available
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (available && summary.totalLessons > 0) ...[
                        const SizedBox(height: AppSpacing.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value:
                                summary.lessonsCompleted / summary.totalLessons,
                            minHeight: 6,
                            backgroundColor: surfaceColors.border,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${summary.lessonsCompleted} of '
                          '${summary.totalLessons} lessons',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!active)
                  Icon(
                    available
                        ? Icons.chevron_right_rounded
                        : Icons.lock_outline_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
