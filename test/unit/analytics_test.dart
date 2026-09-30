import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lingoquest/core/analytics/analytics.dart';
import 'package:lingoquest/core/analytics/analytics_events.dart';
import 'package:lingoquest/core/analytics/analytics_service.dart';
import 'package:lingoquest/core/analytics/screen_tracker.dart';
import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/data/models/pro_entitlement.dart';

/// The analytics layer's own rules, tested without Firebase.
///
/// The value here is not that events fire — it is that they fire *once*,
/// carry no personal data, and never take the app down when the
/// platform underneath them does.
Route<void> _route(String path) =>
    PageRouteBuilder(
      settings: RouteSettings(name: path),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
    );

void main() {
  group('never taking the app down', () {
    test('the no-op recorder answers every call', () async {
      const a = NoopAnalytics();
      // Nothing here should throw, and nothing should be recorded.
      await a.screenView('home');
      await a.screenTime('home', const Duration(seconds: 4));
      await a.logEvent('anything', const {'x': 1});
      await a.setUserProperty('k', 'v');
      expect(a.isEnabled, isFalse);
    });

    test('a recorder with no Firebase behind it still satisfies the API', () {
      // The app holds an AnalyticsService, not a FirebaseAnalytics, so a
      // build with no Firebase project is a type-level non-event.
      const AnalyticsService a = NoopAnalytics();
      expect(a, isA<AnalyticsService>());
    });
  });

  group('percentages', () {
    test('are whole, clamped, and safe at zero', () {
      expect(percent(0, 0), 0);
      expect(percent(5, 0), 0);
      expect(percent(1, 3), 33);
      expect(percent(2, 3), 67);
      expect(percent(3, 3), 100);
      // More done than total should never report 140%.
      expect(percent(7, 5), 100);
      expect(percent(-1, 5), 0);
    });
  });

  group('lesson buckets', () {
    test('stay coarse, so the property is groupable', () {
      expect(lessonBucket(0), '0');
      expect(lessonBucket(1), '1-5');
      expect(lessonBucket(5), '1-5');
      expect(lessonBucket(6), '6-20');
      expect(lessonBucket(20), '6-20');
      expect(lessonBucket(21), '21-50');
      expect(lessonBucket(50), '21-50');
      expect(lessonBucket(51), '50+');
      expect(lessonBucket(9999), '50+');
    });
  });

  group('subscription status', () {
    test('maps every entitlement state to one countable value', () async {
      for (final (status, expected) in const [
        (EntitlementStatus.notSubscribed, 'free'),
        (EntitlementStatus.trialActive, 'trial'),
        (EntitlementStatus.subscribedActive, 'subscribed'),
        (EntitlementStatus.expired, 'expired'),
      ]) {
        final a = RecordingAnalytics();
        await a.setSubscriptionStatus(status);
        expect(
          a.userProperties[AnalyticsUserProperty.subscriptionStatus],
          expected,
        );
      }
    });
  });

  group('event payloads', () {
    test('a completed lesson carries progress, not content', () async {
      final a = RecordingAnalytics();
      await a.lessonCompleted(
        language: 'es',
        lessonId: 'es_u1_l1',
        correctAnswers: 8,
        totalQuestions: 10,
        xpEarned: 40,
        isPerfect: false,
        duration: const Duration(seconds: 95),
      );

      final p = a.paramsFor(AnalyticsEvent.lessonCompleted).single;
      expect(p[AnalyticsParam.language], 'es');
      expect(p[AnalyticsParam.lessonId], 'es_u1_l1');
      expect(p[AnalyticsParam.completionPercent], 80);
      expect(p[AnalyticsParam.durationSeconds], 95);

      // Nothing that identifies a person or reproduces what they typed.
      expect(p.keys, isNot(contains('name')));
      expect(p.keys, isNot(contains('email')));
      expect(p.keys, isNot(contains('answer')));
    });

    test('abandonment records where the learner stopped', () async {
      final a = RecordingAnalytics();
      await a.lessonAbandoned(
        language: 'de',
        lessonId: 'de_u1_l2',
        lastExerciseIndex: 3,
        totalQuestions: 12,
        lastExerciseType: ExerciseType.speaking,
        duration: const Duration(seconds: 40),
      );

      final p = a.paramsFor(AnalyticsEvent.lessonAbandoned).single;
      // The whole point of the event: which exercise lost them.
      expect(p[AnalyticsParam.lastExerciseIndex], 3);
      expect(p[AnalyticsParam.lastExerciseType], 'speaking');
      expect(p[AnalyticsParam.completionPercent], 25);
    });

    test('a restore is reported as a restore, not a new sale', () async {
      final a = RecordingAnalytics();
      await a.purchaseSuccess(plan: 'Monthly', restored: true);

      expect(a.countOf(AnalyticsEvent.restoreSuccess), 1);
      expect(a.countOf(AnalyticsEvent.purchaseSuccess), 0);
    });

    test('a failure carries a reason code, never the store message', () async {
      final a = RecordingAnalytics();
      await a.purchaseFailed(plan: 'Yearly', reason: 'network');

      final p = a.paramsFor(AnalyticsEvent.purchaseFailed).single;
      expect(p[AnalyticsParam.reason], 'network');
      // A raw store message is unbounded developer text; one bucket per
      // phrasing would make the metric uncountable.
      expect((p[AnalyticsParam.reason]! as String).length, lessThan(30));
    });
  });

  group('screen tracking', () {
    late RecordingAnalytics analytics;
    late ScreenTracker tracker;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      analytics = RecordingAnalytics();
      tracker = ScreenTracker(analytics);
    });

    tearDown(() => tracker.dispose());

    test('a route push is one screen view', () {
      tracker.didPush(_route('/home'), null);
      expect(analytics.countOf('screen_view'), 1);
      expect(
        analytics.paramsFor('screen_view').single[AnalyticsParam.screenName],
        'home',
      );
    });

    test('an unmapped route is not a screen', () {
      // Dialogs and helper routes push and pop constantly; counting them
      // would bury the screens that matter.
      tracker.didPush(_route('/some/dialog'), null);
      tracker.didPush(_route(''), null);
      expect(analytics.countOf('screen_view'), 0);
    });

    test('pushing the same screen twice does not re-count it', () {
      final route = _route('/home');
      tracker.didPush(route, null);
      tracker.didPush(route, null);
      expect(analytics.countOf('screen_view'), 1);
    });

    test('opening the paywall records where it was opened from', () {
      tracker.didPush(_route('/path'), null);
      tracker.didPush(_route('/premium'), null);

      final p = analytics.paramsFor(AnalyticsEvent.paywallViewed).single;
      // A paywall reached from a locked lesson converts very differently
      // from one opened out of Settings.
      expect(p[AnalyticsParam.sourceScreen], 'path');
    });

    test('the paywall opened first says so rather than guessing', () {
      tracker.didPush(_route('/premium'), null);
      expect(
        analytics.paramsFor(AnalyticsEvent.paywallViewed).single[
            AnalyticsParam.sourceScreen],
        'unknown',
      );
    });

    test('a visit too short to be a visit sends no duration', () {
      tracker.didPush(_route('/splash'), null);
      tracker.didReplace(newRoute: _route('/home'), oldRoute: _route('/splash'));

      // Passing through the splash on the way to Home is not a visit,
      // and a pile of one-second readings drags every average down.
      expect(analytics.countOf(AnalyticsEvent.screenTime), 0);
    });

    test('backgrounding stops the clock', () async {
      tracker.didPush(_route('/home'), null);
      tracker.didChangeAppLifecycleState(AppLifecycleState.paused);

      // A phone left face-down overnight must not report a fourteen-hour
      // visit. Nothing is sent on backgrounding either — the learner has
      // left the app, not the screen.
      expect(analytics.countOf(AnalyticsEvent.screenTime), 0);

      tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(analytics.countOf(AnalyticsEvent.screenTime), 0);
    });

    test('disposal closes whatever was open', () async {
      tracker.didPush(_route('/home'), null);
      await Future<void>.delayed(const Duration(seconds: 1));
      tracker.dispose();

      // The visit still happened, so it is still reported.
      final times = analytics.paramsFor(AnalyticsEvent.screenTime);
      expect(times, hasLength(1));
      expect(times.single[AnalyticsParam.screenName], 'home');
    });
  });

  group('the screen-name table', () {
    test('maps the paths the router actually declares', () {
      expect(screenNameForPath('/home'), AnalyticsScreen.home);
      expect(screenNameForPath('/premium'), AnalyticsScreen.premium);
      expect(screenNameForPath('/lesson/play'), AnalyticsScreen.lessonPlayer);
      // An unmapped path reports absent rather than a mangled name.
      expect(screenNameForPath('/not/a/route'), isNull);
    });

    test('no two screens share a name', () {
      // A duplicate would silently merge two screens into one metric.
      final names = <String>[];
      for (final path in const [
        '/home', '/path', '/fun', '/premium', '/settings',
        '/lesson/intro', '/lesson/play', '/lesson/complete',
        '/statistics', '/achievements', '/languages',
      ]) {
        final name = screenNameForPath(path);
        expect(name, isNotNull, reason: '$path is not mapped');
        names.add(name!);
      }
      expect(names.toSet(), hasLength(names.length));
    });
  });
}
