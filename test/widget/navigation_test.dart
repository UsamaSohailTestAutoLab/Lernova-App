import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lernova/core/services/local_storage_service.dart';
import 'package:lernova/core/services/service_providers.dart';
import 'package:lernova/core/widgets/lernova_parrot.dart';
import 'package:lernova/data/models/app_user.dart';
import 'package:lernova/data/models/user_progress.dart';
import 'package:lernova/main.dart';

/// Boots straight into the app (onboarding already done) so the bottom
/// navigation is on screen.
Future<void> _pumpApp(WidgetTester tester) async {
  final user = AppUser(
    id: 'local',
    name: 'Ada',
    email: '',
    avatarSeed: 'Ada',
    joinedAt: DateTime(2026, 1, 1),
    selectedLanguageId: 'es',
    currentCourseId: 'course_es',
  );
  SharedPreferences.setMockInitialValues({
    'lernova.active_account_id': 'local',
    'lernova.user.local': jsonEncode(user.toJson()),
    'lernova.progress.local': jsonEncode(UserProgress.initial(weekId: '2026-W01').toJson()),
    'lernova.onboarding_complete.local': true,
  });
  final storage = await LocalStorageService.create();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      child: const LernovaApp(),
    ),
  );

  // Bounded pumps rather than pumpAndSettle: Home runs a continuous
  // animation, so settling never completes (see docs/TESTING.md).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1000));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.text('Settings'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// The Settings tab's scrollable, for reaching items below the fold.
Finder _settingsList() => find.byType(Scrollable).last;

void main() {
  testWidgets('the bottom bar is exactly Home, Path, Fun, Settings', (tester) async {
    await _pumpApp(tester);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(4));
    expect(
      bar.destinations.map((d) => (d as NavigationDestination).label).toList(),
      ['Home', 'Path', 'Fun', 'Settings'],
    );
  });

  testWidgets('the removed tabs are gone', (tester) async {
    await _pumpApp(tester);

    for (final removed in ['Mate', 'Ranks', 'Profile']) {
      expect(find.text(removed), findsNothing, reason: '$removed should be removed');
    }
  });

  testWidgets('Settings is reachable from the bar and shows its sections', (tester) async {
    await _pumpApp(tester);

    await _openSettings(tester);

    // The entry point used to live on Profile, which no longer exists.
    expect(find.text('Upgrade to Pro'), findsOneWidget);
    expect(find.text('Restore Purchase'), findsOneWidget);
    // The brand header at the top: one mascot design across the app.
    expect(find.byType(LernovaParrot), findsOneWidget);

    // The rest sit further down the list.
    for (final item in [
      'Support',
      'More Apps',
      'Privacy Policy',
      'Terms of Use',
      'EULA',
    ]) {
      await tester.scrollUntilVisible(find.text(item), 200, scrollable: _settingsList());
      expect(find.text(item), findsOneWidget);
    }

    // Sign-in is gone entirely.
    expect(find.text('Log out'), findsNothing);
  });

  testWidgets('Statistics and Achievements survived the Profile removal', (tester) async {
    await _pumpApp(tester);

    await _openSettings(tester);

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
  });
}
