import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/data/models/app_user.dart';
import 'package:lingoquest/data/models/fun_progress.dart';
import 'package:lingoquest/data/models/pro_entitlement.dart';
import 'package:lingoquest/data/models/user_progress.dart';
import 'package:lingoquest/features/settings/application/purchase_controller.dart';
import 'package:lingoquest/main.dart';

import '../support/fake_store.dart';

/// The free tier as a learner meets it: one Path lesson, one Fun level,
/// and a paywall everywhere else. `entitlements_test.dart` pins the rule
/// itself; these pin that the screens route to the paywall, which is the
/// half that silently stops working when a tap handler is refactored.

/// Pump until [finder] matches, or fail saying what never arrived.
///
/// Two things make a plain `pump` insufficient here. The course JSON and
/// the Fun word lists come off the asset bundle, which is real I/O and
/// only progresses inside [WidgetTester.runAsync]; and how long that
/// takes depends on what the rest of the file has already loaded, so a
/// fixed pump budget passes a test in isolation and fails it in a full
/// run. Waiting on the thing being looked for is stable either way.
///
/// Never [WidgetTester.pumpAndSettle] — the mascots animate forever.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  String? because,
  int maxRounds = 80,
}) async {
  for (var i = 0; i < maxRounds; i++) {
    if (finder.evaluate().isNotEmpty) {
      // One more frame so the match is laid out before it is tapped.
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump(const Duration(milliseconds: 120));
  }
  fail('timed out waiting for $finder${because == null ? '' : ' — $because'}');
}

/// A few frames, for asserting that something is *not* there.
Future<void> _pumpAWhile(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _boot(
  WidgetTester tester, {
  bool pro = false,
  Set<String> completedLessons = const {},
  Map<String, int> funLevels = const {},
}) async {
  final user = AppUser(
    id: 'u1',
    name: 'Ada',
    email: 'ada@example.com',
    avatarSeed: 'Ada',
    joinedAt: DateTime(2026, 1, 1),
    selectedLanguageId: 'es',
    currentCourseId: 'course_es',
  );

  var progress = UserProgress.initial(weekId: '2026-W37')
      .copyWith(completedLessonIds: completedLessons);
  if (pro) {
    progress = progress.copyWith(
      isPremium: true,
      proEntitlement: const ProEntitlement(
        isActive: true,
        source: ProSource.store,
      ),
    );
  }

  final fun = FunProgress(
    gameLevels: funLevels,
    dailyChallengeDate: DateTime(2026, 9, 13),
  );

  // Account-scoped keys, not the pre-multi-profile ones. Seeding the
  // legacy keys would send the app through its one-time migration, and
  // that migration *writes* — so the next test in the file would boot on
  // a store the previous one had already rewritten.
  SharedPreferences.setMockInitialValues({
    'lernova.active_account_id': user.id,
    'lernova.user.${user.id}': jsonEncode(user.toJson()),
    'lernova.progress.${user.id}': jsonEncode(progress.toJson()),
    'lernova.onboarding_complete.${user.id}': true,
    // Fun levels are kept per account *and* per language, in their own
    // store rather than on UserProgress.
    'lernova.fun_progress.${user.id}.${user.selectedLanguageId}':
        jsonEncode(fun.toJson()),
  });

  // Drop the cached instance *after* installing the values, so the next
  // getInstance() re-reads them. SharedPreferences caches per isolate
  // and the app writes to that store as it runs.
  SharedPreferences.resetStatic();

  // rootBundle caches the *future* per asset key, and a load left in
  // flight when the previous test tore down stays in that cache as a
  // future that will never complete. The next test awaiting the same key
  // then sits on a spinner forever, which reads as "the content is
  // missing" rather than "the bundle is poisoned".
  rootBundle.clear();

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
      child: const LingoQuestApp(),
    ),
  );

  // Home is up once the bottom bar is, which is past the splash and the
  // first storage read.
  await _pumpUntil(
    tester,
    find.text('Settings'),
    because: 'the app never booted',
  );
}

/// The Pro screen's headline for somebody who has not paid.
final _paywall = find.textContaining('Learn without limits');

