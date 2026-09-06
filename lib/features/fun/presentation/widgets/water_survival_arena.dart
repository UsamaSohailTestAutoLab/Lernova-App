import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/fun/fun_question.dart';
import '../../../../core/widgets/cartoon_character.dart';
import 'realistic_water.dart';
import 'water_bubble.dart';

/// Level 1's themed presentation for Falling Words: a cartoon character
/// stands at a fixed spot near the bottom while the water level rises
/// *over* it as hearts are lost — at 0 hearts lost the character is dry
/// and clear of the water, at full hearts lost it's completely
/// submerged. This is a pure presentation swap over the *same*
/// session/answer logic every other level and mode uses — lives, combo,
/// XP, and the win/fail rules are untouched; only how a question and its
/// options are drawn changes.
class WaterSurvivalArena extends StatelessWidget {
  final FunQuestion question;
  final int lives;
  final int maxLives;
  final int? tappedIndex;
  final BubbleVisualState tappedState;
  final CartoonCharacterMood mascotMood;
  final double countdownFraction;
  final ValueChanged<int> onSelect;

  const WaterSurvivalArena({
    super.key,
    required this.question,
    required this.lives,
    required this.maxLives,

    required this.tappedIndex,
    required this.tappedState,
    required this.mascotMood,
    required this.countdownFraction,
    required this.onSelect,
  });

  static const _characterSize = 132.0;
  static const _characterBottom = 10.0;

  @override
  Widget build(BuildContext context) {
    final lostFraction = ((maxLives - lives) / maxLives).clamp(0.0, 1.0);

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Water rises from a shallow, ankle-deep start at full
              // health up to a level guaranteed to fully cover the
              // character once every heart is lost.
              const minWaterHeight = 44.0;
              final fullDrownHeight = _characterBottom + _characterSize * 1.28;
              final maxWaterHeight = math.min(constraints.maxHeight * 0.9, fullDrownHeight);
              final waterHeight =
                  minWaterHeight + (maxWaterHeight - minWaterHeight) * lostFraction;

              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Character stays put — the water rises in front of
                  // it, so more of it visually disappears underwater as
                  // hearts are lost instead of the character "floating"
                  // on the surface.
                  Positioned(
                    bottom: _characterBottom,
                    child: CartoonCharacter(size: _characterSize, mood: mascotMood),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    height: waterHeight,
                    width: constraints.maxWidth,
                    child: const RealisticWater(),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.xl),
            child: LinearProgressIndicator(
              value: countdownFraction.clamp(0, 1),
              minHeight: 6,
              color: countdownFraction < 0.3 ? AppColors.error : AppColors.primary,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        // Answers sit in one row of wide pills under the scene. With the
        // 2-3 option cap there is always room for a full-width pill per
        // option, so the label never has to shrink to fit.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final count = question.options.length;
              final slot = (constraints.maxWidth - AppSpacing.md * (count - 1)) / count;
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (var i = 0; i < count; i++)
                    WaterBubble(
                      label: question.options[i],
                      emoji: question.emojiFor(i),
                      state: tappedIndex == i ? tappedState : BubbleVisualState.idle,
                      width: slot.clamp(120.0, 240.0),
                      height: 72,
                      onTap: () => onSelect(i),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
