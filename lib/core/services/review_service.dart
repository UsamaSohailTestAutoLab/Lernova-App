import 'package:in_app_review/in_app_review.dart';

import 'store_links.dart';

/// The App Store id for LingoQuest.
///
/// Kept as an alias so existing callers keep working; the value lives in
/// [StoreLinks.appStoreId] alongside the Play equivalents, because the
/// two stores' identifiers are the same kind of fact and drifting them
/// apart is how one platform ends up pointing at the other's shop.
const String? kAppStoreId = StoreLinks.appStoreId;

/// The one place the app asks a store for a review.
///
/// Wrapped rather than called inline so the prompt policy above it can
/// be tested without a store, and so there is a single place where the
/// platform rules are written down:
///
///  * **Only the system prompt.** Apple's guidelines require
///    `SKStoreReviewController`, which this plugin wraps. A custom
///    "rate us" dialog — even one that then opens the real prompt — is
///    a rejection risk, and one that imitates the system sheet is a
///    certain one.
///  * **iOS decides whether anything appears.** `requestReview` is a
///    request, not a command: the system shows it at most three times
///    per year per user, suppresses it entirely if the learner has
///    turned ratings off in Settings, and gives no callback either way.
///    Nothing in this app may depend on the prompt having been seen.
///  * **A button must not call `requestReview`.** When someone taps
///    "Rate LingoQuest" they have asked for the page, and a request that
///    silently does nothing reads as a broken button. That path uses
///    [openStoreListing] instead, which always opens something.
class ReviewService {
  final InAppReview _inAppReview;

  ReviewService({InAppReview? inAppReview})
      : _inAppReview = inAppReview ?? InAppReview.instance;

  /// Whether the platform can show the in-app prompt at all. False on a
  /// simulator without a store account, and on unsupported platforms.
  Future<bool> isAvailable() => _inAppReview.isAvailable();

  /// Asks the system to show its rating prompt.
  ///
  /// Returns once the request has been made. It resolves whether or not
  /// anything was displayed, because the platform does not say.
  Future<void> requestReview() => _inAppReview.requestReview();

  /// Opens this build's own store listing, on the write-review page.
  ///
  /// The explicit path: the learner tapped a button asking for it, so
  /// something must open.
  ///
  /// The platforms differ in what they need, and conflating them is what
  /// sent Android users to the App Store:
  ///
  ///  * **Android** needs nothing. The plugin addresses Play by the
  ///    application id, which is known at build time. It always works.
  ///  * **iOS** needs [kAppStoreId], which Apple assigns and which
  ///    cannot be guessed. Without it there is nothing to open, so this
  ///    reports false and the caller says so rather than opening a
  ///    listing that 404s.
  ///
  /// The platform comes from [StoreLinks.isAndroid], which reads
  /// `defaultTargetPlatform` rather than `dart:io`'s `Platform`. The
  /// latter reports the *host* in a widget test — Windows here — so a
  /// test of the Android branch would silently exercise the iOS one.
  Future<bool> openStoreListing() async {
    if (StoreLinks.isAndroid) {
      await _inAppReview.openStoreListing();
      return true;
    }
    if (kAppStoreId == null) return false;
    await _inAppReview.openStoreListing(appStoreId: kAppStoreId);
    return true;
  }
}
