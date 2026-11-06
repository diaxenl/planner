// TEMPORARY persona-review harness (not part of the app). Delete after use.
import 'package:flutter/material.dart';
import 'package:planner/app.dart';
import 'package:planner/models/calendar_event.dart';
import 'package:planner/models/settings.dart';
import 'package:planner/models/task.dart';
import 'package:planner/services/calendar_source.dart';
import 'package:planner/services/day_repository.dart';
import 'package:planner/services/settings_repository.dart';
import 'package:planner/state/day_planner_model.dart';
import 'package:planner/state/day_planner_provider.dart';
import 'package:planner/state/settings_model.dart';
import 'package:planner/state/settings_provider.dart';

class MemDays implements DayRepository {
  final _d = <DateTime, List<Task>>{};
  @override
  Future<List<Task>> load(DateTime date) async => List.of(_d[date] ?? []);
  @override
  Future<void> save(DateTime date, List<Task> tasks) async => _d[date] = List.of(tasks);
}

class MemSettings implements SettingsRepository {
  Settings _s = const Settings();
  @override
  Future<Settings> load() async => _s;
  @override
  Future<void> save(Settings s) async => _s = s;
}

class FakeCalendar implements CalendarSource {
  @override
  Future<bool> requestAccess() async => true;
  @override
  Future<List<DeviceCalendarInfo>> listCalendars() async => const [
        DeviceCalendarInfo(id: 'work', name: 'Work', accountName: 'me@company.com'),
        DeviceCalendarInfo(id: 'home', name: 'Personal', accountName: 'me@gmail.com'),
      ];
  @override
  Future<List<CalendarEvent>> eventsFor(DateTime d, Set<String>? ids) async {
    CalendarEvent e(String id, String t, int h, int m, int mins, [String cal = 'work']) {
      final s = DateTime(d.year, d.month, d.day, h, m);
      return CalendarEvent(id: '$id-${d.day}', calendarId: cal, title: t, start: s, end: s.add(Duration(minutes: mins)));
    }
    if (d.weekday >= 6) return const [];
    final all = d.weekday == DateTime.thursday
        ? [
            e('a', 'Standup', 8, 30, 15), e('b', '1:1 Priya', 9, 0, 30), e('c', '1:1 Marco', 9, 30, 30),
            e('d', 'Product review', 11, 0, 60), e('e', 'Lunch w/ candidate', 12, 30, 60),
            e('f', 'Customer call — Acme', 14, 0, 60), e('g', 'Eng sync', 16, 0, 30),
            e('h', 'Kids pickup', 17, 30, 30, 'home'),
            CalendarEvent(id: 'z', calendarId: 'home', title: 'Mom birthday', start: DateTime(d.year, d.month, d.day), end: DateTime(d.year, d.month, d.day + 1), isAllDay: true),
          ]
        : [e('a', 'Standup', 8, 30, 15), e('x', 'Board meeting', 10, 0, 120), e('y', 'Team lunch', 12, 0, 60)];
    return all.where((x) => ids == null || ids.contains(x.calendarId)).toList();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsModel(repository: MemSettings());
  await settings.load();
  final model = DayPlannerModel(repository: MemDays(), calendarSource: FakeCalendar())
    ..outcomeCap = settings.settings.outcomeCap
    ..calendarIds = settings.settings.selectedCalendarIds
    ..setWorkday(settings.settings.workdayStartHour, settings.settings.workdayEndHour);
  settings.addListener(() {
    model.outcomeCap = settings.settings.outcomeCap;
    model.setWorkday(settings.settings.workdayStartHour, settings.settings.workdayEndHour);
    final ids = settings.settings.selectedCalendarIds;
    if (ids != model.calendarIds) {
      model.calendarIds = ids;
      model.refreshCalendar();
    }
  });
  await model.loadDate(DateTime.now());
  runApp(SettingsProvider(model: settings, child: DayPlannerProvider(model: model, child: const HyperDayApp())));
}
