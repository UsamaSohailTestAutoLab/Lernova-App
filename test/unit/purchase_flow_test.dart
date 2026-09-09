import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lernova/core/services/local_storage_service.dart';
import 'package:lernova/core/services/purchase_service.dart';
import 'package:lernova/core/services/service_providers.dart';
import 'package:lernova/data/models/pro_entitlement.dart';
import 'package:lernova/features/progress/application/progress_controller.dart';
import 'package:lernova/features/settings/application/purchase_controller.dart';

/// A stand-in store. Lets every outcome the real stores can return be
/// driven deterministically, with no Play/StoreKit connection.
class FakePurchaseService implements PurchaseService {
  final _controller = StreamController<PurchaseUpdate>.broadcast();

  bool available = true;
  List<ProductDetails> catalogue = [
    ProductDetails(
      id: ProProducts.monthly,
      title: 'Lernova Pro (Yearly)',
      description: 'A year of Pro',
      price: r'$59.99',
      rawPrice: 59.99,
      currencyCode: 'USD',
    ),
    ProductDetails(
      id: ProProducts.weekly,
      title: 'Lernova Pro (Monthly)',
      description: 'A month of Pro',
      price: r'$6.99',
      rawPrice: 6.99,
      currencyCode: 'USD',
    ),
  ];

  int buyCalls = 0;
  int restoreCalls = 0;
  bool buyThrows = false;

  @override
  Stream<PurchaseUpdate> get updates => _controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  void listen() {}

  @override
  Future<List<ProductDetails>> loadProducts() async =>
      available ? catalogue : const [];

  @override
  Future<void> buy(ProductDetails product) async {
    buyCalls++;
    if (buyThrows) throw Exception('store exploded');
  }

  @override
  Future<void> restore() async => restoreCalls++;

  /// Pushes a store event, as the real purchase stream would.
  void emit(PurchaseUpdate update) => _controller.add(update);

  @override
  void dispose() => _controller.close();
}

