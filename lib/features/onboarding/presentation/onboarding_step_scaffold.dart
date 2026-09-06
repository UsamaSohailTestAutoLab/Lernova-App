import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';

/// Shared shell for every onboarding step: a thin progress bar, a
/// title/subtitle, scrollable content, and a pinned primary CTA.
class OnboardingStepScaffold extends StatelessWidget {
  final double stepProgress;
  final String title;
  final String? subtitle;
  final Widget content;
  final String ctaLabel;
  final VoidCallback? onCta;
  final bool ctaLoading;
  final Widget? secondaryAction;

  const OnboardingStepScaffold({
    super.key,
    required this.stepProgress,
    required this.title,
    this.subtitle,
    required this.content,
    required this.ctaLabel,
    required this.onCta,
    this.ctaLoading = false,
    this.secondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.xl),
          child: LinearProgressIndicator(value: stepProgress, minHeight: 8),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Text(title, style: theme.textTheme.headlineLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(subtitle!, style: theme.textTheme.bodyMedium),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    content,
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  PrimaryButton(label: ctaLabel, onPressed: onCta, isLoading: ctaLoading),
                  if (secondaryAction != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    secondaryAction!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
