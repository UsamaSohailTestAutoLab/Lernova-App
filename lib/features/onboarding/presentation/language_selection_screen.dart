import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selectable_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/repositories/content_providers.dart';
import '../application/onboarding_controller.dart';
import 'onboarding_step_scaffold.dart';

class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languagesAsync = ref.watch(languagesProvider);
    final selections = ref.watch(onboardingProvider);

    return OnboardingStepScaffold(
      stepProgress: 0.15,
      title: 'What do you want to learn?',
      subtitle: 'Pick a language to start your course.',
      ctaLabel: 'Continue',
      onCta: selections.languageId != null
          ? () => context.push(AppRoutes.goalSelection)
          : null,
      content: languagesAsync.when(
        data: (languages) => Column(
          children: [
            for (final language in languages) ...[
              SelectableTile(
                title: language.name,
                subtitle: language.nativeName,
                leading: Text(language.flagEmoji, style: const TextStyle(fontSize: 28)),
                selected: selections.languageId == language.id,
                onTap: () =>
                    ref.read(onboardingProvider.notifier).setLanguage(language.id),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
        loading: () => Column(
          children: List.generate(
            3,
            (i) => const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: SkeletonBox(height: 76),
            ),
          ),
        ),
        error: (e, st) => ErrorStateView(
          message: 'Could not load languages.',
          onRetry: () => ref.invalidate(languagesProvider),
        ),
      ),
    );
  }
}
