import 'package:flutter/widgets.dart';

import 'analytics.dart';
import 'analytics_events.dart';
import 'analytics_service.dart';

/// Records which screen is on top and how long it stays there.
///
/// Hooked up as a `NavigatorObserver` on the router, so it sees real
/// route changes rather than widget rebuilds. That distinction is the
/// whole design: a Riverpod screen rebuilds many times a second while
/// nothing about it has changed, and a `screen_view` per build would be
/// both wrong and expensive.
///
/// ## Where the time comes from
///
/// One clock, started when a route reaches the top and read when it
/// leaves. [AnalyticsEvent.screenTime] is sent once per visit, never per
/// tick.
///
/// Backgrounding pauses it. Without that, a phone left face-down
/// overnight on the Home screen reports a fourteen-hour visit, and a
/// single one of those drags an average far enough to make the metric
/// meaningless.
///
/// ## What counts as a screen
///
/// Only routes with a name in [AnalyticsScreen] — the router sets those
/// through `RouteSettings.name`. Dialogs, sheets and unnamed helper
/// routes are ignored: they push and pop constantly, and counting them
/// would bury the screens that matter.
class ScreenTracker extends NavigatorObserver with WidgetsBindingObserver {
  final AnalyticsService _analytics;

  /// Visits shorter than this are dropped.
  ///
  /// Passing through a route on the way to another — the splash on a
  /// warm start, a results screen being replaced — is not a visit, and
  /// a pile of one-second readings pulls every average down.
  static const _minimumVisit = Duration(milliseconds: 900);

  String? _current;

  /// The screen open immediately before [_current]. Only used to answer
  /// "where was the paywall opened from", which is the difference
  /// between a conversion number and a useful one.
  String? _previous;

  DateTime? _since;

  /// Accumulated time on [_current] before the app was last backgrounded.
  Duration _carried = Duration.zero;

  ScreenTracker(this._analytics) {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    // Whatever is open when the app is torn down still happened.
    _close();
    WidgetsBinding.instance.removeObserver(this);
  }

  // ---- navigation ------------------------------------------------------

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _open(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Popping reveals whatever was underneath, which becomes the screen
    // being looked at.
    _close();
    if (previousRoute != null) _open(previousRoute, isReturn: true);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _close();
    if (newRoute != null) _open(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_nameOf(route) != _current) return;
    _close();
    if (previousRoute != null) _open(previousRoute, isReturn: true);
  }

  // ---- lifecycle -------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Restart the clock, keeping what was already banked.
        if (_current != null) _since = DateTime.now();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Bank the time so far and stop counting. No event yet — the
        // learner has not left the screen, only the app, and they will
        // usually come back to the same one.
        _carried += _elapsed();
        _since = null;
    }
  }

  // ---- internals -------------------------------------------------------

  /// A route's analytics name, or null if it is not a tracked screen.
  ///
  /// go_router puts the path in `RouteSettings.name`, so the path is
  /// what maps to a screen name.
  String? _nameOf(Route<dynamic>? route) {
    final path = route?.settings.name;
    if (path == null || path.isEmpty) return null;
    return screenNameForPath(path);
  }

  void _open(Route<dynamic> route, {bool isReturn = false}) {
    final name = _nameOf(route);
    if (name == null) return;
    // Re-entering the screen already being timed — a redirect landing
    // back where it started — is not a new visit.
    if (name == _current && _since != null) return;

    _previous = _current;
    _current = name;
    _since = DateTime.now();
    _carried = Duration.zero;

    // Returning to a screen is a genuine second view: it is how "people
    // bounce off the paywall and come back" shows up at all.
    _analytics.screenView(name);

    // The paywall gets a second, domain-level event carrying where it
    // was opened from — a paywall reached from a locked lesson converts
    // very differently from one opened out of Settings, and without the
    // source the conversion rate is a single number that cannot be
    // acted on.
    //
    // Emitted here rather than from the Pro screen or its eight callers
    // for two reasons: the screen is a `ConsumerWidget`, so anything in
    // its `build` would fire again on every rebuild; and a nineth entry
    // point added later would silently go uncounted. Navigation is the
    // one place that sees every arrival exactly once.
    if (name == AnalyticsScreen.premium) {
      _analytics.paywallViewed(source: _previous ?? 'unknown');
    }
  }

  void _close() {
    final name = _current;
    if (name == null) return;

    final total = _carried + _elapsed();
    _current = null;
    _since = null;
    _carried = Duration.zero;

    if (total >= _minimumVisit) {
      _analytics.screenTime(name, total);
    }
  }

  Duration _elapsed() {
    final since = _since;
    if (since == null) return Duration.zero;
    return DateTime.now().difference(since);
  }
}

