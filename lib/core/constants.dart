/// App-wide constants for HyperDay.
///
/// All magic numbers live here. Widgets import this file instead of
/// hard-coding values.
class AppConstants {
  AppConstants._();

  // ── Day window ──────────────────────────────────────────────────────
  /// Start of the plannable day window (inclusive).
  static const int dayStartHour = 6;

  /// End of the plannable day window (exclusive).
  static const int dayEndHour = 23; // 11 PM

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

  // ── Outcomes ────────────────────────────────────────────────────────
  /// Default and allowed range for the daily outcome cap (Settings).
  static const int defaultOutcomeCap = 3;
  static const int minOutcomeCap = 1;
  static const int maxOutcomeCap = 5;
}
