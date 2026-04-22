import 'constants.dart';

/// Pure utility functions shared across the app.
///
/// No Flutter imports — these are plain Dart helpers.
class AppUtils {
  AppUtils._();

  /// Converts a time (hour + optional minutes) to a vertical pixel offset
  /// relative to the top of the timeline.
  static double timeToOffset(int hour, [int minutes = 0]) {
    final hoursFromStart = hour - AppConstants.dayStartHour;
    return (hoursFromStart * AppConstants.hourHeight) +
        (minutes / 60.0 * AppConstants.hourHeight);
  }

  /// Formats an hour integer (0–23) as a 12-hour label, e.g. "6 AM", "1 PM".
  static String formatHourLabel(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
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

  /// Returns a 3-letter month abbreviation for [DateTime.month] (1 = Jan).
  static String monthAbbrev(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[month - 1];
  }
}
