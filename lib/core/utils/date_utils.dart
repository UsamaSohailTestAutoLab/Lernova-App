/// Date helpers used by streak/daily-goal/leaderboard logic. Kept pure
/// and side-effect free so they're trivial to unit test.
class AppDateUtils {
  AppDateUtils._();

  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isYesterday(DateTime day, DateTime reference) {
    final ref = dateOnly(reference);
    final target = dateOnly(day);
    return ref.difference(target).inDays == 1;
  }

  static int daysBetween(DateTime a, DateTime b) {
    return dateOnly(b).difference(dateOnly(a)).inDays;
  }

  /// ISO-8601 week id, e.g. "2026-W35" — used to detect league rollover.
  static String isoWeekId(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final dayOfWeek = d.weekday; // 1 = Monday
    final thursday = d.add(Duration(days: 4 - dayOfWeek));
    final firstDayOfYear = DateTime.utc(thursday.year, 1, 1);
    final weekNumber =
        ((thursday.difference(firstDayOfYear).inDays) / 7).floor() + 1;
    return '${thursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }
}