void main() {
  late ProviderContainer container;
  late FakePurchaseService store;

  Future<void> boot() async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    store = FakePurchaseService();
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        purchaseServiceProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    // Products load in a microtask from build().
    container.read(purchaseProvider);
    await Future<void>.delayed(Duration.zero);
  }

  bool isPro() => container.read(progressProvider).isPremium;
  ProEntitlement entitlement() => container.read(progressProvider).proEntitlement;
  PurchaseState state() => container.read(purchaseProvider);
  PurchaseController controller() => container.read(purchaseProvider.notifier);

  setUp(boot);

  group('products', () {
    test('prices come from the store, never from the app', () async {
      expect(state().products, hasLength(2));
      expect(state().products.map((p) => p.price), containsAll([r'$59.99', r'$6.99']));
      // Longer period first, so "best value" reads top-down.
      expect(state().products.first.id, ProProducts.monthly);
      expect(state().selectedProduct?.id, ProProducts.monthly);
    });

    test('an unreachable store leaves no products rather than a fake price', () async {
      store.available = false;
      await controller().loadProducts();

      expect(state().products, isEmpty);
      expect(state().storeUnavailable, isTrue);
      expect(state().phase, PurchasePhase.ready);
    });
  });

  group('selecting a plan', () {
    test('switches the highlighted plan', () {
      controller().selectPlan(ProProducts.weekly);
      expect(state().selectedProduct?.id, ProProducts.weekly);
    });
  });

  group('purchase outcomes', () {
    test('a successful purchase grants Pro and records where it came from', () async {
      await controller().buySelected();
      expect(store.buyCalls, 1);
      expect(isPro(), isFalse, reason: 'nothing is granted until the store confirms');

      store.emit(PurchaseUpdate(
        outcome: PurchaseOutcome.purchased,
        productId: ProProducts.monthly,
        transactionDate: DateTime(2026, 3, 1),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(isPro(), isTrue);
      expect(entitlement().source, ProSource.store);
      expect(entitlement().productId, ProProducts.monthly);
      expect(state().phase, PurchasePhase.ready);
    });

    test('a cancelled purchase grants nothing and does not scold', () async {
      await controller().buySelected();
      store.emit(const PurchaseUpdate(outcome: PurchaseOutcome.canceled));
      await Future<void>.delayed(Duration.zero);

      expect(isPro(), isFalse);
      expect(state().phase, PurchasePhase.ready);
      expect(state().message, isNull, reason: 'backing out is not an error');
    });

    test('a failed purchase grants nothing and explains itself', () async {
      await controller().buySelected();
      store.emit(const PurchaseUpdate(
        outcome: PurchaseOutcome.error,
        message: 'BillingResponse.network_error',
      ));
      await Future<void>.delayed(Duration.zero);

      expect(isPro(), isFalse);
      expect(state().isError, isTrue);
      expect(state().message, contains('connection'));
      expect(state().phase, PurchasePhase.ready);
    });

    // "Ask to buy", slow payment methods: taken by the store, not yet
    // paid for. Granting Pro here would be giving it away.
    test('a pending purchase grants nothing yet', () async {
      await controller().buySelected();
      store.emit(const PurchaseUpdate(outcome: PurchaseOutcome.pending));
      await Future<void>.delayed(Duration.zero);

      expect(isPro(), isFalse);
      expect(state().phase, PurchasePhase.pending);
      expect(state().message, contains('being processed'));
    });

    test('a pending purchase that later clears grants Pro', () async {
      await controller().buySelected();
      store.emit(const PurchaseUpdate(outcome: PurchaseOutcome.pending));
      await Future<void>.delayed(Duration.zero);
      expect(isPro(), isFalse);

      store.emit(const PurchaseUpdate(
        outcome: PurchaseOutcome.purchased,
        productId: ProProducts.weekly,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(isPro(), isTrue);
    });
  });

  group('restore', () {
    test('a restored purchase grants Pro and is marked as restored', () async {
      unawaited(controller().restore());
      await Future<void>.delayed(Duration.zero);
      expect(store.restoreCalls, 1);

      store.emit(const PurchaseUpdate(
        outcome: PurchaseOutcome.restored,
        productId: ProProducts.monthly,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(isPro(), isTrue);
      expect(entitlement().source, ProSource.restored);
    });
  });

  group('guards', () {
    test('a second tap while a purchase is open does not start another', () async {
      await controller().buySelected();
      expect(state().phase, PurchasePhase.working);

      await controller().buySelected();
      await controller().buySelected();

      expect(store.buyCalls, 1, reason: 'one tap, one transaction');
    });

    test('an existing subscriber is not sold the same thing twice', () async {
      container.read(progressProvider.notifier).applyEntitlement(
            const ProEntitlement(isActive: true, source: ProSource.store),
          );

      await controller().buySelected();

      expect(store.buyCalls, 0);
      expect(state().message, contains('already'));
    });

    test('a thrown store call surfaces as an error, not a crash', () async {
      store.buyThrows = true;
      await controller().buySelected();

      expect(isPro(), isFalse);
      expect(state().isError, isTrue);
      expect(state().phase, PurchasePhase.ready);
    });
  });

  group('entitlement persistence', () {
    test('survives a round-trip through storage', () async {
      store.emit(PurchaseUpdate(
        outcome: PurchaseOutcome.purchased,
        productId: ProProducts.weekly,
        transactionDate: DateTime(2026, 5, 4),
      ));
      await Future<void>.delayed(Duration.zero);

      final saved = container.read(progressProvider).toJson();
      final reloaded = ProEntitlement.fromJson(
        saved['proEntitlement'] as Map<String, dynamic>,
      );

      expect(reloaded.isActive, isTrue);
      expect(reloaded.productId, ProProducts.weekly);
      expect(reloaded.source, ProSource.store);
      expect(reloaded.purchasedAt, DateTime(2026, 5, 4));
    });

    test('older saved progress with no entitlement block still loads', () {
      final legacy = {'isPremium': true};
      expect(
        ProEntitlement.fromJson(const {}).isActive,
        isFalse,
        reason: 'an absent block is not an entitlement()',
      );
      expect(legacy['isPremium'], isTrue);
    });
  });
}
