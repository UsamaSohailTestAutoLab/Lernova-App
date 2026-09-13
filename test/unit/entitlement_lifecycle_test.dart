import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/purchase_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/data/models/pro_entitlement.dart';
import 'package:lingoquest/data/models/user_progress.dart';
import 'package:lingoquest/features/progress/application/progress_controller.dart';
import 'package:lingoquest/features/settings/application/purchase_controller.dart';

/// The entitlement's whole life: what each state grants, what an older
/// record migrates to, and — the part with teeth — what happens on
/// launch when the store is asked whether the cached subscription is
/// still real.
class _Store implements PurchaseService {
  final _controller = StreamController<PurchaseUpdate>.broadcast();

  /// What this store account currently owns. Both platforms replay only
  /// live entitlements on restore, so an empty set is the expired case.
  Set<String> owned;
  bool available;
  bool restoreThrows;
  int restoreCalls = 0;

  _Store({
    this.owned = const {},
    this.available = true,
    this.restoreThrows = false,
  });

  @override
  Stream<PurchaseUpdate> get updates => _controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  void listen() {}

  @override
  Future<List<ProductDetails>> loadProducts() async => const [];

  @override
  Future<void> buy(ProductDetails product) async {}

  @override
  Future<void> restore() async {
    restoreCalls++;
    if (restoreThrows) throw Exception('store unreachable');
    for (final id in owned) {
      _controller.add(PurchaseUpdate(
        outcome: PurchaseOutcome.restored,
        productId: id,
        transactionDate: DateTime(2026, 9, 1),
      ));
    }
  }

  @override
  void dispose() => _controller.close();
}

UserProgress _progressWith(ProEntitlement entitlement) =>
    UserProgress.initial(weekId: '2026-W37').copyWith(
      isPremium: entitlement.isActive,
      proEntitlement: entitlement,
    );