/// Maps a router path to the screen name reported for it.
///
/// A table rather than a derived string, so a path can be renamed
/// without silently renaming a metric that has months of history behind
/// it — and so a new route that nobody mapped shows up as absent rather
/// than as a mangled name.
String? screenNameForPath(String path) => _byPath[path];

const Map<String, String> _byPath = {
  '/splash': AnalyticsScreen.splash,
  '/welcome': AnalyticsScreen.welcome,
  '/welcome/explainer': AnalyticsScreen.onboardingExplainer,
  '/onboarding/name': AnalyticsScreen.nameEntry,
  '/onboarding/language': AnalyticsScreen.languageSelection,
  '/onboarding/goal': AnalyticsScreen.goalSelection,
  '/onboarding/daily-goal': AnalyticsScreen.dailyGoalSelection,
  '/onboarding/placement': AnalyticsScreen.placement,

  '/home': AnalyticsScreen.home,
  '/path': AnalyticsScreen.path,
  '/fun': AnalyticsScreen.fun,

  '/preview/vocab': AnalyticsScreen.vocabPreview,
  '/fun/intro': AnalyticsScreen.funGameIntro,
  '/fun/survival-intro': AnalyticsScreen.funSurvivalIntro,
  '/fun/play': AnalyticsScreen.funGamePlay,
  '/fun/results': AnalyticsScreen.funRoundResults,
  '/fun/word-match/play': AnalyticsScreen.funWordMatchPlay,
  '/fun/word-match/results': AnalyticsScreen.funWordMatchResults,
  '/fun/sentence-builder/play': AnalyticsScreen.funSentenceBuilderPlay,
  '/fun/sentence-builder/results': AnalyticsScreen.funSentenceBuilderResults,
  '/fun/memory-match/play': AnalyticsScreen.funMemoryMatchPlay,
  '/fun/memory-match/results': AnalyticsScreen.funMemoryMatchResults,
  '/fun/conversation/play': AnalyticsScreen.funConversationPlay,
  '/fun/conversation/results': AnalyticsScreen.funConversationResults,

  '/lesson/intro': AnalyticsScreen.lessonIntro,
  '/lesson/play': AnalyticsScreen.lessonPlayer,
  '/lesson/complete': AnalyticsScreen.lessonComplete,
  '/lesson/review': AnalyticsScreen.lessonReview,
  '/lesson/xp-reward': AnalyticsScreen.xpReward,
  '/lesson/streak': AnalyticsScreen.streakResult,
  '/lesson/daily-goal': AnalyticsScreen.dailyGoalResult,
  '/lesson/achievement-unlock': AnalyticsScreen.achievementUnlock,

  '/achievements': AnalyticsScreen.achievements,
  '/statistics': AnalyticsScreen.statistics,
  '/languages': AnalyticsScreen.languages,

  '/settings': AnalyticsScreen.settings,
  '/settings/notifications': AnalyticsScreen.notificationSettings,
  '/settings/account': AnalyticsScreen.accountSettings,
  '/premium': AnalyticsScreen.premium,
};