void main() {
  group('the Path', () {
    testWidgets('a locked lesson opens the paywall, not a lesson',
        (tester) async {
      await _boot(tester, completedLessons: {'es_u1_l1'});

      await tester.tap(find.text('Path'));
      await _pumpUntil(tester, find.text('Yes, No, Sorry'));

      // warnIfMissed: false — path nodes sit under nested Transforms (the
      // dx offset, and the shake a progression-locked node uses), which
      // makes flutter_test's own hit-test sanity check unreliable even
      // though the tap does reach the node's GestureDetector.
      await tester.tap(find.text('Yes, No, Sorry'), warnIfMissed: false);
      await _pumpUntil(tester, _paywall, because: 'the paywall never opened');
    });

    testWidgets('Say Hello still opens for free', (tester) async {
      await _boot(tester);

      await tester.tap(find.text('Path'));
      await _pumpUntil(tester, find.text('Say Hello'));

      await tester.tap(find.text('Say Hello'), warnIfMissed: false);
      await _pumpAWhile(tester);

      // The lesson intro, not the Pro screen.
      expect(_paywall, findsNothing);
      expect(find.text('Your path'), findsNothing);
    });

    testWidgets('a subscriber gets the lesson instead', (tester) async {
      await _boot(tester, pro: true, completedLessons: {'es_u1_l1'});

      await tester.tap(find.text('Path'));
      await _pumpUntil(tester, find.text('Yes, No, Sorry'));

      await tester.tap(find.text('Yes, No, Sorry'), warnIfMissed: false);
      await _pumpAWhile(tester);

      expect(_paywall, findsNothing);
    });
  });

  group('the Fun Zone', () {
    testWidgets('every game but Word Bubble offers Pro', (tester) async {
      await _boot(tester);

      await tester.tap(find.text('Fun'));
      await _pumpUntil(tester, find.text('Word Bubble'));

      // Nine of the ten modes are behind the subscription.
      expect(
        find.text('Unlock with Pro'),
        findsNWidgets(FunGameMode.values.length - 1),
      );
      // Word Bubble keeps its own blurb.
      expect(find.text(FunGameMode.fallingWords.blurb), findsOneWidget);
    });

    testWidgets('tapping a locked game opens the paywall', (tester) async {
      await _boot(tester);

      await tester.tap(find.text('Fun'));
      await _pumpUntil(tester, find.text('Word Rush'));

      await tester.tap(find.text('Word Rush'));
      await _pumpUntil(tester, _paywall, because: 'the paywall never opened');
    });

    testWidgets('Word Bubble is playable at level 1', (tester) async {
      await _boot(tester);

      await tester.tap(find.text('Fun'));
      await _pumpUntil(tester, find.text('Word Bubble'));

      await tester.tap(find.text('Word Bubble'));
      await _pumpAWhile(tester);

      expect(_paywall, findsNothing);
      expect(find.textContaining('needs Pro'), findsNothing);
    });

    testWidgets('Word Bubble at level 2 asks for Pro', (tester) async {
      // Clearing the free level moves the learner to level 2 — the exact
      // moment the free tier runs out.
      await _boot(tester, funLevels: {FunGameMode.fallingWords.name: 2});

      await tester.tap(find.text('Fun'));
      await _pumpUntil(tester, find.text('Word Bubble'));

      expect(
        find.text('Unlock with Pro'),
        findsNWidgets(FunGameMode.values.length),
      );

      await tester.tap(find.text('Word Bubble'));
      await _pumpUntil(tester, _paywall, because: 'the paywall never opened');
    });

    testWidgets('a subscriber sees no Pro locks at all', (tester) async {
      await _boot(
        tester,
        pro: true,
        funLevels: {FunGameMode.fallingWords.name: 4},
      );

      await tester.tap(find.text('Fun'));
      await _pumpUntil(tester, find.text('Word Bubble'));

      expect(find.text('Unlock with Pro'), findsNothing);
    });
  });

  group('Home', () {
    testWidgets('the continue button sells Pro once the free lesson is done',
        (tester) async {
      await _boot(tester, completedLessons: {'es_u1_l1'});
      await _pumpUntil(tester, find.text('Unlock with Pro'));

      expect(find.text('Continue learning'), findsNothing);

      // Home scrolls, and the card sits below the fold on the default
      // test viewport — an un-scrolled tap lands on nothing.
      await tester.ensureVisible(find.text('Unlock with Pro'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Unlock with Pro'));
      await _pumpUntil(tester, _paywall, because: 'the paywall never opened');
    });

    testWidgets('it still says Continue learning before that', (tester) async {
      await _boot(tester);
      await _pumpUntil(tester, find.text('Continue learning'));

      expect(find.text('Unlock with Pro'), findsNothing);
    });
  });
}