void main() {
  group('what each state grants', () {
    test('only trial and paid open anything', () {
      expect(EntitlementStatus.notSubscribed.grantsAccess, isFalse);
      expect(EntitlementStatus.trialActive.grantsAccess, isTrue);
      expect(EntitlementStatus.subscribedActive.grantsAccess, isTrue);
      expect(EntitlementStatus.expired.grantsAccess, isFalse);
    });

    test('a trial is a premium member, not a half-member', () {
      // The acceptance criterion this exists for: an active trial has to
      // be indistinguishable from a paid subscription everywhere access
      // is decided.
      const trial = ProEntitlement(status: EntitlementStatus.trialActive);
      const paid = ProEntitlement(status: EntitlementStatus.subscribedActive);

      expect(trial.isActive, paid.isActive);
      expect(trial.isActive, isTrue);
      expect(trial.isTrial, isTrue);
      expect(paid.isTrial, isFalse);
    });
  });

  group('reading a stored entitlement', () {
    test('round-trips every field', () {
      final original = ProEntitlement(
        status: EntitlementStatus.trialActive,
        productId: ProProducts.monthly,
        purchasedAt: DateTime(2026, 9, 1, 10, 30),
        source: ProSource.store,
        trialEndsAt: DateTime(2026, 9, 4, 10, 30),
        lastVerifiedAt: DateTime(2026, 9, 2),
      );

      final back = ProEntitlement.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(back.status, original.status);
      expect(back.productId, original.productId);
      expect(back.purchasedAt, original.purchasedAt);
      expect(back.source, original.source);
      expect(back.trialEndsAt, original.trialEndsAt);
      expect(back.lastVerifiedAt, original.lastVerifiedAt);
    });

    test('a record from the isActive-bool era still grants access', () {
      // Written by a build that predates the status enum. Reading it as
      // "not subscribed" would silently revoke a paying member.
      final old = ProEntitlement.fromJson({
        'isActive': true,
        'productId': ProProducts.yearly,
        'source': 'store',
      });

      expect(old.status, EntitlementStatus.subscribedActive);
      expect(old.isActive, isTrue);
      // Under-claiming the trial is the safe direction for a guess.
      expect(old.isTrial, isFalse);
    });

    test('an inactive old record stays inactive', () {
      final old = ProEntitlement.fromJson({'isActive': false});
      expect(old.status, EntitlementStatus.notSubscribed);
      expect(old.isActive, isFalse);
    });

    test('a record with nothing in it is nobody', () {
      expect(ProEntitlement.fromJson(const {}).isActive, isFalse);
    });
  });

  group('expiring', () {
    test('drops access but keeps what was bought', () {
      final live = ProEntitlement(
        status: EntitlementStatus.trialActive,
        productId: ProProducts.monthly,
        purchasedAt: DateTime(2026, 9, 1),
        source: ProSource.store,
        trialEndsAt: DateTime(2026, 9, 4),
      );

      final dead = live.expire(at: DateTime(2026, 9, 5));

      expect(dead.isActive, isFalse);
      expect(dead.status, EntitlementStatus.expired);
      // "Your Monthly plan ended" is more use than "you have nothing".
      expect(dead.productId, ProProducts.monthly);
      expect(dead.purchasedAt, DateTime(2026, 9, 1));
      // The trial is over; keeping its end date would keep labelling
      // them as being in one.
      expect(dead.trialEndsAt, isNull);
      expect(dead.lastVerifiedAt, DateTime(2026, 9, 5));
    });
  });

  group('asking the store on launch', () {
    late ProviderContainer container;

    Future<void> boot(
      _Store store, {
      required ProEntitlement cached,
    }) async {
      SharedPreferences.setMockInitialValues({
        'lernova.active_account_id': 'local',
        'lernova.progress.local': jsonEncode(_progressWith(cached).toJson()),
      });
      SharedPreferences.resetStatic();
      final storage = await LocalStorageService.create();

      container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          purchaseServiceProvider.overrideWithValue(store),
          // The real window is five seconds of waiting for the store.
          entitlementVerifyWindowProvider.overrideWithValue(Duration.zero),
        ],
      );
      addTearDown(container.dispose);

      // build() starts both the product load and the verification.
      container.read(purchaseProvider);
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    ProEntitlement result() =>
        container.read(progressProvider).proEntitlement;

    const live = ProEntitlement(
      status: EntitlementStatus.subscribedActive,
      productId: ProProducts.monthly,
      source: ProSource.store,
    );

    test('a subscription the store still owns is confirmed', () async {
      await boot(
        _Store(owned: {ProProducts.monthly}),
        cached: live,
      );

      expect(result().isActive, isTrue);
      expect(result().status, EntitlementStatus.subscribedActive);
      // Confirmed, and stamped so it is visible that it was.
      expect(result().lastVerifiedAt, isNotNull);
    });

    test('a subscription the store no longer replays is expired', () async {
      // The store knows the account and did not hand the subscription
      // back: on iOS that is currentEntitlements omitting it, on Play
      // queryPurchases omitting it. Either way it has lapsed.
      await boot(_Store(owned: const {}), cached: live);

      expect(result().isActive, isFalse);
      expect(result().status, EntitlementStatus.expired);
    });

    test('an unreachable store changes nothing', () async {
      // "I could not ask" is not "the answer is no". Treating an offline
      // launch as an expiry would lock a paying member out on a plane.
      final store = _Store(owned: const {}, available: false);
      await boot(store, cached: live);

      expect(result().isActive, isTrue);
      expect(store.restoreCalls, 0);
    });

    test('a store that throws mid-restore changes nothing', () async {
      await boot(
        _Store(owned: const {}, restoreThrows: true),
        cached: live,
      );

      expect(result().isActive, isTrue);
    });

    test('a developer entitlement is left alone', () async {
      // No store will ever replay it, so verifying it would revoke it on
      // the next launch and make the debug switch useless.
      const debug = ProEntitlement(
        status: EntitlementStatus.subscribedActive,
        source: ProSource.debug,
      );
      final store = _Store(owned: const {});
      await boot(store, cached: debug);

      expect(result().isActive, isTrue);
      expect(store.restoreCalls, 0);
    });

    test('a free learner is not made to wait on the store', () async {
      final store = _Store(owned: const {});
      await boot(store, cached: ProEntitlement.none);

      expect(result().isActive, isFalse);
      expect(store.restoreCalls, 0);
    });

    test('an already-expired entitlement is not re-checked', () async {
      final store = _Store(owned: const {});
      await boot(store, cached: live.expire());

      expect(result().status, EntitlementStatus.expired);
      expect(store.restoreCalls, 0);
    });

    test('the launch check says nothing to the learner', () async {
      // It runs on every cold start. Announcing "Your Pro subscription
      // is back" each time would be noise for something nobody asked
      // for.
      await boot(_Store(owned: {ProProducts.monthly}), cached: live);

      expect(container.read(purchaseProvider).message, isNull);
    });

    test('an expired subscription can be bought again', () async {
      // Expiry must not be a dead end: the paywall has to come back, and
      // the guard that stops an active member re-buying must not still
      // be holding.
      await boot(_Store(owned: const {}), cached: live);

      expect(container.read(progressProvider).isPremium, isFalse);
      await container.read(purchaseProvider.notifier).buySelected();
      // No products in this fake catalogue, so it reports that rather
      // than "you're already a Pro member".
      expect(
        container.read(purchaseProvider).message,
        isNot(contains('already')),
      );
    });
  });
}
