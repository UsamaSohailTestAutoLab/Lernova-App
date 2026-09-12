import 'dart:convert';

import 'package:flutter/material.dart';
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

/// Once somebody has paid, every surface that was selling Pro has to
/// stop selling it and start serving it. These tests pin that flip on
/// the two screens a subscriber actually visits.
UserProgress _progress({required bool pro, String? productId}) {
  final base = UserProgress.initial(weekId: '2026-W37');
  if (!pro) return base;
  return base.copyWith(
    isPremium: true,
    proEntitlement: ProEntitlement(
      isActive: true,
      productId: productId,
      purchasedAt: DateTime(2026, 9, 1),
      source: ProSource.store,
    ),
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget screen, {
  required bool pro,
  String? productId,
}) async {
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

  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      // Without this the real billing plugin is constructed and reaches
      // for a channel no test binding answers.
      purchaseServiceProvider.overrideWithValue(FakeStore()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(), home: screen),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return container;
}

void main() {
  group('Settings, before anyone has paid', () {
    testWidgets('sells Pro and offers a restore', (tester) async {
      await _pump(tester, const SettingsScreen(), pro: false);

      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(find.text('Restore Purchase'), findsOneWidget);
      expect(find.text('Manage subscription'), findsNothing);
      expect(find.text('LINGOQUEST PRO'), findsOneWidget); // section header
    });
  });

  group('Settings, once they have', () {
    testWidgets('stops selling and names the plan instead', (tester) async {
      await _pump(
        tester,
        const SettingsScreen(),
        pro: true,
        productId: ProProducts.monthly,
      );

      // The upsell is gone.
      expect(find.text('Upgrade to Pro'), findsNothing);
      // So is restore — there is nothing to restore.
      expect(find.text('Restore Purchase'), findsNothing);
      // And the plan is named.
      expect(find.text('Active · Monthly plan'), findsOneWidget);
      expect(find.text('Manage subscription'), findsOneWidget);
    });

    testWidgets('says only "Active" when the product was never recorded',
        (tester) async {
      // An entitlement restored by an older build carries no product id;
      // inventing a plan name for it would misstate what they pay for.
      await _pump(tester, const SettingsScreen(), pro: true);

      expect(find.text('Active'), findsOneWidget);
      expect(find.textContaining('Active · '), findsNothing);
      expect(find.text('Manage subscription'), findsOneWidget);
    });
  });

  group('The Pro screen', () {
    testWidgets('shows plans and a restore link before purchase',
        (tester) async {
      await _pump(tester, const PremiumScreen(), pro: false);

      expect(find.text('Restore Purchases'), findsOneWidget);
      expect(find.text('Manage subscription'), findsNothing);
      expect(find.textContaining('Learn without limits'), findsOneWidget);
    });

    testWidgets('swaps restore for manage once subscribed', (tester) async {
      await _pump(
        tester,
        const PremiumScreen(),
        pro: true,
        productId: ProProducts.yearly,
      );

      expect(find.text('Yearly Pro — active'), findsOneWidget);
      expect(find.text('Manage subscription'), findsOneWidget);
      expect(find.text('Restore Purchases'), findsNothing);
      // No plan cards, no buy button.
      expect(find.text('Upgrade to Pro'), findsNothing);
      expect(find.textContaining('You have it all'), findsOneWidget);
    });
  });
}
