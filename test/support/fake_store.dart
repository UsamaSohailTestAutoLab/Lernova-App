import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'package:lingoquest/core/services/purchase_service.dart';

/// A Play-shaped catalogue, because Play is where the awkward cases are:
/// a trial reports the plan's price as "Free", and every offer comes back
/// as its own product sharing one id.
///
/// Any test that pumps a screen reading [purchaseServiceProvider] needs
/// one of these. Without it the real plugin is constructed, reaches for
/// the billing channel, and fails the test from an async gap with a
/// `PlatformException(channel-error)` that names no test in particular.
class FakeStore implements PurchaseService {
  final _controller = StreamController<PurchaseUpdate>.broadcast();
  bool monthlyHasTrial;

  /// What this store account currently owns.
  ///
  /// Both real stores replay only *active* entitlements when asked to
  /// restore — iOS through `Transaction.currentEntitlements`, Play
  /// through `queryPurchases` — which is what makes restore usable as
  /// the authority on whether a subscription is still live. A fake that
  /// replayed nothing would make every launch look like an expiry, so
  /// it models the same rule: empty means "this account owns nothing
  /// any more", which is exactly the expired case.
  final Set<String> owned;

  /// Whether the store can be reached at all. False is the offline case,
  /// where nothing may be concluded about the entitlement.
  bool available;

  FakeStore({
    this.monthlyHasTrial = true,
    Set<String> owned = const {},
    this.available = true,
  }) : owned = {...owned};

  @override
  Stream<PurchaseUpdate> get updates => _controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  void listen() {}

  @override
  Future<List<ProductDetails>> loadProducts() async => [
        ...playProduct(ProProducts.yearly, 'P1Y', 30000000, r'$30.00'),
        ...playProduct(
          ProProducts.monthly,
          'P1M',
          12000000,
          r'$12.00',
          trialPeriod: monthlyHasTrial ? 'P3D' : null,
        ),
        ...playProduct(ProProducts.weekly, 'P1W', 2990000, r'$2.99'),
      ];

  @override
  Future<void> buy(ProductDetails product) async {
    owned.add(product.id);
    _controller.add(PurchaseUpdate(
      outcome: PurchaseOutcome.purchased,
      productId: product.id,
      transactionDate: DateTime(2026, 9, 13),
    ));
  }

  @override
  Future<void> restore() async {
    for (final id in owned) {
      _controller.add(PurchaseUpdate(
        outcome: PurchaseOutcome.restored,
        productId: id,
        transactionDate: DateTime(2026, 9, 13),
      ));
    }
  }

  /// Emits an arbitrary update, for the outcomes a test drives directly
  /// (pending, canceled, error).
  void emit(PurchaseUpdate update) => _controller.add(update);

  @override
  void dispose() => _controller.close();
}

/// One Play subscription, fanned out into a base offer plus an optional
/// trial offer — the shape Play actually returns.
List<ProductDetails> playProduct(
  String id,
  String period,
  int micros,
  String formatted, {
  String? trialPeriod,
}) {
  PricingPhaseWrapper phase(String p, int m, String f, RecurrenceMode mode) =>
      PricingPhaseWrapper(
        billingCycleCount: 1,
        billingPeriod: p,
        formattedPrice: f,
        priceAmountMicros: m,
        priceCurrencyCode: 'USD',
        recurrenceMode: mode,
      );

  final base = SubscriptionOfferDetailsWrapper(
    basePlanId: id,
    offerTags: const [],
    offerIdToken: '$id-base',
    pricingPhases: [
      phase(period, micros, formatted, RecurrenceMode.infiniteRecurring),
    ],
  );

  final offers = [base];
  if (trialPeriod != null) {
    offers.add(
      SubscriptionOfferDetailsWrapper(
        basePlanId: id,
        offerId: 'trial',
        offerTags: const [],
        offerIdToken: '$id-trial',
        pricingPhases: [
          phase(trialPeriod, 0, 'Free', RecurrenceMode.finiteRecurring),
          phase(period, micros, formatted, RecurrenceMode.infiniteRecurring),
        ],
      ),
    );
  }

  return GooglePlayProductDetails.fromProductDetails(
    ProductDetailsWrapper(
      description: 'LingoQuest Pro',
      name: 'LingoQuest Pro',
      productId: id,
      productType: ProductType.subs,
      title: 'LingoQuest Pro',
      subscriptionOfferDetails: offers,
    ),
  );
}
