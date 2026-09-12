import 'package:in_app_review/in_app_review.dart';

/// The App Store id for LingoQuest, used to deep-link the write-review
/// page from Settings.
///
/// Deliberately null until the app is created in App Store Connect —
/// that number is assigned by Apple and cannot be guessed. With it unset
/// the Settings row tells the learner the link is not ready rather than
/// opening a wrong or dead listing.
const String? kAppStoreId = null;

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

  /// Opens the store listing's write-review page.
  ///
  /// This is the explicit path: the learner tapped a button asking for
  /// it. On iOS it needs [kAppStoreId]; without one there is nothing to
  /// open, so this reports false and the caller says so.
  Future<bool> openStoreListing() async {
    if (kAppStoreId == null) return false;
    await _inAppReview.openStoreListing(appStoreId: kAppStoreId);
    return true;
  }
}
