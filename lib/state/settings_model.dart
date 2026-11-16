import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/settings.dart';
import '../services/settings_repository.dart';

/// Holds the user's [Settings] and persists every change immediately.
class SettingsModel extends ChangeNotifier {
  SettingsModel({SettingsRepository? repository}) : _repository = repository;

  final SettingsRepository? _repository;

  Settings _settings = const Settings();
  Settings get settings => _settings;

  /// Loads saved settings from the repository (if any).
  Future<void> load() async {
    if (_repository == null) return;
    _settings = await _repository.load();
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) =>
      _update(_settings.copyWith(themeMode: mode));

  void setOutcomeCap(int cap) => _update(_settings.copyWith(outcomeCap: cap));

  void setSelectedCalendarIds(Set<String>? ids) =>
      _update(_settings.copyWith(selectedCalendarIds: () => ids));

  /// Sets the workday hours. Ignored unless start is before end.
  void setWorkday(int startHour, int endHour) {
    if (!Settings.isValidWorkday(startHour, endHour)) return;
    _update(
      _settings.copyWith(workdayStartHour: startHour, workdayEndHour: endHour),
    );
  }

  /// Sets the breathing room between planned items. Ignored unless it is
  /// one of [AppConstants.bufferChoices].
  void setBufferMinutes(int minutes) {
    if (!AppConstants.bufferChoices.contains(minutes)) return;
    _update(_settings.copyWith(bufferMinutes: minutes));
  }

  void _update(Settings next) {
    _settings = next;
    _repository?.save(next);
    notifyListeners();
  }
}
