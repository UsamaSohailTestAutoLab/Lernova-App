import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'analytics_events.dart';

/// What the app records about how it is used.
///
/// An interface rather than a direct `FirebaseAnalytics` call at every
/// site, for three reasons that all showed up while building this:
///
/// 1. **It can be off.** Firebase needs `google-services.json` on
///    Android and `GoogleService-Info.plist` on iOS. Neither is in this
///    repository — they are generated per Firebase project — so a build
///    without them must still run. [NoopAnalytics] is what makes a
///    missing config a silent no-op instead of a crash on launch.
/// 2. **It must never be the reason something breaks.** Every method
///    here swallows its own failures. A dropped event is a gap in a
///    chart; an exception thrown out of a tap handler is a broken app.
/// 3. **It is testable.** [RecordingAnalytics] lets a test assert that
///    finishing a lesson records one completion, without a network or a
///    Firebase project.
abstract class AnalyticsService {
  /// A screen became the top route.
  Future<void> screenView(String screenName, {String? screenClass});

  /// A screen was left, after [duration] on it.
  Future<void> screenTime(String screenName, Duration duration);

  /// Any other event. Prefer the named helpers below.
  Future<void> logEvent(String name, [Map<String, Object?> params]);

  /// Sets a property every future event is sliced by.
  Future<void> setUserProperty(String name, String? value);

  /// Whether events actually leave the device. False when Firebase is
  /// not configured — worth surfacing in a debug screen so "no data in
  /// the console" can be told apart from "no events fired".
  bool get isEnabled;
}

/// The real one.
class FirebaseAnalyticsService implements AnalyticsService {
  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsService(this._analytics);

  @override
  bool get isEnabled => true;

  @override
  Future<void> screenView(String screenName, {String? screenClass}) =>
      _guard(() => _analytics.logScreenView(
            screenName: screenName,
            screenClass: screenClass ?? screenName,
          ));

  @override
  Future<void> screenTime(String screenName, Duration duration) =>
      logEvent(AnalyticsEvent.screenTime, {
        AnalyticsParam.screenName: screenName,
        AnalyticsParam.durationSeconds: duration.inSeconds,
      });

  @override
  Future<void> logEvent(String name, [Map<String, Object?> params = const {}]) =>
      _guard(() => _analytics.logEvent(
            name: name,
            parameters: _clean(params),
          ));

  @override
  Future<void> setUserProperty(String name, String? value) =>
      _guard(() => _analytics.setUserProperty(name: name, value: value));

  /// Runs [body], and lets nothing out.
  ///
  /// Firebase's plugin can throw for reasons that have nothing to do
  /// with the caller — a platform channel not ready during the first
  /// frame, a device with Play Services disabled, an app being killed
  /// mid-flush. None of those are worth a crash, and none are worth a
  /// log line in release either: the failure mode is a missing data
  /// point, and a user's console is not the place to report it.
  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('analytics dropped an event: $error');
        debugPrintStack(stackTrace: stack, maxFrames: 4);
      }
    }
  }

  /// Drops nulls and coerces to the types Firebase accepts.
  ///
  /// The SDK takes only `String` and `num`. A `bool` passed straight
  /// through is rejected at runtime and the whole event is lost, so
  /// booleans become `'true'` / `'false'` here rather than at twenty
  /// call sites. Strings are cut to Firebase's 100-character ceiling —
  /// nothing this app sends is near it, but a truncated value is a
  /// better failure than a rejected event.
  static Map<String, Object> _clean(Map<String, Object?> params) {
    final out = <String, Object>{};
    params.forEach((key, value) {
      if (value == null) return;
      if (value is num) {
        out[key] = value;
      } else if (value is bool) {
        out[key] = value ? 'true' : 'false';
      } else {
        final text = value.toString();
        out[key] = text.length <= 100 ? text : text.substring(0, 100);
      }
    });
    return out;
  }
}

/// Analytics that go nowhere.
///
/// Used when Firebase is not configured, and in every test that is not
/// about analytics. Every method returns immediately, so a build with no
/// Firebase project behaves exactly like one with analytics disabled
/// rather than one that is broken.
class NoopAnalytics implements AnalyticsService {
  const NoopAnalytics();

  @override
  bool get isEnabled => false;

  @override
  Future<void> screenView(String screenName, {String? screenClass}) async {}

  @override
  Future<void> screenTime(String screenName, Duration duration) async {}

  @override
  Future<void> logEvent(String name, [Map<String, Object?> params = const {}]) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {}
}

/// Keeps events in memory so a test can read them back.
@visibleForTesting
class RecordingAnalytics implements AnalyticsService {
  final List<({String name, Map<String, Object?> params})> events = [];
  final Map<String, String?> userProperties = {};

  @override
  bool get isEnabled => true;

  @override
  Future<void> screenView(String screenName, {String? screenClass}) async {
    events.add((
      name: 'screen_view',
      params: {
        AnalyticsParam.screenName: screenName,
        AnalyticsParam.screenClass: screenClass ?? screenName,
      },
    ));
  }

  @override
  Future<void> screenTime(String screenName, Duration duration) async {
    events.add((
      name: AnalyticsEvent.screenTime,
      params: {
        AnalyticsParam.screenName: screenName,
        AnalyticsParam.durationSeconds: duration.inSeconds,
      },
    ));
  }

  @override
  Future<void> logEvent(String name, [Map<String, Object?> params = const {}]) async {
    events.add((name: name, params: params));
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    userProperties[name] = value;
  }

  /// Every event recorded under [name], in order.
  List<Map<String, Object?>> paramsFor(String name) =>
      events.where((e) => e.name == name).map((e) => e.params).toList();

  int countOf(String name) => events.where((e) => e.name == name).length;

  void clear() {
    events.clear();
    userProperties.clear();
  }
}

/// Brings Firebase up, or decides to do without it.
///
/// Called once from `main()`. A missing or malformed configuration is
/// treated as "analytics off", not as a failure to launch: shipping a
/// build whose first action is to crash because a JSON file is absent
/// would be a far worse bug than having no usage data.
///
/// ## Turning it on
///
/// 1. Create a Firebase project and register the Android app with the
///    applicationId from `android/app/build.gradle.kts`
///    (`com.lernova.lernova`).
/// 2. Put the downloaded `google-services.json` in `android/app/`.
/// 3. Add the Google services Gradle plugin — see `docs/ANALYTICS.md`.
/// 4. For iOS, register the bundle id and drop
///    `GoogleService-Info.plist` into `ios/Runner/` via Xcode.
///
/// Both files carry project identifiers rather than secrets, but they
/// are environment configuration, so they are gitignored here and
/// belong in whatever the team uses for build config.
Future<AnalyticsService> initAnalytics() async {
  try {
    await Firebase.initializeApp();
    final analytics = FirebaseAnalytics.instance;
    // Off in debug so a developer's own tapping around does not land in
    // the same numbers as real usage. DebugView still receives
    // everything — that is a separate switch, set with adb. See
    // docs/ANALYTICS.md.
    await analytics.setAnalyticsCollectionEnabled(!kDebugMode);
    return FirebaseAnalyticsService(analytics);
  } catch (error) {
    if (kDebugMode) {
      debugPrint(
        'Firebase is not configured, so analytics are off. '
        'The app runs normally. $error',
      );
    }
    return const NoopAnalytics();
  }
}
