import 'package:permission_handler/permission_handler.dart';

/// What the operating system currently says about notifications.
enum NotificationPermission {
  /// Never asked. The next request will show the system prompt.
  notRequested,

  /// The learner said yes. Reminders may be scheduled.
  granted,

  /// The learner said no, and the OS will still show a prompt if asked
  /// again.
  denied,

  /// The OS will no longer show a prompt — "don't ask again" on Android,
  /// or any refusal on iOS. The only route back is Settings.
  permanentlyDenied,
}

/// The one place the app asks the OS about notifications.
///
/// Wrapped rather than called inline so the toggle can be tested
/// without a platform channel, and so the "denied for good" case has a
/// name: it is the one that has to send the learner to system settings
/// instead of silently doing nothing when they tap the switch.
class NotificationPermissionService {
  const NotificationPermissionService();

  Future<NotificationPermission> status() =>
      _map(Permission.notification.status);

  /// Shows the system prompt if the OS is still willing to show one.
  Future<NotificationPermission> request() =>
      _map(Permission.notification.request());

  /// Opens the app's page in system settings, for when the OS has
  /// stopped offering a prompt.
  Future<bool> openSettings() => openAppSettings();

  Future<NotificationPermission> _map(Future<PermissionStatus> future) async {
    final status = await future;
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return NotificationPermission.granted;
    }
    if (status.isPermanentlyDenied) return NotificationPermission.permanentlyDenied;
    if (status.isDenied) return NotificationPermission.denied;
    return NotificationPermission.notRequested;
  }
}
