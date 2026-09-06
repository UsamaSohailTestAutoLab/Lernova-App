import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lernova/core/services/local_storage_service.dart';
import 'package:lernova/data/models/app_user.dart';
import 'package:lernova/data/models/user_progress.dart';

AppUser _user(String id) => AppUser(
      id: id,
      name: 'Grace Hopper',
      email: '',
      avatarSeed: 'Grace Hopper',
      joinedAt: DateTime(2026, 1, 1),
    );

UserProgress _progressWithXp(int xp) =>
    UserProgress.initial(weekId: '2026-W01').copyWith(totalXp: xp);

void main() {
  group('LocalStorageService profile resolution', () {
    test('a fresh install starts a local profile that can actually save', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();

      // Without an active profile every write silently no-ops, so this
      // is really asserting that saving works at all on a new install.
      expect(storage.activeAccountId, isNotNull);
      await storage.saveProgress(_progressWithXp(42));
      expect(storage.loadProgress()?.totalXp, 42);
    });

    test('adopts an existing namespaced profile instead of starting empty', () async {
      // Simulates an install from the account era whose active-account
      // pointer is gone (the user had logged out before upgrading).
      SharedPreferences.setMockInitialValues({
        'lernova.user.user_123': jsonEncode(_user('user_123').toJson()),
        'lernova.progress.user_123': jsonEncode(_progressWithXp(250).toJson()),
        'lernova.onboarding_complete.user_123': true,
      });

      final storage = await LocalStorageService.create();

      expect(storage.activeAccountId, 'user_123');
      expect(storage.loadProgress()?.totalXp, 250);
      expect(storage.loadUser()?.name, 'Grace Hopper');
      expect(storage.isOnboardingComplete(), isTrue);
    });

    test('keeps whichever profile was already active', () async {
      SharedPreferences.setMockInitialValues({
        'lernova.active_account_id': 'user_b',
        'lernova.progress.user_a': jsonEncode(_progressWithXp(10).toJson()),
        'lernova.progress.user_b': jsonEncode(_progressWithXp(99).toJson()),
      });

      final storage = await LocalStorageService.create();

      expect(storage.activeAccountId, 'user_b');
      expect(storage.loadProgress()?.totalXp, 99);
    });

    test('migrates the oldest un-namespaced keys and keeps the progress', () async {
      SharedPreferences.setMockInitialValues({
        'lernova.user': jsonEncode(_user('legacy1').toJson()),
        'lernova.progress': jsonEncode(_progressWithXp(500).toJson()),
        'lernova.onboarding_complete': true,
      });

      final storage = await LocalStorageService.create();

      expect(storage.activeAccountId, 'legacy1');
      expect(storage.loadProgress()?.totalXp, 500);
      expect(storage.isOnboardingComplete(), isTrue);
    });

    test('progress survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await LocalStorageService.create();
      await first.saveProgress(_progressWithXp(120));

      final second = await LocalStorageService.create();
      expect(second.loadProgress()?.totalXp, 120);
    });
  });
}
