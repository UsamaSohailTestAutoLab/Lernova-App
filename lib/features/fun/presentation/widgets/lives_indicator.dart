import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Session-local "lives" for a Fun round — deliberately not the same
/// widget as the global [HeartsChip]/`hearts` resource; see the
/// architecture note on why Fun lives are scoped to the round.
class LivesIndicator extends StatelessWidget {
  final int lives;
  final int maxLives;

  const LivesIndicator({super.key, required this.lives, required this.maxLives});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLives, (i) {
        final filled = i < lives;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            filled ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: AppColors.heart,
            size: 22,
          ),
        );
      }),
    );
  }
}
