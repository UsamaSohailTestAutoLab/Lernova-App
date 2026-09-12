import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_permission_service.dart';
import '../../../core/services/service_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../application/settings_controller.dart';

/// Notifications are off until the operating system says otherwise.
///
/// The in-app switch is deliberately not the source of truth: it can
/// only ever be on when the OS permission is granted, because a switch
/// that says "on" while the OS is blocking us is a promise the app
/// cannot keep. Turning it on therefore asks the system first and only
/// stores the preference if the answer is yes.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  NotificationPermission? _permission;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Re-read on every return to the screen: the learner may have changed
  /// the permission in system settings while we were backgrounded, and
  /// the stored preference has to be corrected when they have.
  Future<void> _refresh() async {
    final status =
        await ref.read(notificationPermissionServiceProvider).status();
    if (!mounted) return;
    setState(() => _permission = status);

    if (status != NotificationPermission.granted &&
        ref.read(settingsProvider).notificationsEnabled) {
      ref.read(settingsProvider.notifier).toggleNotifications(false);
    }
  }

  Future<void> _onToggle(bool wantsOn) async {
    final controller = ref.read(settingsProvider.notifier);
    if (!wantsOn) {
      controller.toggleNotifications(false);
      return;
    }

    setState(() => _busy = true);
    final service = ref.read(notificationPermissionServiceProvider);
    var status = await service.status();
    if (status != NotificationPermission.granted) {
      status = await service.request();
    }
    if (!mounted) return;

    setState(() {
      _permission = status;
      _busy = false;
    });

    if (status == NotificationPermission.granted) {
      controller.toggleNotifications(true);
      return;
    }

    // The OS has stopped offering a prompt, so tapping the switch again
    // would do nothing at all. Send them where the decision actually
    // lives.
    if (status == NotificationPermission.permanentlyDenied) {
      AppSnackBar.show(
        context,
        'Notifications are blocked for LingoQuest in system settings.',
        actionLabel: 'Open settings',
        onAction: service.openSettings,
      );
      return;
    }

    AppSnackBar.show(context, 'Notifications stay off without permission.');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    final granted = _permission == NotificationPermission.granted;
    final blocked = _permission == NotificationPermission.permanentlyDenied;
    final on = settings.notificationsEnabled && granted;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Push notifications'),
            subtitle: Text(
              blocked
                  ? 'Blocked in system settings'
                  : granted
                      ? 'Master switch for all reminders'
                      : "We'll ask your device for permission first",
            ),
            value: on,
            onChanged: _busy ? null : _onToggle,
          ),
          SwitchListTile(
            title: const Text('Daily reminder'),
            subtitle: const Text("Nudge me if I haven't practiced yet"),
            value: settings.dailyReminderEnabled && on,
            onChanged: on ? controller.toggleDailyReminder : null,
          ),
          if (on && settings.dailyReminderEnabled)
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
                        '${picked.hour.toString().padLeft(2, '0')}:'
                        '${picked.minute.toString().padLeft(2, '0')}';
                    controller.setReminderTime(formatted);
                  }
                },
              ),
            ),
          if (blocked)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Text(
                'Your device is blocking notifications for LingoQuest. '
                'Turn them on in system settings, then come back here.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
