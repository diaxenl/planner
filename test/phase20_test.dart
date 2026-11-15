import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/app.dart';
import 'package:planner/features/day/widgets/schedule_timeline.dart';
import 'package:planner/models/calendar_event.dart';
import 'package:planner/models/day_schedule.dart';
import 'package:planner/models/schedule_suggestion.dart';
import 'package:planner/models/task.dart';
import 'package:planner/services/calendar_source.dart';
import 'package:planner/services/day_stats.dart';
import 'package:planner/state/day_planner_model.dart';
import 'package:planner/state/day_planner_provider.dart';
import 'package:planner/state/settings_model.dart';
import 'package:planner/state/settings_provider.dart';

Widget _app(DayPlannerModel model) => SettingsProvider(
  model: SettingsModel(),
  child: DayPlannerProvider(model: model, child: const HyperDayApp()),
);

/// A calendar whose events can be edited, like a phone's.
class _EditableCalendar implements CalendarSource {
  _EditableCalendar(this.events);

  List<CalendarEvent> events;
  int saves = 0;

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<List<DeviceCalendarInfo>> listCalendars() async => const [];

  @override
  Future<List<CalendarEvent>> eventsFor(DateTime date, Set<String>? ids) async =>
      events;

  @override
  Future<bool> updateEvent(
    CalendarEvent event, {
    required String title,
    required DateTime start,
    required DateTime end,
  }) async {
    saves++;
    events = [
      for (final e in events)
        e.id == event.id
            ? CalendarEvent(
                id: e.id,
                calendarId: e.calendarId,
                eventId: e.eventId,
                title: title,
                start: start,
                end: end,
              )
            : e,
    ];
    return true;
  }
}

