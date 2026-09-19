import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/purchase_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/data/models/app_user.dart';
import 'package:lingoquest/data/models/fun_progress.dart';
import 'package:lingoquest/data/models/pro_entitlement.dart';
import 'package:lingoquest/data/models/user_progress.dart';
import 'package:lingoquest/features/settings/application/purchase_controller.dart';
import 'package:lingoquest/main.dart';

import '../support/fake_store.dart';

/// Captures the app's own screens at iPad geometry, for the iPad store
/// screenshots.
///
/// The App Store treats iPad as its own device family — this app ships
/// Universal (`TARGETED_DEVICE_FAMILY = "1,2"`), so a submission without
/// a 2064×2752 set is rejected. Those screens cannot be photographed
/// from the Android phone this project is developed on, and there is no
/// Mac here to run a simulator, so they are rendered instead: the real
/// `LingoQuestApp`, real bundled course content, real widgets, laid out
/// at an iPad Pro 13″'s 1032×1376 points.
///
/// What that is not: a mock-up, a redraw, or a phone screenshot stretched
/// sideways. What it does not cover: anything mid-gameplay. A falling
/// bubble caught at the right frame is a recording of a device, and
/// those stay phone captures — see the iPad screenshot builder for how
/// that set is composed around the gap.
///
/// Named without the `_test` suffix so `flutter test` leaves it alone:
///
///     flutter test test/widget/marketing_ipad_capture.dart --update-goldens

/// iPad Pro 13″ in points. Doubling it gives the 2064×2752 the store
/// asks for.
const _ipad = Size(1032, 1376);

/// Captured at 2× so the composite can scale the screen down inside a
/// frame and still be sharp. `matchesGoldenFile` writes at logical size
/// and ignores the view's device pixel ratio, so the scaling is done
/// with a transform instead.
const _scale = 2.0;

/// True once the icon and emoji faces are in place.
///
/// The headless renderer ships neither, so without them every
/// [Icon] and every emoji comes out as a "NO GLYPH" box. Harmless in an
/// ordinary golden; fatal in an image bound for a store listing.
bool _glyphsReady = false;

Future<void> _loadFonts() async {
  for (final family in const {
    'Inter': 'assets/fonts/Inter.ttf',
    'Baloo 2': 'assets/fonts/Baloo2.ttf',
  }.entries) {
    final loader = FontLoader(family.key)..addFont(rootBundle.load(family.value));
    await loader.load();
  }

  final icons = await _firstExisting(const [
    r'C:\src\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
    '/opt/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]);
  final emoji = await _firstExisting(const [
    r'C:\Windows\Fonts\seguiemj.ttf',
    '/System/Library/Fonts/Apple Color Emoji.ttc',
    '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
  ]);
  if (icons == null || emoji == null) return;

  // 'MaterialIcons' is the family every Flutter [IconData] names, so
  // registering it under that name is what makes the real icons appear
  // rather than a grid of boxes.
  await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
  // Registered *into* the app's own families rather than as a separate
  // one: Flutter falls through to the later font in a family for any
  // glyph the first lacks, which is exactly how a device resolves emoji
  // and needs no change to the app's text theme.
  for (final family in const ['Inter', 'Baloo 2']) {
    await (FontLoader(family)..addFont(Future.value(emoji))).load();
  }
  _glyphsReady = true;
}

Future<ByteData?> _firstExisting(List<String> paths) async {
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    return ByteData.view((await file.readAsBytes()).buffer);
  }
  return null;
}

/// An account a few weeks in: enough progress that the screens have
/// something to show, and all of it a state the app really produces.
Future<LocalStorageService> _seed() async {
  final user = AppUser(
    id: 'local',
    name: 'Maya',
    email: '',
    avatarSeed: 'Maya',
    joinedAt: DateTime(2026, 8, 1),
    selectedLanguageId: 'es',
    currentCourseId: 'course_es',
  );

  final progress = UserProgress.initial(weekId: '2026-W38').copyWith(
    totalXp: 2480,
    streakCount: 12,
    totalLessonsCompleted: 5,
    completedLessonIds: {'es_u1_l1', 'es_u1_l2'},
    isPremium: true,
    proEntitlement: const ProEntitlement(
      status: EntitlementStatus.subscribedActive,
      productId: ProProducts.yearly,
      source: ProSource.store,
    ),
  );

  final fun = FunProgress(
    gameLevels: const {
      'fallingWords': 6,
      'wordRush': 4,
      'wordMatch': 5,
      'memoryMatch': 3,
      'sentenceBuilder': 4,
      'listenAndCatch': 3,
    },
    dailyChallengeDate: DateTime(2026, 9, 19),
  );

  SharedPreferences.setMockInitialValues({
    'lernova.active_account_id': user.id,
    'lernova.user.${user.id}': jsonEncode(user.toJson()),
    'lernova.progress.${user.id}': jsonEncode(progress.toJson()),
    'lernova.onboarding_complete.${user.id}': true,
    'lernova.fun_progress.${user.id}.es': jsonEncode(fun.toJson()),
  });
  SharedPreferences.resetStatic();
  // rootBundle caches the *future* per asset key; one left in flight by a
  // previous capture never completes and the next screen waits forever on
  // a spinner.
  rootBundle.clear();

  return LocalStorageService.create();
}

/// Pump until [finder] matches. Asset-backed screens only progress
/// inside `runAsync`, and never `pumpAndSettle` — the mascots animate
/// forever.
Future<void> _until(
  WidgetTester tester,
  Finder finder, {
  int maxRounds = 90,
  String? because,
}) async {
  for (var i = 0; i < maxRounds; i++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 120));
      return;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump(const Duration(milliseconds: 120));
  }
  fail('timed out waiting for $finder${because == null ? '' : ' — $because'}');
}

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = Size(_ipad.width * _scale, _ipad.height * _scale);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  late LocalStorageService storage;
  await tester.runAsync(() async {
    storage = await _seed();
  });

  await tester.pumpWidget(
    SizedBox(
      width: _ipad.width * _scale,
      height: _ipad.height * _scale,
      child: Transform.scale(
        scale: _scale,
        alignment: Alignment.topLeft,
        // The app must lay out at an iPad's real point size; the parent
        // hands down tight 2× constraints, which only an OverflowBox can
        // shrink past.
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: _ipad.width,
          maxWidth: _ipad.width,
          minHeight: _ipad.height,
          maxHeight: _ipad.height,
          child: ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWithValue(storage),
              purchaseServiceProvider.overrideWithValue(
                FakeStore(owned: {ProProducts.yearly}),
              ),
              entitlementVerifyWindowProvider.overrideWithValue(Duration.zero),
            ],
            child: const LingoQuestApp(),
          ),
        ),
      ),
    ),
  );

  await _until(tester, find.text('Settings'), because: 'the app never booted');
}

