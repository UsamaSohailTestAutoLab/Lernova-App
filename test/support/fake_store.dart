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

  FakeStore({this.monthlyHasTrial = true});

  @override
  Stream<PurchaseUpdate> get updates => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

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
  Future<void> buy(ProductDetails product) async {}

  @override
  Future<void> restore() async {}

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
