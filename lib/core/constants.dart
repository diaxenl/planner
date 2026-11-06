/// App-wide constants for HyperDay.
///
/// All magic numbers live here. Widgets import this file instead of
/// hard-coding values.
class AppConstants {
  AppConstants._();

  // ── Workday ─────────────────────────────────────────────────────────
  /// Default workday (Settings): work is planned, and free time counted,
  /// only between these hours. Meetings and set-time items may sit
  /// anywhere in the day.
  static const int defaultWorkdayStartHour = 8;
  static const int defaultWorkdayEndHour = 18; // 6 PM

  // ── Spacing ─────────────────────────────────────────────────────────
  static const double paddingSmall = 4.0;
  static const double paddingMedium = 8.0;
  static const double paddingLarge = 16.0;
  static const double paddingXLarge = 24.0;

  // ── Input validation ────────────────────────────────────────────────
  /// Maximum length for a task title.
  static const int titleMaxLength = 100;

  /// Minimum task duration in minutes.
  static const int durationMinMinutes = 5;

  /// Maximum task duration in minutes (8 hours).
  static const int durationMaxMinutes = 480;

  // ── Adaptive replanning ─────────────────────────────────────────────
  /// How often to re-check for task overruns while a task is in progress.
  static const Duration overrunCheckInterval = Duration(seconds: 30);

  /// Shortest session an Outcome is split into when it doesn't fit one
  /// free gap.
  static const int minSessionMinutes = 30;

  /// Breathing room (Settings) kept between planned items, in minutes.
  static const List<int> bufferChoices = [0, 5, 10, 15];
  static const int defaultBufferMinutes = 5;

  /// How long before a meeting the Now card warns that the running task
  /// is about to run into it.
  static const int meetingWarningMinutes = 5;

  // ── Outcomes ────────────────────────────────────────────────────────
  /// Default and allowed range for the daily outcome cap (Settings).
  static const int defaultOutcomeCap = 3;
  static const int minOutcomeCap = 1;
  static const int maxOutcomeCap = 5;
}
