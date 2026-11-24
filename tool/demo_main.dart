// TEMPORARY showcase-video harness (not part of the app). Delete after use.
// Today's sample meetings are placed relative to launch time.
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
  Future<void> save(DateTime date, List<Task> tasks) async =>
      _d[date] = List.of(tasks);
}

class MemSettings implements SettingsRepository {
  Settings _s = const Settings();
  @override
  Future<Settings> load() async => _s;
  @override
  Future<void> save(Settings s) async => _s = s;
}

/// Launch time (minutes from midnight), and rounded up to 5 minutes.
final int _launch = DateTime.now().hour * 60 + DateTime.now().minute;
final int _base = _launch + (5 - _launch % 5) % 5;

class FakeCalendar implements CalendarSource {
  /// Edits saved from the app, by event id: (title, start, end).
  final Map<String, (String, DateTime, DateTime)> _edits = {};

  @override
  Future<bool> updateEvent(
    CalendarEvent event, {
    required String title,
    required DateTime start,
    required DateTime end,
  }) async {
    if (event.eventId == null) return false;
    _edits[event.id] = (title, start, end);
    return true;
  }

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<bool> hasAccess() async => true;
  @override
  Future<List<DeviceCalendarInfo>> listCalendars() async => const [
    DeviceCalendarInfo(id: 'work', name: 'Work', accountName: 'me@company.com'),
    DeviceCalendarInfo(
      id: 'home',
      name: 'Personal',
      accountName: 'me@gmail.com',
    ),
  ];
  @override
  Future<List<CalendarEvent>> eventsFor(DateTime d, Set<String>? ids) async {
    CalendarEvent e(
      String id,
      String t,
      int h,
      int m,
      int mins, [
      String cal = 'work',
    ]) {
      final s = DateTime(d.year, d.month, d.day, h, m);
      final key = '$id-${d.day}';
      final edit = _edits[key];
      return CalendarEvent(
        id: key,
        calendarId: cal,
        eventId: key,
        title: edit?.$1 ?? t,
        start: edit?.$2 ?? s,
        end: edit?.$3 ?? s.add(Duration(minutes: mins)),
        // Standup repeats, as it would in a real calendar.
      );
    }

    final today = DateTime.now();
    if (d.year != today.year || d.month != today.month || d.day != today.day) {
      return const [];
    }
    CalendarEvent at(String id, String t, int offset, int mins) {
      final m = _base + offset;
      return e(id, t, m ~/ 60, m % 60, mins);
    }

    // Standup starts two minutes after launch (to show a meeting pausing
    // work in a short video).
    final standup = _launch + 2;
    final all = [
      e('a', 'Standup', standup ~/ 60, standup % 60, 15),
      at('b', '1:1 Priya', 40, 30),
      at('d', 'Product review', 130, 60),
      at('f', 'Customer call — Acme', 215, 45),
    ];
    return all.where((x) => ids == null || ids.contains(x.calendarId)).toList();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsModel(repository: MemSettings());
  await settings.load();
  final model =
      DayPlannerModel(repository: MemDays(), calendarSource: FakeCalendar())
        ..calendarIds = settings.settings.selectedCalendarIds
        ..setWorkday(
          settings.settings.workdayStartHour,
          settings.settings.workdayEndHour,
        );
  settings.addListener(() {
    model.setWorkday(
      settings.settings.workdayStartHour,
      settings.settings.workdayEndHour,
    );
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
