import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/swipe_carousel.dart';
import '../application/onboarding_explainer_content.dart';

/// A one-time "how LingoQuest works" walkthrough shown between Welcome's
/// "Get started" and account creation for new users — also reachable
/// again later from Settings for anyone who wants a refresher.
class OnboardingExplainerScreen extends StatelessWidget {
  /// True when reached from Settings ("replay the intro") rather than
  /// the first-time Welcome flow — in that case the CTA just closes the
  /// walkthrough instead of pushing into account creation.
  final bool isReplay;
  const OnboardingExplainerScreen({super.key, this.isReplay = false});

  void _finish(BuildContext context) {
    if (isReplay) {
      context.pop();
    } else {
      // No sign-up step any more — just a name, then a language.
      context.push(AppRoutes.nameEntry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slides = onboardingExplainerSlides;

    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => _finish(context),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: SwipeCarouselScaffold(
            itemCount: slides.length,
            itemBuilder: (context, index) {
              final slide = slides[index];
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(slide.emoji, style: const TextStyle(fontSize: 72)),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      slide.title,
                      style: theme.textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (slide.callout != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      // Scales itself down rather than wrapping into a
                      // fourth line on a small phone, so the call to
                      // action always lands as one confident block.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          slide.callout!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      slide.body,
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
            bottomBuilder: (context, index, goNext) {
              final isLast = index >= slides.length - 1;
              return SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: isLast ? (isReplay ? 'Done' : 'Ready 🚀') : 'Next',
                  onPressed: isLast ? () => _finish(context) : goNext,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
