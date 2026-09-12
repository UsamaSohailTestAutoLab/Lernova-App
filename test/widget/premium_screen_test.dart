import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/core/theme/app_theme.dart';
import 'package:lingoquest/data/models/app_user.dart';
import 'package:lingoquest/data/models/pro_entitlement.dart';
import 'package:lingoquest/data/models/user_progress.dart';
import 'package:lingoquest/core/services/purchase_service.dart';
import 'package:lingoquest/features/settings/application/purchase_controller.dart';
import 'package:lingoquest/features/settings/presentation/premium_screen.dart';

import '../support/fake_store.dart';

/// The same pump, but for somebody who has already paid.
///
/// The subscriber layout is a different column — it drops the plan cards
/// and the buy button and adds a membership card and a stats strip — so
/// "the Pro screen fits without scrolling" has to be proved twice, not
/// inferred from the sales state fitting.
Future<void> _pumpSubscribed(WidgetTester tester) async {
  final user = AppUser(
    id: 'local',
    name: 'Maya',
    email: '',
    avatarSeed: 'Maya',
    joinedAt: DateTime(2026, 1, 1),
    selectedLanguageId: 'es',
    currentCourseId: 'course_es',
  );
  final progress = UserProgress.initial(weekId: '2026-W37').copyWith(
    totalXp: 48600, // five digits, the widest the strip will ever hold
    streakCount: 365,
    totalLessonsCompleted: 128,
    isPremium: true,
    proEntitlement: ProEntitlement(
      isActive: true,
      productId: ProProducts.monthly,
      purchasedAt: DateTime(2026, 9, 1),
      source: ProSource.store,
    ),
  );

  SharedPreferences.setMockInitialValues({
    'lernova.active_account_id': 'local',
    'lernova.user.local': jsonEncode(user.toJson()),
    'lernova.progress.local': jsonEncode(progress.toJson()),
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
        purchaseServiceProvider.overrideWithValue(FakeStore()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const PremiumScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pump(WidgetTester tester, FakeStore store) async {
  SharedPreferences.setMockInitialValues({});
  late LocalStorageService storage;
  await tester.runAsync(() async {
    storage = await LocalStorageService.create();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        purchaseServiceProvider.overrideWithValue(store),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const PremiumScreen(),
      ),
    ),
  );
  // Products load in a microtask; the mascot art keeps animating, so
  // bounded pumps rather than pumpAndSettle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The maximum a learner could scroll this screen. Zero means every
/// plan, the price and the button are all on screen at once — which is
/// the whole requirement.
double _scrollExtent(WidgetTester tester) {
  final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
  return scrollable.controller?.position.maxScrollExtent ??
      Scrollable.of(tester.element(find.byType(PremiumScreen)))
          .position
          .maxScrollExtent;
}

/// Whether this screen fits is a question about real text, and the
/// default test font is a square-glyph stand-in that makes every string
/// roughly half again too wide. Loading the app's own bundled faces is
/// what makes "it fits on a phone" mean the same thing here as it does
/// on the device.
Future<void> _loadRealFonts() async {
  for (final family in const {
    'Inter': 'assets/fonts/Inter.ttf',
    'Baloo 2': 'assets/fonts/Baloo2.ttf',
  }.entries) {
    final loader = FontLoader(family.key)
      ..addFont(rootBundle.load(family.value));
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
  });

  testWidgets('the whole paywall fits on a phone with nothing to scroll',
      (tester) async {
    // A Pixel 5a in logical pixels.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await _pump(tester, FakeStore());

    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Restore Purchases'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      _scrollExtent(tester),
      0.0,
      reason: 'the Pro screen must show everything without scrolling',
    );
  });

  testWidgets('a small phone still fits', (tester) async {
    // 375x667 — an iPhone SE, the smallest screen still in wide use.
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await _pump(tester, FakeStore());

    expect(tester.takeException(), isNull);
    expect(_scrollExtent(tester), 0.0);
  });

  testWidgets('it scrolls rather than clipping at a large text size',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    late LocalStorageService storage;
    await tester.runAsync(() async {
      storage = await LocalStorageService.create();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          purchaseServiceProvider.overrideWithValue(FakeStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: PremiumScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Accessibility wins over the no-scroll rule: the learner must be
    // able to reach the price and the button, so the screen gives way
    // rather than cutting them off.
    expect(tester.takeException(), isNull);
    expect(_scrollExtent(tester), greaterThan(0.0));
  });

  testWidgets('the trial badge and CTA come from the store', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await _pump(tester, FakeStore());

    expect(find.text('3 DAYS FREE'), findsOneWidget);
    // Play reports a trial-bearing plan's price as "Free"; the card must
    // show what the learner will actually be charged.
    expect(find.text(r'$12.00'), findsOneWidget);
    expect(find.text('Free'), findsNothing);

    // Monthly is not preselected — yearly is, being the priciest — so
    // the CTA stays generic until the learner picks the trial plan.
    expect(find.text('Upgrade to Pro'), findsOneWidget);
    await tester.tap(find.text('Monthly'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Start my 3 days free'), findsOneWidget);
    expect(
      find.textContaining('Free for 3 days, then \$12.00'),
      findsOneWidget,
    );
  });

  testWidgets('no badge and no trial copy when the store offers none',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await _pump(tester, FakeStore(monthlyHasTrial: false));

    expect(find.textContaining('FREE'), findsNothing);
    expect(find.textContaining('Free for'), findsNothing);
    expect(find.text('Upgrade to Pro'), findsOneWidget);

    await tester.tap(find.text('Monthly'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Upgrade to Pro'), findsOneWidget);
  });

  testWidgets('a subscriber fits on a phone with nothing to scroll',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await _pumpSubscribed(tester);

    expect(find.text('Monthly Pro — active'), findsOneWidget);
    expect(find.text('Member since 1 September 2026'), findsOneWidget);
    expect(find.text('Manage subscription'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      _scrollExtent(tester),
      0.0,
      reason: 'the subscriber view must show everything without scrolling',
    );
  });

  testWidgets('a subscriber fits on a small phone by dropping the stats',
      (tester) async {
    // 375x667 — an iPhone SE. All four blocks do not fit, so the stats
    // strip gives way rather than the page starting to scroll. What a
    // subscriber came for — the confirmation and the manage link — is
    // still there, and Home still shows the same three figures.
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await _pumpSubscribed(tester);

    expect(find.text('Monthly Pro — active'), findsOneWidget);
    expect(find.text('Manage subscription'), findsOneWidget);
    expect(find.text('YOUR PROGRESS'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(_scrollExtent(tester), 0.0);
  });

  testWidgets('the stats strip shows the learner their own totals',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await _pumpSubscribed(tester);

    expect(find.text('48600'), findsOneWidget);
    expect(find.text('365'), findsOneWidget);
    expect(find.text('128'), findsOneWidget);
    // Lifetime totals, so they must not be labelled as since-purchase —
    // the app has no way to compute that.
    expect(find.textContaining('since you went Pro'), findsNothing);
  });

  testWidgets('each plan appears once despite Play fanning offers out',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await _pump(tester, FakeStore());

    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
  });
}
