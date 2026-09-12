import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/data/models/app_user.dart';

AppUser _user() => AppUser(
      id: 'local',
      name: 'Ada Lovelace',
      email: '',
      avatarSeed: 'Ada Lovelace',
      joinedAt: DateTime(2026, 1, 1),
      selectedLanguageId: 'es',
      currentCourseId: 'course_es',
    );

void main() {
  // The app is called LingoQuest. Its *storage* is not, and renaming
  // the prefix to match the brand is the one change here that would be
  // silently catastrophic: it points the app at keys that have never
  // been written, so every installed copy opens blank — progress,
  // streak, settings and Pro entitlement all apparently gone. Nobody
  // ever sees this string; it is plumbing, not branding.
  group('the storage prefix does not follow the rename', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a saved profile lands under the lernova. prefix', () async {
      final storage = await LocalStorageService.create();
      await storage.saveUser(_user());

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.startsWith('lernova.user.')),
        isNotEmpty,
        reason: 'renaming this prefix orphans every existing install',
      );
      expect(prefs.getKeys().where((k) => k.startsWith('lingoquest.')), isEmpty);
    });

    test('data written by the pre-rename app is still found', () async {
      // Exactly the shape an installed copy already has on disk.
      SharedPreferences.setMockInitialValues({
        'lernova.active_account_id': 'local',
        'lernova.user.local': jsonEncode(_user().toJson()),
        'lernova.onboarding_complete.local': true,
      });

      final storage = await LocalStorageService.create();

      expect(storage.loadUser()?.name, 'Ada Lovelace');
      expect(storage.isOnboardingComplete(), isTrue);
    });
  });
}
