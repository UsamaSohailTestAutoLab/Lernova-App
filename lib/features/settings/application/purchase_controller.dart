import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/services/purchase_service.dart';
import '../../../core/services/subscription_manager.dart';
import '../../../core/services/store_offer.dart';
import '../../../data/models/pro_entitlement.dart';
import '../../progress/application/progress_controller.dart';

/// Opening the store's manage-subscription page. Separate from
/// [PurchaseService] because it is not a purchase — it is a link out,
/// and it has to keep working when billing is unavailable.
final subscriptionManagerProvider =
    Provider<SubscriptionManager>((ref) => SubscriptionManager());

/// How long the store gets to replay entitlements on launch before
/// silence is taken to mean "no longer active".
///
/// A provider rather than a constant so a test can collapse it and
/// assert on the outcome instead of waiting out a real five seconds.
final entitlementVerifyWindowProvider =
    Provider<Duration>((ref) => const Duration(seconds: 5));

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = PurchaseService();
  ref.onDispose(service.dispose);
  return service;
});

/// What the Pro screen is doing right now.
enum PurchasePhase {
  /// Asking the store for products.
  loadingProducts,

  /// Products in hand (or the store said it has none). Idle.
  ready,

  /// A purchase sheet is open, or a restore is running. The CTA must be
  /// disabled — this is what stops a double tap becoming two purchases.
  working,

  /// Taken by the store, not yet cleared. Nothing is granted yet.
  pending,
}

class PurchaseState {
  final PurchasePhase phase;

  /// Live from the store. Empty when the store is unreachable or the
  /// products aren't configured — the UI must then show no price at all
  /// rather than inventing one.
  final List<ProductDetails> products;

  /// Which plan the learner has selected. Null until products load.
  final String? selectedProductId;

  /// A message to show the learner. Cleared once shown.
  final String? message;
  final bool isError;

  /// True when the store itself could not be reached.
  final bool storeUnavailable;

  const PurchaseState({
    this.phase = PurchasePhase.loadingProducts,
    this.products = const [],
    this.selectedProductId,
    this.message,
    this.isError = false,
    this.storeUnavailable = false,
  });

  bool get isBusy =>
      phase == PurchasePhase.working || phase == PurchasePhase.loadingProducts;

  ProductDetails? get selectedProduct {
    for (final p in products) {
      if (p.id == selectedProductId) return p;
    }
    return products.isEmpty ? null : products.first;
  }

  PurchaseState copyWith({
    PurchasePhase? phase,
    List<ProductDetails>? products,
    String? selectedProductId,
    String? message,
    bool clearMessage = false,
    bool? isError,
    bool? storeUnavailable,
  }) {
    return PurchaseState(
      phase: phase ?? this.phase,
      products: products ?? this.products,
      selectedProductId: selectedProductId ?? this.selectedProductId,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
      storeUnavailable: storeUnavailable ?? this.storeUnavailable,
    );
  }
}

/// Drives the Pro screen's purchase flow.
///
/// Holds no billing API of its own — [PurchaseService] owns that — so
/// this can be exercised against a fake store. Every outcome the stores
/// can return is handled explicitly; none of them ever fabricates an
/// entitlement.
class PurchaseController extends Notifier<PurchaseState> {
  StreamSubscription<PurchaseUpdate>? _sub;

  /// True while the launch reconciliation is running.
  ///
  /// It uses the same restore machinery as the button, so without this
  /// every cold start would pop "Your Pro subscription is back."
  bool _verifying = false;

  /// Product ids the store replayed during the current verification.
  final Set<String> _replayed = {};

  /// Completes when the store has answered, the window has run out, or
  /// the controller was disposed — whichever happens first.
  Completer<void>? _verifyDone;
  Timer? _verifyTimer;
  bool _disposed = false;

  @override
  PurchaseState build() {
    final service = ref.watch(purchaseServiceProvider);
    service.listen();
    _sub = service.updates.listen(_onUpdate);
    ref.onDispose(() {
      _disposed = true;
      _sub?.cancel();
      // The verification window is a real timer. Left running it would
      // outlive the provider, and its callback would then write an
      // entitlement through a disposed ref.
      _finishVerifyWait();
    });
    // Kicked off here so the screen has prices by the time it paints.
    Future.microtask(loadProducts);
    Future.microtask(verifyEntitlement);
    return const PurchaseState();
  }

