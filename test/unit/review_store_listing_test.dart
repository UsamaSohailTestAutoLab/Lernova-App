import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';

import 'package:lingoquest/core/services/review_service.dart';

/// Which store "Rate LingoQuest" opens, and whether it opens at all.
///
/// The bug this pins: `openStoreListing` refused unless an App Store id
/// was set — on *both* platforms. Android needs no such id, because the
/// plugin addresses Play by the application id, so the guard blocked the
/// one platform that could always have worked. Settings then fell back
/// to a hard-coded Apple URL, and an Android user tapping "Rate" was
/// sent to the App Store.
class _FakeInAppReview implements InAppReview {
  bool available = true;
  int listingCalls = 0;
  String? lastAppStoreId;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {}

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {
    listingCalls++;
    lastAppStoreId = appStoreId;
  }
}

void main() {
  late _FakeInAppReview plugin;
  late ReviewService service;

  setUp(() {
    plugin = _FakeInAppReview();
    service = ReviewService(inAppReview: plugin);
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('on Android', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('opens Play without needing an App Store id', () async {
      // kAppStoreId is null and must stay irrelevant here: Play is
      // addressed by the application id, which is known at build time.
      expect(kAppStoreId, isNull);

      expect(await service.openStoreListing(), isTrue);
      expect(plugin.listingCalls, 1);
      // Passing Apple's id to Play would be meaningless at best.
      expect(plugin.lastAppStoreId, isNull);
    });
  });

  group('on iOS', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test('reports failure rather than opening a listing that 404s', () async {
      // Apple assigns the id and it cannot be guessed. Until LingoQuest
      // exists in App Store Connect there is nothing to open, and the
      // caller shows a message instead of a dead store page.
      expect(await service.openStoreListing(), isFalse);
      expect(plugin.listingCalls, 0);
    });
  });
}
