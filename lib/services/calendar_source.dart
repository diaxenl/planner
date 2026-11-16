import '../models/calendar_event.dart';

/// Access to the phone's calendars: reading events, and saving changes
/// made to one in the app.
///
/// Android and iOS sync Google, Microsoft, and iCloud accounts into the
/// on-device calendar store, so one implementation reading that store
/// covers all major providers.
abstract class CalendarSource {
  /// Asks for calendar permission if needed. Returns whether access is
  /// granted.
  Future<bool> requestAccess();

  /// Whether calendar access is granted, without asking.
  Future<bool> hasAccess();

  /// Calendars available on the device.
  Future<List<DeviceCalendarInfo>> listCalendars();

  /// Events overlapping [date] from [calendarIds] (`null` = all), with
  /// events the user declined already left out where the platform says so.
  Future<List<CalendarEvent>> eventsFor(
    DateTime date,
    Set<String>? calendarIds,
  );

  /// Saves a new [title], [start] and [end] to [event] in its calendar.
  /// Returns whether the calendar accepted the change.
  Future<bool> updateEvent(
    CalendarEvent event, {
    required String title,
    required DateTime start,
    required DateTime end,
  });
}

/// No calendars — used on desktop/web previews and in tests.
class NoCalendarSource implements CalendarSource {
  const NoCalendarSource();

  @override
  Future<bool> requestAccess() async => false;

  @override
  Future<bool> hasAccess() async => false;

  @override
  Future<List<DeviceCalendarInfo>> listCalendars() async => const [];

  @override
  Future<List<CalendarEvent>> eventsFor(
    DateTime date,
    Set<String>? calendarIds,
  ) async => const [];

  @override
  Future<bool> updateEvent(
    CalendarEvent event, {
    required String title,
    required DateTime start,
    required DateTime end,
  }) async => false;
}
