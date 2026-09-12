import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/services/purchase_service.dart';
import '../../../core/services/store_offer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decor.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_metric.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/lingoquest_parrot.dart';
import '../../../data/models/pro_entitlement.dart';
import '../../../data/models/user_progress.dart';
import '../../progress/application/progress_controller.dart';
import '../application/purchase_controller.dart';

/// What Pro actually unlocks.
///
/// Every line here maps to a real gate in the code: `CourseProgress`
/// checks `isPremium` before opening a unit or lesson, and the same flag
/// opens the Fun Zone's higher levels. Nothing aspirational goes on this
/// list — an unimplemented promise on a paid screen is a refund request.
const _proBenefits = [
  (Icons.route_rounded, 'Every lesson on the Path'),
  (Icons.sports_esports_rounded, 'Every game in the Fun Zone'),
  (Icons.replay_rounded, 'Unlimited practice, fresh questions'),
];

/// The Pro screen shows everything at once — no scrolling.
///
/// A paywall that scrolls hides either the plans or the price behind a
/// swipe, and the learner decides on what they can see.
///
/// Fitting it on one screen is a design problem, not only a layout one.
/// A centred stack of loose rows with flexible gaps between them does
/// technically fit, but it reads as a few orphaned lines adrift in
/// whitespace, because every gap that opens up lands *between* the
/// content rather than around it. So the screen is built as three blocks
/// with real edges — a warm hero band, one card holding the benefits
/// together, and a tight group of plans sitting above the button — with
/// a single flexible gap in the middle. The eye then has somewhere to
/// land at every screen height.
///
/// It degrades to scrolling in exactly one case: when the content
/// genuinely cannot fit — a small screen at a large accessibility text
/// size, or a landscape window. Clipping the price to keep the screen
/// static would be the worse failure of the two.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final isPro = progress.isPremium;
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
      // The hero band runs to the very top of the screen, with only the
      // back button floating over it.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            // ClampingScrollPhysics, not Never: when the content does
            // overflow at a large text size the learner must still be
            // able to reach the button. It simply never has anywhere to
            // scroll at ordinary sizes.
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: _Body(
                  isPro: isPro,
                  purchase: purchase,
                  entitlement: progress.proEntitlement,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final bool isPro;
  final PurchaseState purchase;
  final ProEntitlement entitlement;

  const _Body({
    required this.isPro,
    required this.purchase,
    required this.entitlement,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Two genuinely different pages behind one route. Selling asks the
    // reader to compare plans, so its weight belongs at the bottom by
    // the button; confirming a membership answers "what do I have?",
    // which belongs at the top. Sharing one column meant the plan cards
    // were the only thing holding the spacing together — take them out
    // and the flex gaps blew open into a screen with a headline at the
    // top, a receipt at the bottom and a hole between them.
    return isPro
        ? _MemberBody(entitlement: entitlement)
        : _SalesBody(purchase: purchase);
  }
}

/// What a subscriber sees.
///
/// Top-weighted: the membership card sits directly under the hero,
/// because the first question somebody opening this screen after paying
/// has is whether the payment registered.
class _MemberBody extends ConsumerWidget {
  final ProEntitlement entitlement;
  const _MemberBody({required this.entitlement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = ref.watch(progressProvider);
    // The membership card, the benefits and the manage button are the
    // screen's job; the stats are a bonus, and on a 667pt phone they are
    // the block that pushes the page into scrolling. Home shows the same
    // three figures, so dropping them here costs the learner nothing.
    final roomForStats =
        MediaQuery.sizeOf(context).height >= _statsMinScreenHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _HeroBand(isPro: true),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: _ActiveMemberCard(entitlement: entitlement),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            "WHAT'S UNLOCKED",
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: _BenefitsCard(),
        ),
        if (roomForStats) ...[
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              'YOUR PROGRESS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: _MemberStats(progress: progress),
          ),
        ],
        // One gap, below the content rather than between the blocks, so
        // spare height on a tall phone collects at the bottom instead of
        // opening a hole in the middle of the page.
        const _FlexGap(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Restore is for somebody who has paid and cannot see it.
              // A current subscriber needs the opposite: the page where
              // the subscription can be changed or cancelled, which both
              // stores require an app to point at.
              SecondaryButton(
                label: 'Manage subscription',
                onPressed: () async {
                  final opened = await ref
                      .read(subscriptionManagerProvider)
                      .openManageSubscriptions(
                        productId: entitlement.productId,
                      );
                  if (!context.mounted || opened) return;
                  AppSnackBar.show(
                    context,
                    'Manage your subscription in your store account settings.',
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Renews automatically. Cancel any time in your store '
                'account settings.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Below this screen height the stats strip is dropped. An iPhone SE is
/// 667pt tall and does not have the room; a Pixel 5a at 830pt does.
const double _statsMinScreenHeight = 700;

/// The learner's own totals, on the screen they land on after paying.
///
/// Lifetime figures, labelled as such — not "since you went Pro".
/// `UserProgress` counts from the first lesson and has no notion of when
/// a subscription started, so a since-purchase framing would be a number
/// the app cannot actually compute.
class _MemberStats extends StatelessWidget {
  final UserProgress progress;
  const _MemberStats({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lessons = progress.totalLessonsCompleted;
    final streak = progress.streakCount;

    // Same glyphs and colours these three carry on Home, so the numbers
    // read as the same numbers rather than a second scoreboard.
    final stats = <AppMetricData>[
      AppMetricData(
        icon: Icons.star_rounded,
        emoji: '⭐',
        color: AppColors.accent,
        label: 'Total XP',
        value: '${progress.totalXp}',
      ),
      AppMetricData(
        icon: Icons.local_fire_department_rounded,
        emoji: '🔥',
        color: AppColors.streak,
        label: 'Day streak',
        value: '$streak',
      ),
      AppMetricData(
        icon: Icons.school_rounded,
        emoji: '📘',
        color: AppColors.success,
        label: lessons == 1 ? 'Lesson' : 'Lessons',
        value: '$lessons',
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          for (final stat in stats)
            Expanded(
              child: AppMetric(data: stat, layout: MetricLayout.column),
            ),
        ],
      ),
    );
  }
}

/// What somebody who has not paid sees.
class _SalesBody extends ConsumerWidget {
  final PurchaseState purchase;
  const _SalesBody({required this.purchase});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _HeroBand(isPro: false),
        const SizedBox(height: AppSpacing.sm),
        // One gap either side of the benefits card, so spare height on a
        // tall phone is shared rather than pooling into a single hole
        // between two blocks.
        const _FlexGap(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: const _BenefitsCard(),
        ),
        const _FlexGap(),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlanSection(state: purchase),
              const SizedBox(height: AppSpacing.md),
              _Cta(state: purchase),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: purchase.isBusy
                    ? null
                    : () => ref.read(purchaseProvider.notifier).restore(),
                child: const Text('Restore Purchases'),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _legalCopy(purchase),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The trial has to be disclosed where it applies, and both stores
  /// require saying what happens when it ends. The sentence is built
  /// from the store's own offer, so it is absent whenever the offer is.
  String _legalCopy(PurchaseState state) {
    const renewal = 'Renews automatically. Cancel any time in your store '
        'account settings.';
    final selected = state.selectedProduct;
    final trial = selected == null ? null : freeTrialOf(selected);
    if (trial == null) return renewal;
    return '${trial.sentence}, then ${recurringPriceOf(selected!).display}. '
        '$renewal';
  }
}

/// Vertical space that gives way first.
///
/// Deliberately [Expanded] around nothing rather than a [Flexible] with
/// a height: a loose Flexible still contributes its child's height to
/// the column's intrinsic height, so it would push the screen into
/// scrolling on a short phone instead of yielding. Contributing zero
/// means the blocks are measured on their own, the leftover room goes to
/// the one gap between them on a tall phone, and on a short one the gap
/// simply vanishes.
class _FlexGap extends StatelessWidget {
  const _FlexGap();

  @override
  Widget build(BuildContext context) =>
      const Expanded(child: SizedBox.shrink());
}

/// The warm band across the top.
///
/// Amber rather than the app's green for one concrete reason: the mascot
/// is green, and a green parrot on a green field disappears. The warm
/// ground also does the job the old centred header was failing at —
/// giving the screen a top edge, so everything below reads as sitting on
/// something instead of floating in the middle of the page.
class _HeroBand extends StatelessWidget {
  final bool isPro;
  const _HeroBand({required this.isPro});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Theme-aware by construction: `tint` resolves to the light amber in
    // a light theme and the dark-theme amber in a dark one, so the band
    // is never a raw literal that only works under one brightness.
    final tint = context.decor.tint(AppColors.accent);

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        MediaQuery.of(context).padding.top + kToolbarHeight - AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint,
            Color.alphaBlend(
              tint.withValues(alpha: 0.35),
              theme.colorScheme.surface,
            ),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.xl),
        ),
      ),
      // Mascot beside the words rather than above them: stacked, the
      // header alone ate a third of a small phone and pushed the prices
      // toward the fold.
      child: Row(
        children: [
          LingoQuestParrot(
            size: 72,
            mood: isPro
                ? LingoQuestParrotMood.celebrate
                : LingoQuestParrotMood.teaching,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'LINGOQUEST PRO',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.8,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  isPro ? 'You have it all' : 'Learn without limits',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The benefits, held together by one card.
///
/// As loose rows they read as three unrelated lines with the screen's
/// spare space collecting around each of them; inside one bordered block
/// they read as a single list of what the money buys.
class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _proBenefits.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.decor.tint(AppColors.primary),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _proBenefits[i].$1,
                    color: AppColors.primary,
                    size: 15,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _proBenefits[i].$2,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
          mainAxisSize: MainAxisSize.min,
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
              onPressed: () =>
                  ref.read(purchaseProvider.notifier).loadProducts(),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < state.products.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _PlanCard(
            product: state.products[i],
            selected: state.products[i].id == state.selectedProduct?.id,
            enabled: !state.isBusy,
            onTap: () => ref
                .read(purchaseProvider.notifier)
                .selectPlan(state.products[i].id),
          ),
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

  /// The plan's name and billing period, derived from the product id
  /// rather than parsed out of the store's localized title — that title
  /// is translated and often carries the app name, so it is display
  /// text, not data.
  (String, String) get _plan => switch (product.id) {
        ProProducts.yearly => ('Yearly', 'per year'),
        ProProducts.monthly => ('Monthly', 'per month'),
        _ => ('Weekly', 'per week'),
      };

  /// The longest period is the best deal per day, so it carries the
  /// badge — and [PurchaseController] sorts by price so it lands on top.
  bool get _isBestValue => product.id == ProProducts.yearly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = selected ? AppColors.primary : theme.colorScheme.outline;
    // Read back from the store's own product, never assumed: see
    // [freeTrialOf].
    final trial = freeTrialOf(product);
    // Not product.price: on Play, a plan carrying a trial reports the
    // trial's own price, which is "Free". See [recurringPriceOf].
    final price = recurringPriceOf(product).display;

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
          border: Border.all(color: accent, width: selected ? 2 : 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.primary : Colors.transparent,
                      border: Border.all(color: accent, width: 2),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // A Wrap, not a Row: the badge is not flexible,
                        // so as a Row sibling it would take its full
                        // width and squeeze the plan name into a
                        // one-character-per-line column. Here it drops
                        // to its own line instead.
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _plan.$1,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (trial != null)
                              _Badge(
                                label: trial.badge,
                                color: AppColors.success,
                                foreground: Colors.white,
                              )
                            else if (_isBestValue)
                              const _Badge(
                                label: 'BEST VALUE',
                                color: AppColors.accent,
                                foreground: Colors.black87,
                              ),
                          ],
                        ),
                        Text(
                          trial == null ? _plan.$2 : 'then $price ${_plan.$2}',
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
                    price,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: selected ? AppColors.primary : null,
                    ),
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

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color foreground;

  const _Badge({
    required this.label,
    required this.color,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 0.3,
              height: 1.2,
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
    final selected = state.selectedProduct;
    final trial = selected == null ? null : freeTrialOf(selected);
    final label = pending
        ? 'Waiting for the store…'
        : trial == null
            ? 'Upgrade to Pro'
            : 'Start my ${trial.label} free';

    return PrimaryButton(
      label: label,
      // Disabled while a sheet is open or a purchase is pending: this is
      // what stops an impatient double tap becoming two transactions.
      isLoading: state.phase == PurchasePhase.working,
      onPressed: state.isBusy || pending || state.products.isEmpty
          ? null
          : () => ref.read(purchaseProvider.notifier).buySelected(),
    );
  }
}

/// The membership card — the answer to "did my payment go through?".
///
/// Everything on it is read back from the stored entitlement. Nothing
/// here is a renewal date or a next-charge amount, because this app has
/// no receipt verification and therefore does not know either; the store
/// does, which is what the manage button is for.
class _ActiveMemberCard extends StatelessWidget {
  final ProEntitlement entitlement;
  const _ActiveMemberCard({required this.entitlement});

  /// Names the plan when the product id was recorded. An entitlement
  /// restored by an older build may not carry one, and inventing a plan
  /// name for it would be worse than saying nothing.
  String get _title {
    final plan = ProProducts.planLabel(entitlement.productId);
    return plan == null ? 'Pro is active' : '$plan Pro — active';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final since = entitlement.purchasedAt;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.decor.tint(AppColors.success),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Every lesson and every game is unlocked.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (since != null) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: AppColors.success.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Member since ${_formatDate(since)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Deliberately not `intl`'s `DateFormat`: the rest of this screen's
/// strings are not localized yet, so a date that alone switched to the
/// device locale would read as an oversight rather than a translation.
String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}
