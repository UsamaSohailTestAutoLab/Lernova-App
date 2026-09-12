import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

import 'package:lingoquest/core/services/store_offer.dart';

/// The free trial on the Pro screen is a claim about what the store will
/// do. These tests pin the one rule that matters: the badge appears when
/// — and only when — the store itself reported a free introductory
/// offer. Everything else, including a discounted-but-not-free offer,
/// must read as no trial.
void main() {
  SKProductWrapper skProduct({SKProductDiscountWrapper? intro}) {
    final locale = SKPriceLocaleWrapper(
      currencySymbol: r'$',
      currencyCode: 'USD',
      countryCode: 'US',
    );
    return SKProductWrapper(
      productIdentifier: 'com.monthly.learning',
      localizedTitle: 'LingoQuest Pro',
      localizedDescription: 'Monthly',
      priceLocale: locale,
      price: '12.00',
      subscriptionPeriod: SKProductSubscriptionPeriodWrapper(
        numberOfUnits: 1,
        unit: SKSubscriptionPeriodUnit.month,
      ),
      introductoryPrice: intro,
    );
  }

  SKProductDiscountWrapper discount({
    required SKProductDiscountPaymentMode mode,
    required int numberOfUnits,
    required SKSubscriptionPeriodUnit unit,
    int numberOfPeriods = 1,
    String price = '0.00',
  }) {
    return SKProductDiscountWrapper(
      price: price,
      priceLocale: SKPriceLocaleWrapper(
        currencySymbol: r'$',
        currencyCode: 'USD',
        countryCode: 'US',
      ),
      numberOfPeriods: numberOfPeriods,
      paymentMode: mode,
      subscriptionPeriod: SKProductSubscriptionPeriodWrapper(
        numberOfUnits: numberOfUnits,
        unit: unit,
      ),
      identifier: 'intro',
      type: SKProductDiscountType.introductory,
    );
  }

  ProductDetails playProduct(List<PricingPhaseWrapper> phases) {
    final wrapper = ProductDetailsWrapper(
      description: 'Monthly',
      name: 'LingoQuest Pro',
      productId: 'com.monthly.learning',
      productType: ProductType.subs,
      title: 'LingoQuest Pro',
      subscriptionOfferDetails: [
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'monthly',
          offerId: 'trial',
          offerTags: const [],
          offerIdToken: 'token',
          pricingPhases: phases,
        ),
      ],
    );
    return GooglePlayProductDetails.fromProductDetails(wrapper).single;
  }

  PricingPhaseWrapper phase({
    required String period,
    required int micros,
    required String formatted,
  }) {
    return PricingPhaseWrapper(
      billingCycleCount: 1,
      billingPeriod: period,
      formattedPrice: formatted,
      priceAmountMicros: micros,
      priceCurrencyCode: 'USD',
      recurrenceMode: RecurrenceMode.finiteRecurring,
    );
  }

  group('App Store', () {
    test('reads a three-day free trial from the introductory offer', () {
      final product = AppStoreProductDetails.fromSKProduct(
        skProduct(
          intro: discount(
            mode: SKProductDiscountPaymentMode.freeTrail,
            numberOfUnits: 3,
            unit: SKSubscriptionPeriodUnit.day,
          ),
        ),
      );

      final trial = freeTrialOf(product);
      expect(trial, isNotNull);
      expect(trial!.count, 3);
      expect(trial.unit, TrialUnit.day);
      expect(trial.label, '3 days');
      expect(trial.badge, '3 DAYS FREE');
    });

    test('multiplies the period by how many times it repeats', () {
      // A three-day trial configured as 3 × one day must not read as
      // "1 day free".
      final product = AppStoreProductDetails.fromSKProduct(
        skProduct(
          intro: discount(
            mode: SKProductDiscountPaymentMode.freeTrail,
            numberOfUnits: 1,
            unit: SKSubscriptionPeriodUnit.day,
            numberOfPeriods: 3,
          ),
        ),
      );

      expect(freeTrialOf(product)!.label, '3 days');
    });

    test('a paid introductory price is not a trial', () {
      // "First month for $1" is an offer, not free. Badging it "1 MONTH
      // FREE" would be a lie the store then contradicts at checkout.
      final product = AppStoreProductDetails.fromSKProduct(
        skProduct(
          intro: discount(
            mode: SKProductDiscountPaymentMode.payAsYouGo,
            numberOfUnits: 1,
            unit: SKSubscriptionPeriodUnit.month,
            price: '1.00',
          ),
        ),
      );

      expect(freeTrialOf(product), isNull);
    });

    test('no introductory offer means no trial', () {
      final product = AppStoreProductDetails.fromSKProduct(skProduct());
      expect(freeTrialOf(product), isNull);
    });

    test('singular reads naturally', () {
      final product = AppStoreProductDetails.fromSKProduct(
        skProduct(
          intro: discount(
            mode: SKProductDiscountPaymentMode.freeTrail,
            numberOfUnits: 1,
            unit: SKSubscriptionPeriodUnit.week,
          ),
        ),
      );

      expect(freeTrialOf(product)!.label, '1 week');
    });
  });

  group('Play Store', () {
    test('reads the zero-priced first pricing phase', () {
      final product = playProduct([
        phase(period: 'P3D', micros: 0, formatted: 'Free'),
        phase(period: 'P1M', micros: 12000000, formatted: r'$12.00'),
      ]);

      final trial = freeTrialOf(product);
      expect(trial, isNotNull);
      expect(trial!.count, 3);
      expect(trial.unit, TrialUnit.day);
    });

    test('a plan with no free phase has no trial', () {
      final product = playProduct([
        phase(period: 'P1M', micros: 12000000, formatted: r'$12.00'),
      ]);

      expect(freeTrialOf(product), isNull);
    });

    test('a compound duration is reported as no trial rather than rounded', () {
      final product = playProduct([
        phase(period: 'P1M15D', micros: 0, formatted: 'Free'),
      ]);

      expect(freeTrialOf(product), isNull);
    });

    test('the displayed price still comes from the paid phase', () {
      // The plugin builds the product from the *first* phase, so a free
      // trial phase would show "Free" as the plan price. Confirming what
      // the plugin actually does here, because the card prints it.
      final product = playProduct([
        phase(period: 'P3D', micros: 0, formatted: 'Free'),
        phase(period: 'P1M', micros: 12000000, formatted: r'$12.00'),
      ]);

      expect(product.price, 'Free');
      expect(product.rawPrice, 0);
    });
  });

  group('the price a learner will actually pay', () {
    test('is the recurring phase, not the free trial phase', () {
      // The plugin reports a trial-bearing plan's price as "Free".
      // Printing that where the monthly price belongs would tell the
      // learner the subscription costs nothing.
      final product = playProduct([
        phase(period: 'P3D', micros: 0, formatted: 'Free'),
        phase(period: 'P1M', micros: 12000000, formatted: r'$12.00'),
      ]);

      final price = recurringPriceOf(product);
      expect(price.display, r'$12.00');
      expect(price.raw, 12.0);
    });

    test('is the plan price when there is no trial', () {
      final product = playProduct([
        phase(period: 'P1M', micros: 12000000, formatted: r'$12.00'),
      ]);

      expect(recurringPriceOf(product).display, r'$12.00');
    });

    test('falls back to the plugin price off Play', () {
      final product = AppStoreProductDetails.fromSKProduct(
        skProduct(
          intro: discount(
            mode: SKProductDiscountPaymentMode.freeTrail,
            numberOfUnits: 3,
            unit: SKSubscriptionPeriodUnit.day,
          ),
        ),
      );

      // StoreKit keeps the trial in a separate field, so the product's
      // own price is already the recurring one.
      expect(recurringPriceOf(product).display, r'$12.00');
    });
  });

  group('one card per plan', () {
    test('collapses Play\'s per-offer duplicates, keeping the trial', () {
      // Play returns the base plan and every offer on it as separate
      // products sharing one id — two "Monthly" cards, if rendered raw.
      final wrapper = ProductDetailsWrapper(
        description: 'Monthly',
        name: 'LingoQuest Pro',
        productId: 'com.monthly.learning',
        productType: ProductType.subs,
        title: 'LingoQuest Pro',
        subscriptionOfferDetails: [
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'monthly',
            offerTags: const [],
            offerIdToken: 'base',
            pricingPhases: [
              phase(period: 'P1M', micros: 12000000, formatted: r'$12.00'),
            ],
          ),
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'monthly',
            offerId: 'trial',
            offerTags: const [],
            offerIdToken: 'trial',
            pricingPhases: [
              phase(period: 'P3D', micros: 0, formatted: 'Free'),
              phase(period: 'P1M', micros: 12000000, formatted: r'$12.00'),
            ],
          ),
        ],
      );

      final all = GooglePlayProductDetails.fromProductDetails(wrapper);
      expect(all, hasLength(2), reason: 'the plugin fans offers out');

      final deduped = dedupeByPlan(all);
      expect(deduped, hasLength(1));
      // The trial-bearing offer is the one Play will apply at checkout,
      // so it is the one the card must describe.
      expect(freeTrialOf(deduped.single)?.label, '3 days');
    });

    test('leaves a one-offer-per-id list alone', () {
      final monthly = playProduct([
        phase(period: 'P1M', micros: 12000000, formatted: r'$12.00'),
      ]);

      expect(dedupeByPlan([monthly]), hasLength(1));
    });
  });

  test('a plain ProductDetails from an unknown platform has no trial', () {
    final product = ProductDetails(
      id: 'com.monthly.learning',
      title: 'Pro',
      description: 'Monthly',
      price: r'$12.00',
      rawPrice: 12.0,
      currencyCode: 'USD',
    );

    expect(freeTrialOf(product), isNull);
  });
}