void main() {
  group('paused work', () {
    test('pausing keeps the run, and Review counts its time', () async {
      final model = DayPlannerModel();
      await model.loadDate(DateTime.now());
      final task = Task(
        title: 'Write report',
        durationMinutes: 120,
        type: TaskType.floating,
        date: model.viewedDate,
      );
      model.addTask(task);
      final started = DateTime.now().subtract(const Duration(minutes: 40));
      model.updateTask(
        task.id,
        model.tasks.single.copyWith(
          status: TaskStatus.inProgress,
          startedAt: () => started,
        ),
      );
      model.pauseTask(task.id);

      final paused = model.tasks.single;
      expect(paused.status, TaskStatus.notStarted);
      expect(paused.pausedRuns, hasLength(1));
      expect(paused.pausedRuns.single.start, started);
      expect(paused.actualDurationMinutes, 40);

      final split = DayStats.timeSplit(model.tasks, model.schedule);
      expect(split.actual[TimeBucket.other], 40);
      expect(DayStats.workedMinutes(model.tasks), (0, 40));

      // Survives a save and load.
      final restored = Task.fromJson(paused.toJson())!;
      expect(restored.pausedRuns.single.start, started);
      model.dispose();
    }, skip: TimeOfDay.now().hour == 0 && TimeOfDay.now().minute < 45);

    testWidgets('a paused run stays on the timeline next to what is left', (
      tester,
    ) async {
      final model = DayPlannerModel();
      await tester.runAsync(() => model.loadDate(DateTime.now()));
      final now = DateTime.now();
      model.addTask(
        Task(
          title: 'Write report',
          durationMinutes: 120,
          type: TaskType.floating,
          date: model.viewedDate,
          actualDurationMinutes: 30,
          pausedRuns: [
            DateTimeRange(
              start: now.subtract(const Duration(minutes: 40)),
              end: now.subtract(const Duration(minutes: 10)),
            ),
          ],
        ),
      );
      await tester.pumpWidget(_app(model));
      await tester.pump();

      final timeline = find.byType(ScheduleTimeline);
      await tester.scrollUntilVisible(
        timeline,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.descendant(of: timeline, matching: find.text('Write report')),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: timeline,
          matching: find.textContaining('Worked 30m'),
        ),
        findsOneWidget,
      );
      model.dispose();
    }, skip: TimeOfDay.now().hour == 0 && TimeOfDay.now().minute < 45);

    test('Done after a pause counts as started at the first run', () async {
      final model = DayPlannerModel();
      await model.loadDate(DateTime.now());
      final now = DateTime.now();
      final first = now.subtract(const Duration(minutes: 50));
      model.addTask(
        Task(
          title: 'Fix bug',
          durationMinutes: 60,
          type: TaskType.floating,
          date: model.viewedDate,
          actualDurationMinutes: 20,
          pausedRuns: [
            DateTimeRange(
              start: first,
              end: first.add(const Duration(minutes: 20)),
            ),
          ],
        ),
      );
      model.markComplete(model.tasks.single.id, now);
      final done = model.tasks.single;
      expect(done.startedAt, first);
      expect(done.actualDurationMinutes, 20);
      model.dispose();
    }, skip: TimeOfDay.now().hour == 0 && TimeOfDay.now().minute < 55);
  });

  test('"Later today" is only offered when the item still fits', () async {
    final model = DayPlannerModel()..setWorkday(0, 24);
    await model.loadDate(DateTime.now());
    final small = Task(
      title: 'Call back',
      durationMinutes: 5,
      type: TaskType.pinned,
      startTime: const TimeOfDay(hour: 0, minute: 0),
      date: model.viewedDate,
    );
    final huge = Task(
      title: 'Offsite',
      durationMinutes: 480,
      type: TaskType.pinned,
      startTime: const TimeOfDay(hour: 0, minute: 5),
      date: model.viewedDate,
    );
    model
      ..addTask(small)
      ..addTask(huge);
    final left = 24 * 60 - (TimeOfDay.now().hour * 60 + TimeOfDay.now().minute);
    expect(model.fitsLaterToday(small.id), left > 20);
    expect(model.fitsLaterToday(huge.id), left > 480 + 20);
    model.dispose();
  }, skip: TimeOfDay.now().hour < 9);

  test('the day-shifted headline leaves names to the rows', () {
    Task t(String title) => Task(
      title: title,
      durationMinutes: 30,
      type: TaskType.floating,
      date: DateTime(2030),
    );
    const at = TimeOfDay(hour: 9, minute: 0);
    final move = TaskMove(task: t('Proposal'), oldStart: at, newStart: at);
    expect(
      ScheduleSuggestion(
        proposed: DaySchedule.empty,
        moves: const [],
        pushedOut: [t('Report')],
      ).summary,
      'Not enough time left today.',
    );
    expect(
      ScheduleSuggestion(proposed: DaySchedule.empty, moves: [move]).summary,
      'An outcome moved later.',
    );
  });

  group('calendar meetings', () {
    final day = DateTime(2030, 1, 7);
    CalendarEvent event({bool recurring = false, bool readOnly = false}) =>
        CalendarEvent(
          id: 'work/42/1',
          calendarId: 'work',
          eventId: '42',
          title: 'Design review',
          start: DateTime(2030, 1, 7, 10),
          end: DateTime(2030, 1, 7, 11),
          isRecurring: recurring,
          isReadOnly: readOnly,
        );

    test('an edit in the app is saved back to the calendar', () async {
      final calendar = _EditableCalendar([event()]);
      final model = DayPlannerModel(calendarSource: calendar);
      await model.loadDate(day);
      final meeting = model.schedule.committed.single.task;
      expect(model.whyNotEditable(meeting), isNull);

      await model.updateImported(
        meeting,
        title: 'Design review (moved)',
        start: const TimeOfDay(hour: 14, minute: 0),
        durationMinutes: 45,
      );
      expect(calendar.saves, 1);
      final after = model.schedule.committed.single;
      expect(after.task.title, 'Design review (moved)');
      expect(after.startMinutes, 14 * 60);
      expect(after.durationMinutes, 45);
      model.dispose();
    });

    test('repeating meetings and read-only calendars say why not', () async {
      for (final e in [event(recurring: true), event(readOnly: true)]) {
        final calendar = _EditableCalendar([e]);
        final model = DayPlannerModel(calendarSource: calendar);
        await model.loadDate(day);
        final meeting = model.schedule.committed.single.task;
        expect(model.whyNotEditable(meeting), isNotNull);
        await expectLater(
          model.updateImported(
            meeting,
            title: 'x',
            start: const TimeOfDay(hour: 9, minute: 0),
            durationMinutes: 30,
          ),
          throwsArgumentError,
        );
        expect(calendar.saves, 0);
        model.dispose();
      }
    });
  });
}
