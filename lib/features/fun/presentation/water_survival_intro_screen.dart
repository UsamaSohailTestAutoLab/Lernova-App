import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decor.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/lernova_parrot.dart';
import '../../progress/application/progress_controller.dart';
import 'widgets/realistic_water.dart';

/// Identifies this explainer in `UserProgress.seenTutorialIds`.
///
/// Deliberately re-keyed when the mechanic moved out of Word Bubble
/// into its own mode: a player who saw it as "Word Bubble level 1" has
/// not yet met Word Survival, and the explainer is worth one more
/// showing on the game it now belongs to.
const waterSurvivalTutorialId = 'fun.wordSurvival.intro';

/// Explains Word Survival's rising-water mechanic *before* it starts.
///
/// The mode dresses a catch-the-meaning round as a character standing
/// in rising water: every wrong or missed answer raises it, and a full
/// set of lost hearts drowns them. Learners met that with no warning —
/// the first they knew of the stakes was the water already at chest
/// height. This says what to do while there is still time to act on it.
class WaterSurvivalIntroScreen extends ConsumerStatefulWidget {
  const WaterSurvivalIntroScreen({super.key});

  @override
  ConsumerState<WaterSurvivalIntroScreen> createState() =>
      _WaterSurvivalIntroScreenState();
}

class _WaterSurvivalIntroScreenState extends ConsumerState<WaterSurvivalIntroScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the demo: water creeping up, then dropping back. Slow and
  /// looping rather than eye-catching — this plays under text people
  /// are meant to be reading.
  late final AnimationController _demo = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  bool _starting = false;

  @override
  void dispose() {
    _demo.dispose();
    super.dispose();
  }

  void _start() {
    // Guards a double tap on the CTA from pushing the game twice.
    if (_starting) return;
    setState(() => _starting = true);
    ref.read(progressProvider.notifier).markTutorialSeen(waterSurvivalTutorialId);
    // pushReplacement, so backing out of the game returns to where the
    // learner came from rather than to this screen again.
    context.pushReplacement(AppRoutes.funGamePlay);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                children: [
                  const Center(
                    child: LernovaParrot(size: 104, mood: LernovaParrotMood.curious),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Watch out! 🌊',
                    style: theme.textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'The water is rising. Answer fast to keep your '
                    'friend above it.',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RisingWaterDemo(animation: _demo),
                  const SizedBox(height: AppSpacing.lg),
                  const _Step(
                    number: '1',
                    icon: Icons.translate_rounded,
                    text: 'Tap the bubble with the right meaning.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _Step(
                    number: '2',
                    icon: Icons.timer_outlined,
                    text: 'Be quick — the bar under the scene is your time.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _Step(
                    number: '3',
                    icon: Icons.waves_rounded,
                    text: 'Every wrong or missed answer raises the water. '
                        'Lose all your hearts and it goes over their head.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: PrimaryButton(
                label: 'Got it! Start level',
                onPressed: _starting ? null : _start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A miniature of the real arena: water creeping up a figure, then
/// falling back. Shows the stake in a second, which is faster than the
/// sentence explaining it.
class _RisingWaterDemo extends StatelessWidget {
  final Animation<double> animation;
  const _RisingWaterDemo({required this.animation});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: 150,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(
              child: ColoredBox(color: context.decor.tint(AppColors.info)),
            ),
            const Positioned(
              bottom: 8,
              child: LernovaParrot(size: 96, mood: LernovaParrotMood.happy),
            ),
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                // 20% to 78% of the box: ankle-deep up to over the head,
                // the same span the real arena covers.
                final t = Curves.easeInOut.transform(animation.value);
                return SizedBox(
                  height: 150 * (0.2 + 0.58 * t),
                  width: double.infinity,
                  child: const RealisticWater(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final IconData icon;
  final String text;

  const _Step({required this.number, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
