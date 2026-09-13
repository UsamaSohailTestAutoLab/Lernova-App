import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

/// A free-trial offer, exactly as the store reported it.
///
/// The app never decides that a plan has a trial. App Store Connect and
/// the Play Console do, and they can change it without an app release —
/// so the badge on the plan card is read back out of the product the
/// store returned, the same rule the price already follows. If the
/// introductory offer is removed in the console tomorrow, the badge
/// disappears tomorrow, with no code change and no learner shown a free
/// trial they cannot actually get.
class FreeTrial {
  final int count;
  final TrialUnit unit;

  const FreeTrial({required this.count, required this.unit});

  /// Short enough for a badge: "3 DAYS FREE".
  String get badge => '${label.toUpperCase()} FREE';

  /// "3 days", "1 week", "2 months".
  String get label {
    final noun = switch (unit) {
      TrialUnit.day => 'day',
      TrialUnit.week => 'week',
      TrialUnit.month => 'month',
      TrialUnit.year => 'year',
    };
    return '$count $noun${count == 1 ? '' : 's'}';
  }

  /// "Free for 3 days, then …" — the sentence under the CTA.
  String get sentence => 'Free for $label';

  /// When this trial would end, counting from [start].
  ///
  /// Months and years are added as calendar units rather than a fixed
  /// number of days, so a month-long trial starting on the 31st lands
  /// where a person would expect. Used only to label a member as being
  /// inside a trial; the store, not this arithmetic, decides whether
  /// access continues.
  DateTime endFrom(DateTime start) => switch (unit) {
        TrialUnit.day => start.add(Duration(days: count)),
        TrialUnit.week => start.add(Duration(days: 7 * count)),
        TrialUnit.month =>
          DateTime(start.year, start.month + count, start.day, start.hour, start.minute),
        TrialUnit.year =>
          DateTime(start.year + count, start.month, start.day, start.hour, start.minute),
      };
}

enum TrialUnit { day, week, month, year }

/// Reads a free trial off a store product, whichever store it came from.
///
/// Returns null whenever there is any doubt — no offer configured, a
/// discounted-but-not-free introductory price, an unexpected shape, or a
/// platform this build does not know. A missing badge is a small loss; a
/// badge promising a trial the store will not honour is a refund.
///
/// Eligibility is deliberately not claimed here. Apple only grants an
/// introductory offer once per subscription group, and the plugin does
/// not expose eligibility for StoreKit 1, so the copy says what the plan
/// includes rather than promising this particular learner will get it.
FreeTrial? freeTrialOf(ProductDetails product) {
  if (product is AppStoreProductDetails) {
    return _fromStoreKit(product.skProduct.introductoryPrice);
  }
  if (product is AppStoreProduct2Details) {
    return _fromStoreKit2(product.sk2Product);
  }
  if (product is GooglePlayProductDetails) {
    return _fromPlay(product);
  }
  return null;
}

FreeTrial? _fromStoreKit(SKProductDiscountWrapper? discount) {
  if (discount == null) return null;
  if (discount.paymentMode != SKProductDiscountPaymentMode.freeTrail) {
    return null;
  }
  final period = discount.subscriptionPeriod;
  final unit = switch (period.unit) {
    SKSubscriptionPeriodUnit.day => TrialUnit.day,
    SKSubscriptionPeriodUnit.week => TrialUnit.week,
    SKSubscriptionPeriodUnit.month => TrialUnit.month,
    SKSubscriptionPeriodUnit.year => TrialUnit.year,
  };
  // numberOfPeriods is how many times the period repeats: a 3-day trial
  // can be reported as 3 × 1 day or 1 × 3 days depending on how it was
  // configured, and both must read as three days.
  final count = period.numberOfUnits * discount.numberOfPeriods;
  return count <= 0 ? null : FreeTrial(count: count, unit: unit);
}

FreeTrial? _fromStoreKit2(SK2Product product) {
  final offers = product.subscription?.promotionalOffers;
  if (offers == null) return null;
  for (final offer in offers) {
    if (offer.type != SK2SubscriptionOfferType.introductory) continue;
    if (offer.paymentMode != SK2SubscriptionOfferPaymentMode.freeTrial) {
      continue;
    }
    final unit = switch (offer.period.unit) {
      SK2SubscriptionPeriodUnit.day => TrialUnit.day,
      SK2SubscriptionPeriodUnit.week => TrialUnit.week,
      SK2SubscriptionPeriodUnit.month => TrialUnit.month,
      SK2SubscriptionPeriodUnit.year => TrialUnit.year,
    };
    final count = offer.period.value * offer.periodCount;
    if (count > 0) return FreeTrial(count: count, unit: unit);
  }
  return null;
}

