import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lingoquest/core/services/purchase_service.dart';
import 'package:lingoquest/core/services/subscription_manager.dart';

void main() {
  Uri? launched;
  LaunchMode? launchedMode;
  var launchSucceeds = true;
  var launchThrows = false;

  Future<bool> fakeLaunch(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
    if (launchThrows) throw Exception('no browser');
    launched = uri;
    launchedMode = mode;
    return launchSucceeds;
  }

  SubscriptionManager manager(String platform) => SubscriptionManager(
        launch: fakeLaunch,
        platformOverride: platform,
      );

  setUp(() {
    launched = null;
    launchedMode = null;
    launchSucceeds = true;
    launchThrows = false;
  });

  group('the page each store expects', () {
    test('iOS goes to the account-wide subscriptions page', () {
      final url = manager('ios').manageUrl(productId: ProProducts.monthly);

      expect(url.toString(), 'https://apps.apple.com/account/subscriptions');
    });

    test('iOS ignores the product id, because Apple has one page', () {
      expect(
        manager('ios').manageUrl(productId: null).toString(),
        manager('ios').manageUrl(productId: ProProducts.yearly).toString(),
      );
    });

    test('Play opens the specific subscription when the product is known', () {
      final url = manager('android').manageUrl(productId: ProProducts.yearly)!;

      expect(url.host, 'play.google.com');
      expect(url.path, '/store/account/subscriptions');
      expect(url.queryParameters['sku'], ProProducts.yearly);
      expect(
        url.queryParameters['package'],
        SubscriptionManager.androidPackage,
      );
    });

    test('Play falls back to the account list without a product id', () {
      // An entitlement restored by an older build may not carry one.
      final url = manager('android').manageUrl()!;

      expect(url.toString(),
          'https://play.google.com/store/account/subscriptions');
      expect(url.queryParameters, isEmpty);
    });

    test('anywhere else there is no page to open', () {
      expect(manager('other').manageUrl(productId: ProProducts.monthly), isNull);
    });
  });

  group('opening it', () {
    test('launches externally so the store app can take over', () async {
      final opened = await manager('ios').openManageSubscriptions();

      expect(opened, isTrue);
      expect(launched.toString(), 'https://apps.apple.com/account/subscriptions');
      expect(launchedMode, LaunchMode.externalApplication);
    });

    test('reports false on a platform with nowhere to go', () async {
      expect(await manager('other').openManageSubscriptions(), isFalse);
      expect(launched, isNull);
    });

    test('reports false rather than throwing when the launcher fails', () async {
      launchThrows = true;

      // A device with no browser must not crash the settings screen.
      expect(await manager('android').openManageSubscriptions(), isFalse);
    });

    test('passes a refusal from the launcher straight through', () async {
      launchSucceeds = false;

      expect(await manager('ios').openManageSubscriptions(), isFalse);
    });
  });

  group('naming the plan a subscriber is on', () {
    test('reads the plan from the product id', () {
      expect(ProProducts.planLabel(ProProducts.weekly), 'Weekly');
      expect(ProProducts.planLabel(ProProducts.monthly), 'Monthly');
      expect(ProProducts.planLabel(ProProducts.yearly), 'Yearly');
    });

    test('says nothing rather than guessing for an unknown product', () {
      // Better "Active" than a plan name the learner is not paying for.
      expect(ProProducts.planLabel(null), isNull);
      expect(ProProducts.planLabel('com.something.else'), isNull);
    });
  });
}
