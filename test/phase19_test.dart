import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/app.dart';
import 'package:planner/core/utils.dart';
import 'package:planner/features/day/widgets/schedule_timeline.dart';
import 'package:planner/models/scheduled_task.dart';
import 'package:planner/models/task.dart';
import 'package:planner/state/day_planner_model.dart';
import 'package:planner/state/day_planner_provider.dart';
import 'package:planner/state/settings_model.dart';
import 'package:planner/state/settings_provider.dart';

Widget _app(DayPlannerModel model) => SettingsProvider(
  model: SettingsModel(),
  child: DayPlannerProvider(model: model, child: const HyperDayApp()),
);

final _day = DateTime(2030, 1, 7);

ScheduledTask _at(
  String title,
  int hour,
  int minute,
  int duration, {
  TaskType type = TaskType.floating,
  TaskStatus status = TaskStatus.notStarted,
}) => ScheduledTask(
  task: Task(
    title: title,
    durationMinutes: duration,
    type: type,
    status: status,
    date: _day,
  ),
  computedStartTime: TimeOfDay(hour: hour, minute: minute),
);

void main() {
  test('timers and countdowns carry units', () {
    expect(AppUtils.formatTimer(const Duration(seconds: 42)), '42s');
    expect(
      AppUtils.formatTimer(const Duration(minutes: 14, seconds: 5)),
      '14m 05s',
    );
    expect(
      AppUtils.formatTimer(const Duration(hours: 3, minutes: 11, seconds: 41)),
      '3h 11m',
    );
  });

  test('the timeline flags your own items that overlap open entries', () {
    final layout = TimelineLayout.of(
      [
        _at('Standup', 9, 0, 15, type: TaskType.hard),
        _at('Escalation', 8, 50, 45, type: TaskType.pinned),
        _at('Old email', 9, 0, 10, status: TaskStatus.complete),
      ],
      dayStartHour: 8,
      dayEndHour: 17,
    );
    final byTitle = {for (final b in layout.blocks) b.entry.task.title: b};
    expect(byTitle['Escalation']!.overlaps, ['Standup']);
    expect(byTitle['Escalation']!.overlapSpans, [(9 * 60, 9 * 60 + 15)]);
    expect(byTitle['Standup']!.overlaps, ['Escalation']); // both sides
    expect(byTitle['Old email']!.overlaps, isEmpty); // finished
  });

  group('missed items', () {
    test('a set-time item whose time passed without a Start is missed; '
        'Later today makes it Anytime', () async {
      final model = DayPlannerModel();
      await model.loadDate(DateTime.now());
      model.addTask(
        Task(
          title: 'Prep slides',
          durationMinutes: 5,
          type: TaskType.pinned,
          startTime: const TimeOfDay(hour: 0, minute: 0),
          date: model.viewedDate,
        ),
      );
      expect(model.missedItems.map((t) => t.title), ['Prep slides']);

      final before = model.planLaterToday(model.missedItems.single.id)!;
      expect(before.type, TaskType.pinned);
      final after = model.tasks.single;
      expect(after.type, TaskType.floating);
      expect(after.startTime, isNull);
      expect(model.missedItems, isEmpty);
      model.dispose();
    }, skip: TimeOfDay.now().hour == 0 && TimeOfDay.now().minute < 6);

    test('meetings and other days are never missed', () async {
      final model = DayPlannerModel();
      await model.loadDate(DateTime.now().add(const Duration(days: 3)));
      model.addTask(
        Task(
          title: 'Future',
          durationMinutes: 5,
          type: TaskType.pinned,
          startTime: const TimeOfDay(hour: 0, minute: 0),
          date: model.viewedDate,
        ),
      );
      expect(model.missedItems, isEmpty);
      model.dispose();
    });
  });

  testWidgets(
    'a finished item stays on the timeline, ending when it was done',
    (tester) async {
      final model = DayPlannerModel();
      await tester.runAsync(() => model.loadDate(DateTime.now()));
      final task = Task(
        title: 'Reply to emails',
        durationMinutes: 30,
        type: TaskType.floating,
        date: model.viewedDate,
      );
      model
        ..addTask(task)
        ..markComplete(task.id, DateTime.now());

      await tester.pumpWidget(_app(model));
      await tester.pump();

      final timeline = find.byType(ScheduleTimeline);
      expect(
        find.descendant(of: timeline, matching: find.text('Reply to emails')),
        findsOneWidget,
      );
      expect(find.text('FINISHED'), findsNothing);
      model.dispose();
    },
    skip: TimeOfDay.now().hour >= 23 || TimeOfDay.now().hour == 0,
  );
}
