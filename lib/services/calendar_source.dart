import '../models/calendar_event.dart';

/// Read-only access to the phone's calendars.
///
/// Android and iOS sync Google, Microsoft, and iCloud accounts into the
/// on-device calendar store, so one implementation reading that store
/// covers all major providers.
abstract class CalendarSource {
  /// Asks for calendar permission if needed. Returns whether access is
  /// granted.
  Future<bool> requestAccess();

  /// Calendars available on the device.
  Future<List<DeviceCalendarInfo>> listCalendars();

  /// Events overlapping [date] from [calendarIds] (`null` = all), with
  /// events the user declined already left out where the platform says so.
  Future<List<CalendarEvent>> eventsFor(
    DateTime date,
    Set<String>? calendarIds,
  );
}

/// No calendars — used on desktop/web previews and in tests.
class NoCalendarSource implements CalendarSource {
  const NoCalendarSource();

  @override
  Future<bool> requestAccess() async => false;

  @override
  Future<List<DeviceCalendarInfo>> listCalendars() async => const [];

  @override
  Future<List<CalendarEvent>> eventsFor(
    DateTime date,
    Set<String>? calendarIds,
  ) async => const [];
}
