/// A read-only event imported from one of the phone's calendars.
///
/// Never persisted by HyperDay; re-read from the device on demand.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.start,
    required this.end,
    this.isAllDay = false,
  });

  final String id;
  final String calendarId;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;
}

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
