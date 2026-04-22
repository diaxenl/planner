/// App-wide constants for HyperDay.
///
/// All magic numbers live here. Widgets import this file instead of
/// hard-coding values.
class AppConstants {
  AppConstants._();

  // ── Day window ──────────────────────────────────────────────────────
  /// Earliest hour shown on the timeline (inclusive).
  static const int dayStartHour = 6;

  /// Latest hour shown on the timeline (inclusive end label).
  static const int dayEndHour = 23; // 11 PM

  /// Total number of hour slots rendered on the timeline.
  static int get totalHours => dayEndHour - dayStartHour; // 17

  // ── Timeline dimensions ─────────────────────────────────────────────
  /// Fixed pixel height for one hour on the timeline.
  static const double hourHeight = 80.0;

  /// Width reserved for the hour labels on the left edge.
  static const double timeGutterWidth = 56.0;

  /// Total pixel height of the scrollable timeline area.
  static double get timelineHeight => hourHeight * totalHours;

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
}
