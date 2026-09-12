import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:url_launcher/url_launcher.dart';

/// Opens the store page where a subscription can be changed or
/// cancelled.
///
/// Both stores require this. Apple's Guideline 3.1.2 expects an app
/// selling an auto-renewable subscription to tell the buyer how to
/// manage it, and Google asks the same; in practice a line of prose
/// saying "manage it in your account settings" is not the same thing as
/// a link that goes there, and a subscriber who cannot find the cancel
/// button asks for a refund and leaves a one-star review instead.
///
/// Neither platform lets an app cancel on the buyer's behalf, and
/// neither should: the cancellation flow belongs to the store, which is
/// also the only party that knows the real renewal state. All this does
/// is get them there in one tap.
class SubscriptionManager {
  /// The Android application id. Play needs it to resolve which app's
  /// subscription to open.
  ///
  /// Hard-coded because it is a build-time fact with no runtime source
  /// short of adding a package-info plugin for one string. It must match
  /// `namespace`/`applicationId` in `android/app/build.gradle.kts` — if
  /// that ever changes, this changes with it.
  static const androidPackage = 'com.lernova.lernova';

  final Future<bool> Function(Uri, {LaunchMode mode}) _launch;
  final String _platform;

  SubscriptionManager({
    Future<bool> Function(Uri, {LaunchMode mode})? launch,
    @visibleForTesting String? platformOverride,
  })  : _launch = launch ?? _defaultLaunch,
        _platform = platformOverride ?? _currentPlatform;

  static Future<bool> _defaultLaunch(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) =>
      launchUrl(uri, mode: mode);

  static String get _currentPlatform {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'other';
  }

  /// The store's subscription-management page for this app.
  ///
  /// iOS has one page for every subscription on the account and takes no
  /// product id. Play opens the specific subscription when given the
  /// product, and falls back to the account's subscription list when the
  /// product is unknown — which it is for an entitlement restored before
  /// the product id was recorded.
  Uri? manageUrl({String? productId}) {
    switch (_platform) {
      case 'ios':
        return Uri.parse('https://apps.apple.com/account/subscriptions');
      case 'android':
        final base = 'https://play.google.com/store/account/subscriptions';
        if (productId == null) return Uri.parse(base);
        return Uri.parse('$base?sku=$productId&package=$androidPackage');
      default:
        return null;
    }
  }

  /// Sends the learner to that page. False when there is nowhere to send
  /// them — a desktop or web build, or a launcher that refused.
  Future<bool> openManageSubscriptions({String? productId}) async {
    final uri = manageUrl(productId: productId);
    if (uri == null) return false;
    try {
      return await _launch(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // A missing browser or a store app that will not open is not worth
      // crashing over; the caller says so instead.
      return false;
    }
  }
}
