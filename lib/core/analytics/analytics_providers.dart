import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_service.dart';
import 'screen_tracker.dart';

/// The app's analytics recorder.
///
/// Overridden in `main()` with whatever [initAnalytics] produced — the
/// real Firebase one, or [NoopAnalytics] when no Firebase project is
/// configured. The default here is the no-op, so every widget test and
/// every screenshot harness gets silence without having to say so.
final analyticsProvider = Provider<AnalyticsService>(
  (ref) => const NoopAnalytics(),
);

/// Watches the navigator and reports screen views and durations.
final screenTrackerProvider = Provider<ScreenTracker>((ref) {
  final tracker = ScreenTracker(ref.watch(analyticsProvider));
  ref.onDispose(tracker.dispose);
  return tracker;
});