Future<void> _shoot(WidgetTester tester, String name) async {
  // Better no image than a store screenshot full of NO GLYPH boxes.
  if (!_glyphsReady) {
    markTestSkipped('no icon/emoji font on this host — nothing written');
    return;
  }
  await expectLater(
    find.byType(Transform).first,
    matchesGoldenFile('../../marketing/raw_ipad/$name.png'),
  );
}

/// Opens a bottom-nav destination and waits for something only that tab
/// shows.
Future<void> _tab(WidgetTester tester, String tab, Finder landmark) async {
  await tester.tap(find.text(tab));
  await _until(tester, landmark, because: 'the $tab tab never opened');
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  testWidgets('home', (tester) async {
    await _boot(tester);
    await _until(tester, find.textContaining('Hey Maya'));
    await _shoot(tester, 'home');
  });

  testWidgets('path', (tester) async {
    await _boot(tester);
    await _tab(tester, 'Path', find.text('Your path'));
    await _shoot(tester, 'path');
  });

  testWidgets('fun hub', (tester) async {
    await _boot(tester);
    await _tab(tester, 'Fun', find.text('Word Bubble'));
    await _shoot(tester, 'fun');
  });

  testWidgets('settings', (tester) async {
    await _boot(tester);
    await _tab(tester, 'Settings', find.text('Switch language'));
    await _shoot(tester, 'settings');
  });

  testWidgets('language switcher', (tester) async {
    await _boot(tester);
    await _tab(tester, 'Settings', find.text('Switch language'));
    await tester.tap(find.text('Switch language'));
    await _until(tester, find.textContaining('Spanish'));
    await _shoot(tester, 'languages');
  });

  testWidgets('statistics', (tester) async {
    await _boot(tester);
    await _tab(tester, 'Settings', find.text('Statistics'));
    await tester.tap(find.text('Statistics'));
    await _until(tester, find.textContaining('XP'));
    await _shoot(tester, 'statistics');
  });

  testWidgets('achievements', (tester) async {
    await _boot(tester);
    await _tab(tester, 'Settings', find.text('Achievements'));
    await tester.tap(find.text('Achievements'));
    await _until(tester, find.textContaining('Achievements'));
    await _shoot(tester, 'achievements');
  });

  testWidgets('lesson intro', (tester) async {
    await _boot(tester);
    await _tab(tester, 'Path', find.text('Your path'));
    await tester.tap(find.text('Polite Basics'), warnIfMissed: false);
    await _until(tester, find.textContaining('Polite Basics'));
    await _shoot(tester, 'lesson_intro');
  });
}
