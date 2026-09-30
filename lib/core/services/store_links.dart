import 'package:flutter/foundation.dart';

/// Where the store links in Settings point, per platform.
///
/// An Android build must not send people to the App Store. It is the
/// obvious mistake to make, because the iOS URLs are the ones written
/// down first, and it is silent — the link opens, the page loads, and
/// it is simply the wrong shop.
///
/// Ids that a store assigns are held as nullable constants rather than
/// guessed. A wrong id produces a live page that 404s, which is worse
/// than a row that is not shown: the learner reaches a dead end inside
/// the store and concludes the app is abandoned.
class StoreLinks {
  StoreLinks._();

  /// Play's identifier for the app. This one is not assigned by a store
  /// — it is the `applicationId` from `android/app/build.gradle.kts` —
  /// so it is known ahead of publishing and safe to hard-code.
  static const androidPackage = 'com.lernova.lernova';

  /// Apple's numeric id for LingoQuest.
  ///
  /// Null until the app exists in App Store Connect. Apple assigns it,
  /// and it cannot be derived from anything: 1888780840, which appeared
  /// in an earlier build, is the *developer* id — `itunes.apple.com/
  /// lookup` returns `wrapperType: artist` for it — so the review link
  /// built from it returned "The page you're looking for can't be
  /// found."
  static const String? appStoreId = null;

  /// The developer's display name on Google Play, for the "More apps"
  /// page.
  ///
  /// Null until confirmed. Play's developer page is addressed by the
  /// publisher name exactly as it appears on the console
  /// (`?id=Some+Publisher`), and a near-miss is a 404 rather than a
  /// redirect — so this is not inferred from the Apple developer name,
  /// which is a different registration and need not match.
  static const String? playDeveloperName = null;

  /// Apple's developer page. This id *is* correct for this use — it is
  /// the artist id the lookup confirmed.
  static const appleDeveloperUrl =
      'https://apps.apple.com/us/developer/usama-sohail/id1888780840';

  /// Whether a "More apps" row can point anywhere on this platform.
  static bool get hasDeveloperPage =>
      isAndroid ? playDeveloperName != null : true;

  /// The developer's other apps, in the store this build came from.
  static Uri? get developerPage {
    if (isAndroid) {
      final name = playDeveloperName;
      if (name == null) return null;
      return Uri.https('play.google.com', '/store/apps/developer', {'id': name});
    }
    return Uri.parse(appleDeveloperUrl);
  }

  /// Whether the standard Apple EULA applies to this build.
  ///
  /// It does not on Android. Apple's "Licensed Application End User
  /// Licence Agreement" is a term of *its* distribution agreement;
  /// linking it from a Play build presents an Android user with a
  /// contract that has nothing to do with how they obtained the app.
  /// Play's equivalent terms are accepted in the store, not in the app.
  static bool get showsAppleEula =>
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Which store this build came from.
  ///
  /// [defaultTargetPlatform] rather than `dart:io`'s `Platform`, because
  /// the latter reports the *host* in a widget test — Windows here —
  /// which is neither store, and cannot be overridden. This one can, so
  /// a test can assert what each platform actually shows.
  static bool get isAndroid =>
      defaultTargetPlatform == TargetPlatform.android;

  static const appleEulaUrl =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
}
