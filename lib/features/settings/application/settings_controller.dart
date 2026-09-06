import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_providers.dart';
import '../../../data/models/app_settings.dart';

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    return ref.read(localStorageServiceProvider).loadSettings();
  }

  void _persist(AppSettings next) {
    state = next;
    ref.read(localStorageServiceProvider).saveSettings(next);
  }

  void setThemeMode(AppThemeMode mode) => _persist(state.copyWith(themeMode: mode));

  void toggleNotifications(bool value) =>
      _persist(state.copyWith(notificationsEnabled: value));

  void toggleDailyReminder(bool value) =>
      _persist(state.copyWith(dailyReminderEnabled: value));

  void setReminderTime(String time) =>
      _persist(state.copyWith(reminderTime: time));

  void toggleSound(bool value) => _persist(state.copyWith(soundEnabled: value));

  void toggleHaptics(bool value) =>
      _persist(state.copyWith(hapticsEnabled: value));
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
