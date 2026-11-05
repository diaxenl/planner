/// Pure utility functions shared across the app.
///
/// No Flutter imports — these are plain Dart helpers.
class AppUtils {
  AppUtils._();

  /// Formats minutes-from-midnight as a 12-hour clock, e.g. "9:30 AM".
  static String formatClock(int minutesFromMidnight) {
    final h = (minutesFromMidnight ~/ 60) % 24;
    final m = minutesFromMidnight % 60;
    final suffix = h < 12 ? 'AM' : 'PM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $suffix';
  }

  /// Formats a duration in minutes compactly, e.g. "45m", "1h", "1h 30m".
  static String formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Formats a running timer, e.g. "4:07" or "1:12:30".
  static String formatTimer(Duration d) {
    final total = d.inSeconds.abs();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
    return '$m:$ss';
  }

  /// Returns the full weekday name for [DateTime.weekday] (1 = Monday).
  static String weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday - 1];
  }

  /// Returns the full month name for [DateTime.month] (1 = January).
  static String monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month - 1];
  }

  /// A friendly label for [date] relative to [today]: "Today",
  /// "Tomorrow", "Yesterday", or the weekday name.
  static String relativeDayLabel(DateTime date, DateTime today) {
    final d = DateTime(date.year, date.month, date.day);
    final t = DateTime(today.year, today.month, today.day);
    final diff = d.difference(t).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return weekdayName(d.weekday);
  }
}
