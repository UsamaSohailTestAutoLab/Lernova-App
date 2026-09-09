import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// The store product ids Lernova sells.
///
/// These must match the subscription ids configured in App Store Connect
/// and the Google Play Console exactly. Nothing about a plan — its name,
/// its price, its billing period — is defined here beyond the id: the
/// rest comes from the store at runtime, so a price change is a store
/// change and never an app release.
class ProProducts {
  ProProducts._();

  static const weekly = 'com.weekly.learning';
  static const monthly = 'com.monthly.learning';

  static const all = {weekly, monthly};
}

/// What happened to a purchase attempt, in terms the UI can render.
enum PurchaseOutcome {
  /// Bought and verified. Grant Pro.
  purchased,

  /// Re-granted from a previous purchase (Restore, or the store
  /// replaying an existing subscription on a new device).
  restored,

  /// The learner backed out. Not an error — say nothing accusatory.
  canceled,

  /// Taken by the store but not yet complete: awaiting parental
  /// approval, a slow payment method, "ask to buy". Grant nothing yet.
  pending,

  /// The store rejected it. [PurchaseUpdate.message] says why.
  error,
}

/// One resolved purchase event.
class PurchaseUpdate {
  final PurchaseOutcome outcome;
  final String? productId;
  final DateTime? transactionDate;
  final String? message;

  const PurchaseUpdate({
    required this.outcome,
    this.productId,
    this.transactionDate,
    this.message,
  });
}

/// Wraps `in_app_purchase` so the rest of the app never imports it.
///
/// Everything platform-specific lives here: StoreKit on iOS, Play
/// Billing on Android, both behind the one plugin. The controller above
/// it deals in [PurchaseUpdate]s and [ProductDetails], which makes the
/// purchase flow testable against a fake without a store.
class PurchaseService {
  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final _updates = StreamController<PurchaseUpdate>.broadcast();

  PurchaseService({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  /// Resolved purchase events. One per completed transaction.
  Stream<PurchaseUpdate> get updates => _updates.stream;

  Future<bool> isAvailable() => _iap.isAvailable();

  /// Starts listening for purchase updates.
  ///
  /// Must be running before any purchase is started, and should stay
  /// running for the life of the app: the store can deliver a
  /// transaction that completed while the app was closed (a pending
  /// purchase that later cleared, a subscription renewed elsewhere).
  void listen() {
    _subscription ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => _updates.add(
        PurchaseUpdate(outcome: PurchaseOutcome.error, message: e.toString()),
      ),
    );
  }

  /// Live product details from the store — including the localized
  /// price string, which is the only price the app ever displays.
  ///
  /// Returns an empty list when the store is unreachable, so the UI can
  /// say so rather than inventing a price.
  Future<List<ProductDetails>> loadProducts() async {
    if (!await _iap.isAvailable()) return const [];
    final response = await _iap.queryProductDetails(ProProducts.all);
    // notFoundIDs means the ids aren't configured (or not yet live) in
    // the store console. Surfacing them as "no products" is honest;
    // substituting a hardcoded price would not be.
    return response.productDetails;
  }

  /// Opens the platform purchase sheet. The result arrives on [updates].
  Future<void> buy(ProductDetails product) {
    final param = PurchaseParam(productDetails: product);
    // Subscriptions are non-consumable: buying again must not be
    // possible, and the entitlement has to survive a reinstall.
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Asks the store to replay this account's past purchases. Each one
  /// arrives on [updates] as [PurchaseOutcome.restored].
  Future<void> restore() => _iap.restorePurchases();

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _updates.add(PurchaseUpdate(
            outcome: PurchaseOutcome.pending,
            productId: purchase.productID,
          ));
          // Deliberately not completed: it isn't finished yet.
          continue;

        case PurchaseStatus.canceled:
          _updates.add(PurchaseUpdate(
            outcome: PurchaseOutcome.canceled,
            productId: purchase.productID,
          ));

        case PurchaseStatus.error:
          _updates.add(PurchaseUpdate(
            outcome: PurchaseOutcome.error,
            productId: purchase.productID,
            message: purchase.error?.message,
          ));

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _updates.add(PurchaseUpdate(
            outcome: purchase.status == PurchaseStatus.restored
                ? PurchaseOutcome.restored
                : PurchaseOutcome.purchased,
            productId: purchase.productID,
            transactionDate: _dateOf(purchase),
          ));
      }

      // Mandatory on both stores for every finished transaction —
      // skipping it makes the store redeliver the purchase forever, and
      // on iOS it will eventually refund it.
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  static DateTime? _dateOf(PurchaseDetails purchase) {
    final raw = purchase.transactionDate;
    if (raw == null) return null;
    final millis = int.tryParse(raw);
    return millis == null
        ? DateTime.tryParse(raw)
        : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _updates.close();
  }
}
