/// An event imported from one of the phone's calendars.
///
/// Never persisted by HyperDay; re-read from the device on demand. Edits
/// are written back to the calendar (see `CalendarSource.updateEvent`).
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.start,
    required this.end,
    this.isAllDay = false,
    this.eventId,
    this.isRecurring = false,
    this.isReadOnly = false,
  });

  final String id;
  final String calendarId;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;

  /// The calendar's own id for the event, used to save changes. `null`
  /// when it can't be changed from here.
  final String? eventId;

  /// One occurrence of a repeating event. Not changed from here: saving
  /// it would move the whole series.
  final bool isRecurring;

  /// In a calendar other apps can't change (e.g. a subscribed one).
  final bool isReadOnly;
}

/// The result of checking the calendar connection: whether access is
/// granted, and the calendars actually read from the phone.
typedef CalendarCheck = ({bool access, List<DeviceCalendarInfo> calendars});

/// A calendar available on the device, for the Settings picker.
class DeviceCalendarInfo {
  const DeviceCalendarInfo({
    required this.id,
    required this.name,
    this.accountName,
  });

  final String id;
  final String name;

  /// e.g. "maya@company.com" — groups calendars by account in Settings.
  final String? accountName;
}
