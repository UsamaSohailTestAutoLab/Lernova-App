import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lingoquest/core/services/store_links.dart';

/// Which store a build points at.
///
/// Worth its own tests because the failure is silent: an Android build
/// linking the App Store opens a page that loads perfectly and is simply
/// the wrong shop, and nothing in a stack trace ever says so.
void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('the Apple EULA', () {
    test('shows on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(StoreLinks.showsAppleEula, isTrue);
    });

    test('is absent on Android', () {
      // Apple's Licensed Application EULA is a term of *its* distribution
      // agreement. Showing it in a Play build hands an Android user a
      // contract that has nothing to do with how they got the app.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(StoreLinks.showsAppleEula, isFalse);
    });
  });

  group('the developer page', () {
    test('on iOS points at the Apple developer listing', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(StoreLinks.hasDeveloperPage, isTrue);
      expect(StoreLinks.developerPage!.host, 'apps.apple.com');
    });

    test('on Android never points at the App Store', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      // The bug this guards: an Android build sending people to Apple.
      final page = StoreLinks.developerPage;
      expect(page?.host, isNot('apps.apple.com'));
    });

    test('on Android is hidden until the Play publisher name is known',
        () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      // Play's developer page is addressed by publisher name, and a
      // near-miss is a 404 rather than a redirect — so no row at all
      // beats a row that dead-ends inside the store.
      if (StoreLinks.playDeveloperName == null) {
        expect(StoreLinks.hasDeveloperPage, isFalse);
        expect(StoreLinks.developerPage, isNull);
      } else {
        expect(StoreLinks.hasDeveloperPage, isTrue);
        expect(StoreLinks.developerPage!.host, 'play.google.com');
      }
    });
  });

  group('identifiers', () {
    test('the Play id is the application id, known without a store', () {
      expect(StoreLinks.androidPackage, 'com.lernova.lernova');
    });

    test('the App Store id is absent rather than guessed', () {
      // 1888780840 — which an earlier build used here — is the developer
      // id, not an app id. itunes.apple.com/lookup returns
      // wrapperType "artist" for it, and the review link built from it
      // returned "The page you're looking for can't be found".
      expect(StoreLinks.appStoreId, isNull);
      expect(StoreLinks.appleDeveloperUrl, contains('1888780840'));
    });
  });
}
