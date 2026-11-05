import 'package:flutter/material.dart';

import '../core/constants.dart';

/// Immutable user preferences.
class Settings {
  const Settings({
    this.themeMode = ThemeMode.dark,
    this.outcomeCap = AppConstants.defaultOutcomeCap,
    this.selectedCalendarIds,
  });

  /// Dark by default.
  final ThemeMode themeMode;

  /// Maximum Outcomes per day (see [AppConstants.minOutcomeCap] /
  /// [AppConstants.maxOutcomeCap]).
  final int outcomeCap;

  /// Calendars to import meetings from. `null` means all calendars.
  final Set<String>? selectedCalendarIds;

  Settings copyWith({
    ThemeMode? themeMode,
    int? outcomeCap,
    Set<String>? Function()? selectedCalendarIds,
  }) {
    return Settings(
      themeMode: themeMode ?? this.themeMode,
      outcomeCap: outcomeCap ?? this.outcomeCap,
      selectedCalendarIds: selectedCalendarIds != null
          ? selectedCalendarIds()
          : this.selectedCalendarIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'outcomeCap': outcomeCap,
    'selectedCalendarIds': selectedCalendarIds?.toList(),
  };

  /// Lenient: any missing or invalid field falls back to its default.
  static Settings fromJson(Map<String, dynamic> json) {
    const defaults = Settings();
    final themeMode = ThemeMode.values
        .where((m) => m.name == json['themeMode'])
        .firstOrNull;
    final cap = json['outcomeCap'];
    final ids = json['selectedCalendarIds'];
    return Settings(
      themeMode: themeMode ?? defaults.themeMode,
      outcomeCap:
          cap is int &&
              cap >= AppConstants.minOutcomeCap &&
              cap <= AppConstants.maxOutcomeCap
          ? cap
          : defaults.outcomeCap,
      selectedCalendarIds: ids is List ? ids.whereType<String>().toSet() : null,
    );
  }
}
