import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/purchase_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/core/theme/app_theme.dart';
import 'package:lingoquest/data/models/app_user.dart';
import 'package:lingoquest/data/models/pro_entitlement.dart';
import 'package:lingoquest/data/models/user_progress.dart';
import 'package:lingoquest/features/settings/application/purchase_controller.dart';
import 'package:lingoquest/features/settings/presentation/premium_screen.dart';
import 'package:lingoquest/features/settings/presentation/settings_screen.dart';

import '../support/fake_store.dart';

/// Renders the Pro surfaces in both states, so "what does a subscriber
/// actually see?" is answerable by looking rather than by reading the
/// widget tree.
///
/// Deliberately named without the `_test` suffix so `flutter test` does
/// not pick it up. Golden output shifts with the Flutter version and the
/// host's font rasterizer, and these exist to be looked at rather than
/// to fail a build on a one-pixel difference. Run them by path:
///
///     flutter test test/widget/pro_screen_golden.dart
///     flutter test test/widget/pro_screen_golden.dart --update-goldens
///
/// The behaviour they illustrate is pinned properly, and platform-
/// independently, in `pro_member_state_test.dart` and
/// `premium_screen_test.dart`.
Future<void> _loadRealFonts() async {
  for (final family in const {
    'Inter': 'assets/fonts/Inter.ttf',
    'Baloo 2': 'assets/fonts/Baloo2.ttf',
  }.entries) {
    final loader = FontLoader(family.key)..addFont(rootBundle.load(family.value));
    await loader.load();
  }
}

UserProgress _progress({required bool pro, String? productId}) {
  final base = UserProgress.initial(weekId: '2026-W37').copyWith(
    totalXp: 4860,
    streakCount: 24,
    totalLessonsCompleted: 7,
  );
  if (!pro) return base;
  return base.copyWith(
    isPremium: true,
    proEntitlement: ProEntitlement(
      status: EntitlementStatus.subscribedActive,
      productId: productId,
      purchasedAt: DateTime(2026, 9, 1),
      source: ProSource.store,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required bool pro,
  String? productId,
}) async {
  tester.view.physicalSize = const Size(1320, 2868);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final user = AppUser(
    id: 'local',
    name: 'Maya',
    email: '',
    avatarSeed: 'Maya',
    joinedAt: DateTime(2026, 1, 1),
    selectedLanguageId: 'es',
    currentCourseId: 'course_es',
  );

  SharedPreferences.setMockInitialValues({
    'lernova.active_account_id': 'local',
    'lernova.user.local': jsonEncode(user.toJson()),
    'lernova.progress.local':
        jsonEncode(_progress(pro: pro, productId: productId).toJson()),
    'lernova.onboarding_complete.local': true,
  });

  late LocalStorageService storage;
  await tester.runAsync(() async {
    storage = await LocalStorageService.create();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        purchaseServiceProvider.overrideWithValue(
          FakeStore(owned: pro ? {productId ?? ProProducts.monthly} : const {}),
        ),
        entitlementVerifyWindowProvider.overrideWithValue(Duration.zero),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: screen),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
  });

  testWidgets('Pro screen — subscribed', (tester) async {
    await _pump(
      tester,
      const PremiumScreen(),
      pro: true,
      productId: ProProducts.monthly,
    );
    await expectLater(
      find.byType(PremiumScreen),
      matchesGoldenFile('goldens/pro_screen_subscribed.png'),
    );
  });

  testWidgets('Pro screen — not subscribed', (tester) async {
    await _pump(tester, const PremiumScreen(), pro: false);
    await expectLater(
      find.byType(PremiumScreen),
      matchesGoldenFile('goldens/pro_screen_free.png'),
    );
  });

  testWidgets('Settings — subscribed', (tester) async {
    await _pump(
      tester,
      const SettingsScreen(),
      pro: true,
      productId: ProProducts.monthly,
    );
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_subscribed.png'),
    );
  });
}