  void _finishVerifyWait() {
    _verifyTimer?.cancel();
    _verifyTimer = null;
    final done = _verifyDone;
    _verifyDone = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  /// Asks the store whether the cached entitlement is still real.
  ///
  /// The cached [ProEntitlement] exists so a member does not watch their
  /// content lock and unlock on every cold start. It is not the
  /// authority — the store is — and this is what keeps the two honest:
  ///
  /// * **iOS** — with StoreKit 2 (the plugin's default), restoring maps
  ///   to `Transaction.currentEntitlements`, which yields *only* what is
  ///   currently active. An expired or refunded subscription simply does
  ///   not come back. It shows no password prompt, which is what makes
  ///   it safe to run unattended on every launch.
  /// * **Android** — `queryPurchases` likewise returns only purchases
  ///   that are currently owned.
  ///
  /// Three rules keep this from ever wrongly removing access:
  ///
  /// 1. It runs only when something is cached as active. There is
  ///    nothing to verify otherwise, and a silent restore for a free
  ///    learner would be a pointless store round-trip.
  /// 2. If the store cannot be reached, it does nothing. "I could not
  ///    ask" is not "the answer is no", and treating an offline launch
  ///    as an expiry would lock a paying member out on a plane.
  /// 3. A developer entitlement is left alone, since no store will ever
  ///    replay it.
  Future<void> verifyEntitlement() async {
    final cached = ref.read(progressProvider).proEntitlement;
    if (!cached.isActive) return;
    if (cached.source == ProSource.debug) return;

    final service = ref.read(purchaseServiceProvider);
    if (!await service.isAvailable()) return;

    _verifying = true;
    _replayed.clear();
    try {
      final done = Completer<void>();
      _verifyDone = done;
      // The store answers asynchronously on the purchase stream. The
      // wait ends as soon as it replays one of our products — usually
      // well inside the window — and the window is only the ceiling on
      // how long silence is given before it counts as an answer.
      _verifyTimer = Timer(
        ref.read(entitlementVerifyWindowProvider),
        _finishVerifyWait,
      );

      await service.restore();
      await done.future;
      if (_disposed) return;

      final stillOwned = _replayed.any(ProProducts.all.contains);
      final notifier = ref.read(progressProvider.notifier);
      if (stillOwned) {
        notifier.applyEntitlement(
          cached.copyWith(lastVerifiedAt: DateTime.now()),
        );
      } else {
        // The store knows this account and did not replay the
        // subscription: it has lapsed. Access closes on the next build,
        // with nothing to migrate — every gate reads this entitlement.
        notifier.applyEntitlement(cached.expire());
      }
    } catch (_) {
      // Reaching the store failed after all. Keep the cache; rule 2.
    } finally {
      _finishVerifyWait();
      _verifying = false;
      _replayed.clear();
    }
  }



  Future<void> loadProducts() async {
    final service = ref.read(purchaseServiceProvider);
    final available = await service.isAvailable();
    if (!available) {
      state = state.copyWith(
        phase: PurchasePhase.ready,
        products: const [],
        storeUnavailable: true,
      );
      return;
    }

    // Play answers with one entry per base plan *and* per offer, all
    // sharing a product id, so the list is collapsed to one card per
    // plan before anything renders.
    final products = dedupeByPlan(await service.loadProducts());
    // Longer billing period first, so "best value" reads top-down.
    // Sorted on the recurring price, not rawPrice: a plan with a free
    // trial reports a raw price of zero on Play and would otherwise
    // sort to the bottom.
    products.sort(
      (a, b) => recurringPriceOf(b).raw.compareTo(recurringPriceOf(a).raw),
    );
    state = state.copyWith(
      phase: PurchasePhase.ready,
      products: products,
      storeUnavailable: false,
      selectedProductId: state.selectedProductId ??
          (products.isEmpty ? null : products.first.id),
    );
  }

  void selectPlan(String productId) {
    if (state.isBusy) return;
    state = state.copyWith(selectedProductId: productId, clearMessage: true);
  }

  /// Opens the store's purchase sheet for the selected plan.
  ///
  /// Refuses when a purchase is already in flight (the double-tap guard)
  /// and when Pro is already active — re-buying an active subscription
  /// is a support ticket waiting to happen, and both stores would
  /// reject or duplicate it.
  Future<void> buySelected() async {
    if (state.isBusy) return;
    if (ref.read(progressProvider).isPremium) {
      state = state.copyWith(
        message: "You're already a Pro member.",
        isError: false,
      );
      return;
    }
    final product = state.selectedProduct;
    if (product == null) {
      state = state.copyWith(
        message: 'Plans are unavailable right now — check your connection.',
        isError: true,
      );
      return;
    }

    state = state.copyWith(phase: PurchasePhase.working, clearMessage: true);
    try {
      await ref.read(purchaseServiceProvider).buy(product);
    } catch (e) {
      state = state.copyWith(
        phase: PurchasePhase.ready,
        message: "That didn't go through. Please try again.",
        isError: true,
      );
    }
  }

  Future<void> restore() async {
    if (state.isBusy) return;
    state = state.copyWith(phase: PurchasePhase.working, clearMessage: true);
    try {
      await ref.read(purchaseServiceProvider).restore();
      // The store answers on the purchase stream. If it replays nothing,
      // there was nothing to restore — say so rather than hanging.
      await Future<void>.delayed(const Duration(seconds: 3));
      if (state.phase == PurchasePhase.working) {
        state = state.copyWith(
          phase: PurchasePhase.ready,
          message: ref.read(progressProvider).isPremium
              ? 'Your Pro subscription is active.'
              : 'No previous purchase found for this store account.',
          isError: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        phase: PurchasePhase.ready,
        message: "Couldn't reach the store. Please try again.",
        isError: true,
      );
    }
  }

  void clearMessage() => state = state.copyWith(clearMessage: true);

  void _onUpdate(PurchaseUpdate update) {
    switch (update.outcome) {
      case PurchaseOutcome.purchased:
      case PurchaseOutcome.restored:
        final restored = update.outcome == PurchaseOutcome.restored;
        final id = update.productId;
        if (id != null) {
          _replayed.add(id);
          // Confirmed — no reason to hold the window open.
          if (_verifying && ProProducts.all.contains(id)) _finishVerifyWait();
        }

        ref.read(progressProvider.notifier).applyEntitlement(
              _entitlementFor(update, restored: restored),
            );
        // A launch check is not something the learner asked for, so it
        // reports nothing and leaves the screen's phase alone.
        if (_verifying) return;
        state = state.copyWith(
          phase: PurchasePhase.ready,
          message: restored ? 'Your Pro subscription is back.' : 'Welcome to Pro!',
          isError: false,
        );

      case PurchaseOutcome.pending:
        if (_verifying) return;
        // Approval or a slow payment method. Nothing is granted until
        // the store says it cleared, which arrives as another update.
        state = state.copyWith(
          phase: PurchasePhase.pending,
          message: 'Your purchase is being processed. '
              "We'll unlock Pro as soon as it clears.",
          isError: false,
        );

      case PurchaseOutcome.canceled:
        if (_verifying) return;
        // Backing out is not a failure — no error styling.
        state = state.copyWith(phase: PurchasePhase.ready, clearMessage: true);

      case PurchaseOutcome.error:
        if (_verifying) return;
        state = state.copyWith(
          phase: PurchasePhase.ready,
          message: _friendlyError(update.message),
          isError: true,
        );
    }
  }

  /// Builds the entitlement to record for a completed transaction.
  ///
  /// The only judgement here is trial-versus-paid, and it is a
  /// judgement: neither store reports, through `in_app_purchase`,
  /// whether a given transaction consumed an introductory offer. What is
  /// known is the offer the store advertised for that product when the
  /// catalogue was loaded, and when the transaction happened — so a
  /// purchase of a product carrying a free trial is recorded as
  /// [EntitlementStatus.trialActive] until that trial's length is up.
  ///
  /// This is safe precisely because nothing gates on it: trial and paid
  /// grant identical access (see [EntitlementStatus.grantsAccess]), so a
  /// wrong guess mislabels a row in Settings and never opens or closes a
  /// lesson. Whether access continues at all stays the store's call,
  /// answered by [verifyEntitlement].
  ProEntitlement _entitlementFor(
    PurchaseUpdate update, {
    required bool restored,
  }) {
    final boughtAt = update.transactionDate ?? DateTime.now();
    final product = _productById(update.productId);
    final trial = product == null ? null : freeTrialOf(product);
    final trialEnd = trial?.endFrom(boughtAt);
    final inTrial = trialEnd != null && trialEnd.isAfter(DateTime.now());

    return ProEntitlement(
      status: inTrial
          ? EntitlementStatus.trialActive
          : EntitlementStatus.subscribedActive,
      productId: update.productId,
      purchasedAt: boughtAt,
      source: restored ? ProSource.restored : ProSource.store,
      trialEndsAt: inTrial ? trialEnd : null,
      lastVerifiedAt: DateTime.now(),
    );
  }

  ProductDetails? _productById(String? id) {
    if (id == null) return null;
    for (final p in state.products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Store errors are written for developers. Learners get something
  /// they can act on instead.
  static String _friendlyError(String? raw) {
    final text = (raw ?? '').toLowerCase();
    if (text.contains('network') || text.contains('connect')) {
      return "Couldn't reach the store. Check your connection and try again.";
    }
    if (text.contains('already') || text.contains('owned')) {
      return 'You already own this. Try Restore Purchases.';
    }
    return "That purchase didn't go through. You have not been charged.";
  }
}

final purchaseProvider =
    NotifierProvider<PurchaseController, PurchaseState>(PurchaseController.new);
