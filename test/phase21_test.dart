import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/core/theme.dart';
import 'package:planner/features/settings/settings_screen.dart';
import 'package:planner/models/calendar_event.dart';
import 'package:planner/services/calendar_source.dart';
import 'package:planner/state/day_planner_model.dart';
import 'package:planner/state/day_planner_provider.dart';
import 'package:planner/state/settings_model.dart';
import 'package:planner/state/settings_provider.dart';

/// A phone calendar store whose access and calendars the test controls.
class _Phone implements CalendarSource {
  _Phone({this.access = false, this.allowOnAsk = true, this.calendars = 0});

  bool access;
  final bool allowOnAsk;
  final int calendars;

  @override
  Future<bool> requestAccess() async => access = access || allowOnAsk;

  @override
  Future<bool> hasAccess() async => access;

  @override
  Future<List<DeviceCalendarInfo>> listCalendars() async => [
    if (access)
      for (var i = 0; i < calendars; i++)
        DeviceCalendarInfo(id: '$i', name: 'Calendar $i'),
  ];

  @override
  Future<List<CalendarEvent>> eventsFor(DateTime date, Set<String>? ids) async =>
      const [];

  @override
  Future<bool> updateEvent(
    CalendarEvent event, {
    required String title,
    required DateTime start,
    required DateTime end,
  }) async => false;
}

Future<void> _open(WidgetTester tester, _Phone phone) async {
  final model = DayPlannerModel(calendarSource: phone);
  addTearDown(model.dispose);
  await tester.pumpWidget(
    SettingsProvider(
      model: SettingsModel(),
      child: DayPlannerProvider(
        model: model,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('CALENDARS'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  group('calendar connection in Settings', () {
    testWidgets('allowing access shows a verified check and the count', (
      tester,
    ) async {
      await _open(tester, _Phone(calendars: 8));
      expect(find.byIcon(Icons.check_circle), findsNothing);

      await tester.tap(find.text('Allow calendar access'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Connected · 8 calendars'), findsOneWidget);
      expect(find.text('Allow calendar access'), findsNothing);
    });

    testWidgets('already allowed: connected straight away', (tester) async {
      await _open(tester, _Phone(access: true, calendars: 1));
      expect(find.text('Connected · 1 calendar'), findsOneWidget);
    });

    testWidgets('access allowed but no calendars: no check, says so', (
      tester,
    ) async {
      await _open(tester, _Phone(access: true));
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(
        find.text('Access allowed, but no calendars found'),
        findsOneWidget,
      );
      expect(find.text('Check again'), findsOneWidget);
    });

    testWidgets('access refused: no check, the button stays', (tester) async {
      await _open(tester, _Phone(allowOnAsk: false, calendars: 3));
      await tester.tap(find.text('Allow calendar access'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.text('Allow calendar access'), findsOneWidget);
    });
  });
}
