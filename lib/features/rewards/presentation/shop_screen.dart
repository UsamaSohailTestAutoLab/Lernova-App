import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/icon_mapper.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/gamification_indicators.dart';
import '../../../data/models/reward.dart';
import '../../progress/application/progress_controller.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Center(child: GemsChip(gems: progress.gems)),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: shopCatalog.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          final item = shopCatalog[i];
          final owned = item.type == ShopItemType.streakFreeze && progress.streakFreezeAvailable;
          final canAfford = progress.gems >= item.gemCost;

          return AppCard(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.gem.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(shopIconFor(item.icon), color: AppColors.gem),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: theme.textTheme.titleMedium),
                      Text(item.description, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 96,
                  child: owned
                      ? const Center(child: Icon(Icons.check_circle_rounded, color: AppColors.success))
                      : SecondaryButton(
                          label: '${item.gemCost}',
                          icon: Icons.diamond_outlined,
                          onPressed: !canAfford ? null : () => _buy(context, ref, item),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _buy(BuildContext context, WidgetRef ref, ShopItem item) {
    final controller = ref.read(progressProvider.notifier);
    final bool success = switch (item.type) {
      ShopItemType.streakFreeze => controller.spendGemsForStreakFreeze(),
      ShopItemType.mascotOutfit => controller.spendGemsForMascotOutfit(),
    };
    AppSnackBar.show(
      context,
      success ? '${item.title} purchased!' : 'Not enough gems',
      isError: !success,
    );
  }
}
