import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'services/calendar_source.dart';
import 'services/device_calendar_source.dart';
import 'services/local_day_repository.dart';
import 'services/recurring_repository.dart';
import 'services/settings_repository.dart';
import 'state/day_planner_model.dart';
import 'state/day_planner_provider.dart';
import 'state/settings_model.dart';
import 'state/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsModel(repository: LocalSettingsRepository());
  await settings.load();

  // The phone's calendar store exists only on Android and iOS.
  final onPhone =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  final CalendarSource calendar = onPhone
      ? DeviceCalendarSource()
      : const NoCalendarSource();

  final model =
      DayPlannerModel(
          repository: LocalDayRepository(),
          calendarSource: calendar,
          recurringRepository: LocalRecurringRepository(),
        )
        ..outcomeCap = settings.settings.outcomeCap
        ..calendarIds = settings.settings.selectedCalendarIds
        ..setWorkday(
          settings.settings.workdayStartHour,
          settings.settings.workdayEndHour,
        )
        ..setBufferMinutes(settings.settings.bufferMinutes);
  settings.addListener(() {
    model.outcomeCap = settings.settings.outcomeCap;
    model.setWorkday(
      settings.settings.workdayStartHour,
      settings.settings.workdayEndHour,
    );
    model.setBufferMinutes(settings.settings.bufferMinutes);
    final ids = settings.settings.selectedCalendarIds;
    if (ids != model.calendarIds) {
      model.calendarIds = ids;
      model.refreshCalendar();
    }
  });
  await model.loadDate(DateTime.now());

  runApp(
    SettingsProvider(
      model: settings,
      child: DayPlannerProvider(model: model, child: const HyperDayApp()),
    ),
  );
}
