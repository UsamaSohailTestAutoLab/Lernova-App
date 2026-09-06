import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/app_user.dart';
import '../../data/models/fun_progress.dart';
import '../../data/models/user_progress.dart';

/// Single choke point for all local persistence. Device-wide data (the
/// account list, which account is currently active) lives under fixed
/// keys; everything else — profile, progress, settings, fun progress,
/// onboarding-complete — is namespaced per account id, keyed off
/// whichever account [setActiveAccount] last selected, so multiple
/// accounts on one device never see each other's data. A future
/// backend-backed repository can mirror this same per-account shape
/// over the network without any UI change.
class LocalStorageService {
  static const _keyActiveAccountId = 'lernova.active_account_id';

  // Legacy, pre-multi-account keys — read once during migration, then
  // removed. Kept as constants only so the migration step has them.
  static const _legacyKeyUser = 'lernova.user';
  static const _legacyKeyProgress = 'lernova.progress';
  static const _legacyKeySettings = 'lernova.settings';
  static const _legacyKeyFunProgress = 'lernova.fun_progress';
  static const _legacyKeyOnboardingComplete = 'lernova.onboarding_complete';

  final SharedPreferences _prefs;
  String? _activeAccountId;

  LocalStorageService(this._prefs) {
    _activeAccountId = _prefs.getString(_keyActiveAccountId);
  }

  /// The profile id used when there's nothing to inherit — the app is
  /// single-profile now, so this is the steady state for new installs.
  static const _defaultProfileId = 'local';

  static Future<LocalStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final service = LocalStorageService(prefs);
    await service._migrateLegacySingleProfileIfNeeded();
    await service._adoptExistingProfile();
    return service;
  }

  String? get activeAccountId => _activeAccountId;

  Future<void> setActiveAccount(String? id) async {
    _activeAccountId = id;
    if (id == null) {
      await _prefs.remove(_keyActiveAccountId);
    } else {
      await _prefs.setString(_keyActiveAccountId, id);
    }
  }

  /// Sign-in used to decide which namespaced profile was active. With
  /// accounts gone there's nobody to set it, so resolve one at startup:
  /// keep whatever was already active, otherwise adopt an existing
  /// profile's data (so a user who had logged out doesn't come back to
  /// an empty app), otherwise start a fresh local profile.
  ///
  /// Without this every read returns null *and every write silently
  /// no-ops*, which would look exactly like total data loss.
  Future<void> _adoptExistingProfile() async {
    if (_activeAccountId != null) return;

    const progressPrefix = 'lernova.progress.';
    const userPrefix = 'lernova.user.';
    String? inherited;
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(progressPrefix)) {
        inherited = key.substring(progressPrefix.length);
        break; // progress is the data worth preserving — prefer it
      }
      if (key.startsWith(userPrefix)) {
        inherited ??= key.substring(userPrefix.length);
      }
    }

    await setActiveAccount(inherited ?? _defaultProfileId);
  }

  // User — keyed by the user's own id (not the active id), so a caller
  // always writes exactly the profile it means to.
  Future<void> saveUser(AppUser user) =>
      _prefs.setString('lernova.user.${user.id}', jsonEncode(user.toJson()));

  AppUser? loadUser() {
    final id = _activeAccountId;
    if (id == null) return null;
    final raw = _prefs.getString('lernova.user.$id');
    if (raw == null) return null;
    return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  // Progress (per active account)
  Future<void> saveProgress(UserProgress progress) {
    final id = _activeAccountId;
    if (id == null) return Future.value();
    return _prefs.setString('lernova.progress.$id', jsonEncode(progress.toJson()));
  }

  UserProgress? loadProgress() {
    final id = _activeAccountId;
    if (id == null) return null;
    final raw = _prefs.getString('lernova.progress.$id');
    if (raw == null) return null;
    return UserProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  // Settings (per active account)
  Future<void> saveSettings(AppSettings settings) {
    final id = _activeAccountId;
    if (id == null) return Future.value();
    return _prefs.setString('lernova.settings.$id', jsonEncode(settings.toJson()));
  }

  AppSettings loadSettings() {
    final id = _activeAccountId;
    if (id == null) return const AppSettings();
    final raw = _prefs.getString('lernova.settings.$id');
    if (raw == null) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  // Fun progress (per active account)
  Future<void> saveFunProgress(FunProgress progress) {
    final id = _activeAccountId;
    if (id == null) return Future.value();
    return _prefs.setString('lernova.fun_progress.$id', jsonEncode(progress.toJson()));
  }

  FunProgress? loadFunProgress() {
    final id = _activeAccountId;
    if (id == null) return null;
    final raw = _prefs.getString('lernova.fun_progress.$id');
    if (raw == null) return null;
    return FunProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  // Onboarding (per active account)
  Future<void> setOnboardingComplete(bool value) {
    final id = _activeAccountId;
    if (id == null) return Future.value();
    return _prefs.setBool('lernova.onboarding_complete.$id', value);
  }

  bool isOnboardingComplete() {
    final id = _activeAccountId;
    if (id == null) return false;
    return _prefs.getBool('lernova.onboarding_complete.$id') ?? false;
  }

  /// One-time upgrade from the oldest, un-namespaced key scheme: copy
  /// each legacy blob into its namespaced home and adopt that profile,
  /// so an install from before per-profile keys keeps all its progress.
  Future<void> _migrateLegacySingleProfileIfNeeded() async {
    final legacyUserRaw = _prefs.getString(_legacyKeyUser);
    if (legacyUserRaw == null) return; // nothing from the old scheme

    final legacyUser = AppUser.fromJson(jsonDecode(legacyUserRaw) as Map<String, dynamic>);

    await _prefs.setString('lernova.user.${legacyUser.id}', legacyUserRaw);
    await _migrateLegacyBlob(_legacyKeyProgress, 'lernova.progress.${legacyUser.id}');
    await _migrateLegacyBlob(_legacyKeySettings, 'lernova.settings.${legacyUser.id}');
    await _migrateLegacyBlob(_legacyKeyFunProgress, 'lernova.fun_progress.${legacyUser.id}');
    final onboardingComplete = _prefs.getBool(_legacyKeyOnboardingComplete) ?? false;
    await _prefs.setBool('lernova.onboarding_complete.${legacyUser.id}', onboardingComplete);

    await _prefs.remove(_legacyKeyUser);
    await _prefs.remove(_legacyKeyProgress);
    await _prefs.remove(_legacyKeySettings);
    await _prefs.remove(_legacyKeyFunProgress);
    await _prefs.remove(_legacyKeyOnboardingComplete);

    await setActiveAccount(legacyUser.id);
  }

  Future<void> _migrateLegacyBlob(String legacyKey, String newKey) async {
    final raw = _prefs.getString(legacyKey);
    if (raw != null) await _prefs.setString(newKey, raw);
  }
}
