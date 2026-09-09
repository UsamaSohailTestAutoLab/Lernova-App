import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_background.dart';
import 'app_buttons.dart';
import 'app_metric.dart';
import 'gamification_indicators.dart';
import 'lernova_parrot.dart';

/// - [ring] — a [ProgressRing] with a center label (level-up, daily goal).
/// - [badge] — a large icon in a soft radial glow (achievement unlock).
/// - [mascot] — [LernovaParrot] (lesson/round complete) — the same
///   character shown on the level's own start screen, so finishing a
///   level and starting one read as the same app.
/// - [count] — a counting-up number (XP reward).
enum CelebrationHero { ring, badge, mascot, count }

enum CelebrationIntensity { none, soft, medium, full }

/// The shared "you did it" scaffold. Four screens previously reimplemented
/// this shape independently with one variable swapped each time, and none
/// of them had confetti — [intensity] now owns that per-screen so a chain
/// of celebration screens can each feel distinct instead of identical.
class CelebrationScaffold extends StatefulWidget {
  final String headline;
  final String? subline;
  final CelebrationHero hero;
  final List<AppMetricData> stats;
  final List<Widget> pills;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final CelebrationIntensity intensity;
  final Color accent;

  final int? countValue;
  final double? ringProgress;
  final String? ringCenterLabel;
  final IconData? badgeIcon;
  final LernovaParrotMood mascotMood;

  /// An optional way back out of the screen, drawn as an arrow in the
  /// top-left. Celebrations do not want one — there is nothing to go
  /// back to, and the primary button is the way forward — but a screen
  /// that reports a *failed* attempt is a dead end without it.
  final VoidCallback? onBack;

  const CelebrationScaffold({
    super.key,
    required this.headline,
    this.subline,
    required this.hero,
    this.stats = const [],
    this.pills = const [],
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.intensity = CelebrationIntensity.medium,
    this.accent = AppColors.primary,
    this.countValue,
    this.ringProgress,
    this.ringCenterLabel,
    this.badgeIcon,
    this.mascotMood = LernovaParrotMood.celebrate,
    this.onBack,
  });

  @override
  State<CelebrationScaffold> createState() => _CelebrationScaffoldState();
}

class _CelebrationScaffoldState extends State<CelebrationScaffold> {
  ConfettiController? _confetti;

  @override
  void initState() {
    super.initState();
    if (widget.intensity != CelebrationIntensity.none) {
      _confetti = ConfettiController(duration: _durationFor(widget.intensity))..play();
    }
  }

  static Duration _durationFor(CelebrationIntensity i) => switch (i) {
        CelebrationIntensity.soft => const Duration(milliseconds: 900),
        CelebrationIntensity.medium => const Duration(seconds: 2),
        CelebrationIntensity.full => const Duration(seconds: 3),
        CelebrationIntensity.none => Duration.zero,
      };

  static int _particlesFor(CelebrationIntensity i) => switch (i) {
        CelebrationIntensity.soft => 12,
        CelebrationIntensity.medium => 24,
        CelebrationIntensity.full => 40,
        CelebrationIntensity.none => 0,
      };

  @override
  void dispose() {
    _confetti?.dispose();
    super.dispose();
  }

  Widget _hero(BuildContext context) {
    final theme = Theme.of(context);
    switch (widget.hero) {
      case CelebrationHero.mascot:
        return LernovaParrot(size: 130, mood: widget.mascotMood);
      case CelebrationHero.badge:
        return Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [widget.accent.withValues(alpha: 0.25), widget.accent.withValues(alpha: 0)],
            ),
          ),
          child: Icon(widget.badgeIcon ?? Icons.emoji_events_rounded, size: 56, color: widget.accent),
        );
      case CelebrationHero.ring:
        return ProgressRing(
          progress: widget.ringProgress ?? 1,
          size: 120,
          strokeWidth: 10,
          color: widget.accent,
          trackColor: widget.accent.withValues(alpha: 0.15),
          center: widget.ringCenterLabel == null
              ? null
              : Text(widget.ringCenterLabel!, style: theme.textTheme.headlineSmall),
        );
      case CelebrationHero.count:
        return TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: widget.countValue ?? 0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return Text(
              '+$value',
              style: theme.textTheme.displayLarge?.copyWith(color: widget.accent),
            );
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confetti = _confetti;

    return AppBackground(
      variant: AppBackdrop.celebration,
      tint: widget.accent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          alignment: Alignment.topCenter,
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    const Spacer(),
                    _hero(context),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      widget.headline,
                      style: theme.textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (widget.subline != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(widget.subline!, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                    ],
                    if (widget.stats.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpacing.xl,
                        runSpacing: AppSpacing.md,
                        children: [
                          for (final stat in widget.stats)
                            AppMetric(data: stat, layout: MetricLayout.column),
                        ],
                      ),
                    ],
                    if (widget.pills.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: widget.pills,
                      ),
                    ],
                    const Spacer(),
                    PrimaryButton(label: widget.primaryLabel, onPressed: widget.onPrimary),
                    if (widget.secondaryLabel != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SecondaryButton(label: widget.secondaryLabel!, onPressed: widget.onSecondary),
                    ],
                  ],
                ),
              ),
            ),
            if (widget.onBack != null)
              Positioned(
                left: AppSpacing.sm,
                top: 0,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                    onPressed: widget.onBack,
                  ),
                ),
              ),
            if (confetti != null)
              ConfettiWidget(
                confettiController: confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: _particlesFor(widget.intensity),
                maxBlastForce: 18,
                minBlastForce: 6,
                gravity: 0.25,
                colors: const [AppColors.primary, AppColors.accent, AppColors.success, AppColors.gem],
              ),
          ],
        ),
      ),
    );
  }
}