/// Play models a trial as the first pricing phase of an offer costing
/// zero. [GooglePlayProductDetails] is built per base-plan-offer, so
/// [GooglePlayProductDetails.subscriptionIndex] says which one this
/// product is — reading any other offer's phases would describe a plan
/// the learner is not looking at.
FreeTrial? _fromPlay(GooglePlayProductDetails product) {
  final offers = product.productDetails.subscriptionOfferDetails;
  final index = product.subscriptionIndex;
  if (offers == null || index == null || index < 0 || index >= offers.length) {
    return null;
  }
  for (final phase in offers[index].pricingPhases) {
    if (phase.priceAmountMicros != 0) continue;
    return _parseIso8601Period(phase.billingPeriod);
  }
  return null;
}

/// Play reports periods as ISO-8601 durations: `P3D`, `P1W`, `P1M`.
///
/// Only the single-component forms are accepted. A compound duration
/// ("P1M15D") has no honest one-word badge, so it returns null and the
/// card simply shows no trial rather than rounding the offer.
FreeTrial? _parseIso8601Period(String period) {
  final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(period.toUpperCase());
  if (match == null) return null;
  final count = int.tryParse(match.group(1)!) ?? 0;
  if (count <= 0) return null;
  final unit = switch (match.group(2)!) {
    'D' => TrialUnit.day,
    'W' => TrialUnit.week,
    'M' => TrialUnit.month,
    _ => TrialUnit.year,
  };
  return FreeTrial(count: count, unit: unit);
}

/// What the plan costs once any trial ends.
///
/// [ProductDetails.price] is not always that number. Play builds a
/// product from the *first* pricing phase of an offer, so a plan with a
/// free trial reports its price as "Free" and its raw price as zero —
/// which would put "Free" where the monthly price belongs and sort the
/// plan to the bottom of a price-ordered list. The recurring phase is
/// the honest answer, and on the App Store it already is
/// [ProductDetails.price], because StoreKit keeps the introductory offer
/// in a separate field.
({String display, double raw}) recurringPriceOf(ProductDetails product) {
  final fallback = (display: product.price, raw: product.rawPrice);
  if (product is! GooglePlayProductDetails) return fallback;

  final offers = product.productDetails.subscriptionOfferDetails;
  final index = product.subscriptionIndex;
  if (offers == null || index == null || index < 0 || index >= offers.length) {
    return fallback;
  }

  final phases = offers[index].pricingPhases;
  // The plan the learner is signing up for is the one that keeps
  // charging: the last phase, which Play models as infinitely recurring.
  // Falling back to "the last phase that costs something" covers offers
  // configured as a fixed number of cycles.
  for (final phase in phases.reversed) {
    if (phase.recurrenceMode == RecurrenceMode.infiniteRecurring &&
        phase.priceAmountMicros > 0) {
      return (
        display: phase.formattedPrice,
        raw: phase.priceAmountMicros / 1000000.0,
      );
    }
  }
  for (final phase in phases.reversed) {
    if (phase.priceAmountMicros > 0) {
      return (
        display: phase.formattedPrice,
        raw: phase.priceAmountMicros / 1000000.0,
      );
    }
  }
  return fallback;
}

/// Collapses Play's one-product-per-offer list down to one plan per id.
///
/// [GooglePlayProductDetails.fromProductDetails] returns a separate
/// entry for every base plan and every offer on a subscription, all
/// sharing one product id. Rendering them raw would show "Monthly"
/// twice. The offer with a free trial wins, because that is the one the
/// learner gets — Play applies the best eligible offer at checkout — and
/// showing the plainer base plan while the store then grants a trial
/// would undersell it.
///
/// The App Store returns one product per id already, so this is a no-op
/// there.
List<ProductDetails> dedupeByPlan(List<ProductDetails> products) {
  final best = <String, ProductDetails>{};
  for (final product in products) {
    final existing = best[product.id];
    if (existing == null) {
      best[product.id] = product;
      continue;
    }
    final hasTrial = freeTrialOf(product) != null;
    final hadTrial = freeTrialOf(existing) != null;
    if (hasTrial && !hadTrial) best[product.id] = product;
  }
  return best.values.toList();
}
