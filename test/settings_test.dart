import 'package:flutter_test/flutter_test.dart';

import 'package:planner/core/constants.dart';
import 'package:planner/models/settings.dart';
import 'package:planner/state/settings_model.dart';

void main() {
  test('workday round-trips through JSON', () {
    const s = Settings(workdayStartHour: 7, workdayEndHour: 19);
    final back = Settings.fromJson(s.toJson());
    expect(back.workdayStartHour, 7);
    expect(back.workdayEndHour, 19);
  });

  test('an invalid or missing workday falls back to the default', () {
    for (final json in [
      <String, dynamic>{},
      {'workdayStartHour': 18, 'workdayEndHour': 9},
      {'workdayStartHour': -1, 'workdayEndHour': 9},
      {'workdayStartHour': 9, 'workdayEndHour': 25},
    ]) {
      final s = Settings.fromJson(json);
      expect(s.workdayStartHour, AppConstants.defaultWorkdayStartHour);
      expect(s.workdayEndHour, AppConstants.defaultWorkdayEndHour);
    }
  });

  test('setWorkday ignores a start at or after the end', () {
    final model = SettingsModel()..setWorkday(10, 10);
    expect(
      model.settings.workdayStartHour,
      AppConstants.defaultWorkdayStartHour,
    );
    model.setWorkday(6, 24);
    expect(model.settings.workdayEndHour, 24);
  });
}
