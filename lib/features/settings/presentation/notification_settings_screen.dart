import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../application/settings_controller.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Push notifications'),
            subtitle: const Text('Master switch for all in-app reminders'),
            value: settings.notificationsEnabled,
            onChanged: controller.toggleNotifications,
          ),
          SwitchListTile(
            title: const Text('Daily reminder'),
            subtitle: const Text("Nudge me if I haven't practiced yet"),
            value: settings.dailyReminderEnabled && settings.notificationsEnabled,
            onChanged: settings.notificationsEnabled
                ? controller.toggleDailyReminder
                : null,
          ),
          if (settings.notificationsEnabled && settings.dailyReminderEnabled)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminder time'),
                subtitle: Text(settings.reminderTime),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final parts = settings.reminderTime.split(':');
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: int.tryParse(parts[0]) ?? 18,
                      minute: int.tryParse(parts[1]) ?? 0,
                    ),
                  );
                  if (picked != null) {
                    final formatted =
                        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    controller.setReminderTime(formatted);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
