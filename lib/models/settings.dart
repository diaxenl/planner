import 'package:flutter/material.dart';

import '../core/constants.dart';

/// Immutable user preferences.
class Settings {
  const Settings({
    this.themeMode = ThemeMode.dark,
    this.outcomeCap = AppConstants.defaultOutcomeCap,
    this.selectedCalendarIds,
    this.workdayStartHour = AppConstants.defaultWorkdayStartHour,
    this.workdayEndHour = AppConstants.defaultWorkdayEndHour,
  });

  /// Dark by default.
  final ThemeMode themeMode;

  /// Maximum Outcomes per day (see [AppConstants.minOutcomeCap] /
  /// [AppConstants.maxOutcomeCap]).
  final int outcomeCap;

  /// Calendars to import meetings from. `null` means all calendars.
  final Set<String>? selectedCalendarIds;

  /// Workday hours (0–24, start before end). Work is planned only inside
  /// them.
  final int workdayStartHour;
  final int workdayEndHour;

  /// Whether [start]–[end] is a valid workday.
  static bool isValidWorkday(int start, int end) =>
      start >= 0 && end <= 24 && start < end;

  Settings copyWith({
    ThemeMode? themeMode,
    int? outcomeCap,
    Set<String>? Function()? selectedCalendarIds,
    int? workdayStartHour,
    int? workdayEndHour,
  }) {
    return Settings(
      themeMode: themeMode ?? this.themeMode,
      outcomeCap: outcomeCap ?? this.outcomeCap,
      selectedCalendarIds: selectedCalendarIds != null
          ? selectedCalendarIds()
          : this.selectedCalendarIds,
      workdayStartHour: workdayStartHour ?? this.workdayStartHour,
      workdayEndHour: workdayEndHour ?? this.workdayEndHour,
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'outcomeCap': outcomeCap,
    'selectedCalendarIds': selectedCalendarIds?.toList(),
    'workdayStartHour': workdayStartHour,
    'workdayEndHour': workdayEndHour,
  };

  /// Lenient: any missing or invalid field falls back to its default.
  static Settings fromJson(Map<String, dynamic> json) {
    const defaults = Settings();
    final themeMode = ThemeMode.values
        .where((m) => m.name == json['themeMode'])
        .firstOrNull;
    final cap = json['outcomeCap'];
    final ids = json['selectedCalendarIds'];
    final start = json['workdayStartHour'];
    final end = json['workdayEndHour'];
    final validWorkday =
        start is int && end is int && isValidWorkday(start, end);
    return Settings(
      themeMode: themeMode ?? defaults.themeMode,
      outcomeCap:
          cap is int &&
              cap >= AppConstants.minOutcomeCap &&
              cap <= AppConstants.maxOutcomeCap
          ? cap
          : defaults.outcomeCap,
      selectedCalendarIds: ids is List ? ids.whereType<String>().toSet() : null,
      workdayStartHour: validWorkday ? start : defaults.workdayStartHour,
      workdayEndHour: validWorkday ? end : defaults.workdayEndHour,
    );
  }
}
