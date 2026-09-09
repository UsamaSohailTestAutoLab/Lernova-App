import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/services/purchase_service.dart';
import '../../../data/models/pro_entitlement.dart';
import '../../progress/application/progress_controller.dart';

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

  @override
  PurchaseState build() {
    final service = ref.watch(purchaseServiceProvider);
    service.listen();
    _sub = service.updates.listen(_onUpdate);
    ref.onDispose(() => _sub?.cancel());
    // Kicked off here so the screen has prices by the time it paints.
    Future.microtask(loadProducts);
    return const PurchaseState();
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

    final products = await service.loadProducts();
    // Longer billing period first, so "best value" reads top-down.
    products.sort((a, b) => b.rawPrice.compareTo(a.rawPrice));
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
        ref.read(progressProvider.notifier).applyEntitlement(
              ProEntitlement(
                isActive: true,
                productId: update.productId,
                purchasedAt: update.transactionDate ?? DateTime.now(),
                source: restored ? ProSource.restored : ProSource.store,
              ),
            );
        state = state.copyWith(
          phase: PurchasePhase.ready,
          message: restored ? 'Your Pro subscription is back.' : 'Welcome to Pro!',
          isError: false,
        );

      case PurchaseOutcome.pending:
        // Approval or a slow payment method. Nothing is granted until
        // the store says it cleared, which arrives as another update.
        state = state.copyWith(
          phase: PurchasePhase.pending,
          message: 'Your purchase is being processed. '
              "We'll unlock Pro as soon as it clears.",
          isError: false,
        );

      case PurchaseOutcome.canceled:
        // Backing out is not a failure — no error styling.
        state = state.copyWith(phase: PurchasePhase.ready, clearMessage: true);

      case PurchaseOutcome.error:
        state = state.copyWith(
          phase: PurchasePhase.ready,
          message: _friendlyError(update.message),
          isError: true,
        );
    }
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
