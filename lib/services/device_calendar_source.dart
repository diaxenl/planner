import 'package:device_calendar/device_calendar.dart' as dc;

import '../models/calendar_event.dart';
import 'calendar_source.dart';

/// Reads the phone's calendar store (Android Calendar Provider / iOS
/// EventKit) via `device_calendar`. Google, Microsoft and iCloud accounts
/// synced to the phone all appear here. Read-only: nothing is written.
class DeviceCalendarSource implements CalendarSource {
  DeviceCalendarSource() : _plugin = dc.DeviceCalendarPlugin();

  final dc.DeviceCalendarPlugin _plugin;

  @override
  Future<bool> requestAccess() async {
    final has = await _plugin.hasPermissions();
    if (has.isSuccess && has.data == true) return true;
    final asked = await _plugin.requestPermissions();
    return asked.isSuccess && asked.data == true;
  }

  Future<bool> _hasAccess() async {
    final has = await _plugin.hasPermissions();
    return has.isSuccess && has.data == true;
  }

  Future<List<dc.Calendar>> _calendars() async {
    if (!await _hasAccess()) return const [];
    final result = await _plugin.retrieveCalendars();
    if (!result.isSuccess) return const [];
    return [
      for (final c in result.data!)
        if (c.id != null) c,
    ];
  }

  @override
  Future<List<DeviceCalendarInfo>> listCalendars() async => [
    for (final c in await _calendars())
      DeviceCalendarInfo(
        id: c.id!,
        name: c.name ?? 'Calendar',
        accountName: c.accountName,
      ),
  ];

  @override
  Future<List<CalendarEvent>> eventsFor(
    DateTime date,
    Set<String>? calendarIds,
  ) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final params = dc.RetrieveEventsParams(
      startDate: dayStart,
      endDate: dayEnd,
    );

    final events = <CalendarEvent>[];
    for (final cal in await _calendars()) {
      if (calendarIds != null && !calendarIds.contains(cal.id)) continue;
      final result = await _plugin.retrieveEvents(cal.id, params);
      if (!result.isSuccess) continue;
      for (final e in result.data!) {
        if (e.start == null || e.end == null) continue;
        if (e.status == dc.EventStatus.Canceled || _declined(e)) continue;
        events.add(
          CalendarEvent(
            id: '${cal.id}/${e.eventId}/${e.start!.millisecondsSinceEpoch}',
            calendarId: cal.id!,
            title: e.title ?? '',
            // Through epoch millis, so times are in the phone's local zone.
            start: DateTime.fromMillisecondsSinceEpoch(
              e.start!.millisecondsSinceEpoch,
            ),
            end: DateTime.fromMillisecondsSinceEpoch(
              e.end!.millisecondsSinceEpoch,
            ),
            isAllDay: e.allDay ?? false,
          ),
        );
      }
    }
    return events;
  }

  /// Whether the phone's owner declined [e], where the platform says so.
  static bool _declined(dc.Event e) {
    for (final a in e.attendees ?? const <dc.Attendee?>[]) {
      if (a == null || !a.isCurrentUser) continue;
      return a.androidAttendeeDetails?.attendanceStatus ==
              dc.AndroidAttendanceStatus.Declined ||
          a.iosAttendeeDetails?.attendanceStatus ==
              dc.IosAttendanceStatus.Declined;
    }
    return false;
  }
}
