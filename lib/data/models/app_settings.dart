enum AppThemeMode { system, light, dark }

class AppSettings {
  final AppThemeMode themeMode;
  final bool notificationsEnabled;
  final bool dailyReminderEnabled;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final String reminderTime; // "HH:mm"

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.notificationsEnabled = false,
    this.dailyReminderEnabled = false,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.reminderTime = '18:00',
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? notificationsEnabled,
    bool? dailyReminderEnabled,
    bool? soundEnabled,
    bool? hapticsEnabled,
    String? reminderTime,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dailyReminderEnabled:
          dailyReminderEnabled ?? this.dailyReminderEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'notificationsEnabled': notificationsEnabled,
        'dailyReminderEnabled': dailyReminderEnabled,
        'soundEnabled': soundEnabled,
        'hapticsEnabled': hapticsEnabled,
        'reminderTime': reminderTime,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: AppThemeMode.values.byName(
        json['themeMode'] as String? ?? 'system',
      ),
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      dailyReminderEnabled: json['dailyReminderEnabled'] as bool? ?? false,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
      reminderTime: json['reminderTime'] as String? ?? '18:00',
    );
  }
}
