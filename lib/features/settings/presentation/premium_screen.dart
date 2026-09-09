import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/services/purchase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decor.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/lernova_parrot.dart';
import '../../progress/application/progress_controller.dart';
import '../application/purchase_controller.dart';

/// What Pro actually unlocks.
///
/// Every line here maps to a real gate in the code: `CourseProgress`
/// checks `isPremium` before opening a unit or lesson, and the same flag
/// opens the Fun Zone's higher levels. Nothing aspirational goes on this
/// list — an unimplemented promise on a paid screen is a refund request.
const _proBenefits = [
  (
    Icons.route_rounded,
    'Every lesson on the Path',
    'All units and levels, unlocked from today.',
  ),
  (
    Icons.sports_esports_rounded,
    'The whole Fun Zone',
    'Every game and every level, no waiting to unlock.',
  ),
  (
    Icons.replay_rounded,
    'Unlimited practice',
    'Replay any level as often as you like, with fresh questions each time.',
  ),
];

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPro = ref.watch(progressProvider).isPremium;
    final purchase = ref.watch(purchaseProvider);

    // Messages surface as a snackbar rather than inline, so a long
    // store error never reflows the plan cards under the learner's
    // finger mid-tap.
    ref.listen<PurchaseState>(purchaseProvider, (previous, next) {
      final message = next.message;
      if (message == null || message == previous?.message) return;
      AppSnackBar.show(context, message, isError: next.isError);
      ref.read(purchaseProvider.notifier).clearMessage();
    });

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          children: [
            _Header(isPro: isPro),
            const SizedBox(height: AppSpacing.xl),
            for (final benefit in _proBenefits) ...[
              _BenefitRow(
                icon: benefit.$1,
                title: benefit.$2,
                detail: benefit.$3,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.md),
            if (isPro)
              _ActiveMemberCard(entitlementProductId: purchase.selectedProductId)
            else
              _PlanSection(state: purchase),
            const SizedBox(height: AppSpacing.lg),
            if (!isPro) _Cta(state: purchase),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: purchase.isBusy
                    ? null
                    : () => ref.read(purchaseProvider.notifier).restore(),
                child: const Text('Restore Purchases'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Subscriptions renew automatically until cancelled. Manage or '
              'cancel any time in your store account settings.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isPro;
  const _Header({required this.isPro});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // The mascot carries the brand here rather than a stock crown,
        // and stays small so the plans keep the visual weight.
        const LernovaParrot(size: 116, mood: LernovaParrotMood.celebrate),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: context.decor.tint(AppColors.accent),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            'LERNOVA PRO',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          isPro ? 'You have it all' : 'Learn without limits',
          style: theme.textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          isPro
              ? 'Every lesson and every game is open to you.'
              : 'Open every lesson and every game, today.',
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.decor.tint(AppColors.primary),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                detail,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanSection extends ConsumerWidget {
  final PurchaseState state;
  const _PlanSection({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (state.phase == PurchasePhase.loadingProducts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // No invented prices, ever. If the store didn't answer, say so.
    if (state.products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.decor.tint(AppColors.error),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.error),
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.storeUnavailable
                  ? 'Prices unavailable — check your connection.'
                  : 'Plans are not available right now.',
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => ref.read(purchaseProvider.notifier).loadProducts(),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final product in state.products) ...[
          _PlanCard(
            product: product,
            selected: product.id == state.selectedProduct?.id,
            enabled: !state.isBusy,
            onTap: () => ref.read(purchaseProvider.notifier).selectPlan(product.id),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final ProductDetails product;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PlanCard({
    required this.product,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  /// The billing period, derived from the product id rather than parsed
  /// out of the store's localized title — that title is translated and
  /// often carries the app name, so it is display text, not data.
  String get _period =>
      product.id == ProProducts.monthly ? 'per month' : 'per week';

  /// The longer period is the better deal per day, so it carries the
  /// badge — and [PurchaseController] sorts by price so it lands on top.
  bool get _isBestValue => product.id == ProProducts.monthly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = selected ? AppColors.primary : theme.colorScheme.outline;

    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? context.decor.tint(AppColors.primary)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: accent, width: selected ? 2.5 : 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: enabled ? onTap : null,
            child: Padding(
              // 56dp of vertical room keeps the whole card a comfortable
              // touch target even at the smallest text size.
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.primary : Colors.transparent,
                      border: Border.all(color: accent, width: 2),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                        : null,
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
                                product.id == ProProducts.monthly
                                    ? 'Monthly'
                                    : 'Weekly',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (_isBestValue) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(
                                  'BEST VALUE',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          _period,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Straight from the store, already localized to the
                  // learner's storefront currency and formatting.
                  Text(
                    product.price,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cta extends ConsumerWidget {
  final PurchaseState state;
  const _Cta({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = state.phase == PurchasePhase.pending;
    return PrimaryButton(
      label: pending ? 'Waiting for the store…' : 'Upgrade to Pro',
      // Disabled while a sheet is open or a purchase is pending: this is
      // what stops an impatient double tap becoming two transactions.
      isLoading: state.phase == PurchasePhase.working,
      onPressed: state.isBusy || pending || state.products.isEmpty
          ? null
          : () => ref.read(purchaseProvider.notifier).buySelected(),
    );
  }
}

class _ActiveMemberCard extends StatelessWidget {
  final String? entitlementProductId;
  const _ActiveMemberCard({this.entitlementProductId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.decor.tint(AppColors.success),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.success),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: AppColors.success, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Pro subscription is active',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Manage or cancel it in your store account settings.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
