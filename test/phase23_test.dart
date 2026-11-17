import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/models/day_schedule.dart';
import 'package:planner/models/scheduled_task.dart';
import 'package:planner/models/task.dart';
import 'package:planner/services/capture_parser.dart';
import 'package:planner/services/day_stats.dart';
import 'package:planner/state/day_planner_model.dart';

final _day = DateTime(2030, 1, 7);

ScheduledTask _entry(
  String title,
  int hour,
  int minute,
  TaskType type, {
  TaskStatus status = TaskStatus.notStarted,
}) => ScheduledTask(
  task: Task(
    title: title,
    durationMinutes: 30,
    type: type,
    startTime: type == TaskType.floating
        ? null
        : TimeOfDay(hour: hour, minute: minute),
    status: status,
    startedAt: status == TaskStatus.inProgress
        ? DateTime(2030, 1, 7, hour, minute)
        : null,
    date: _day,
  ),
  computedStartTime: TimeOfDay(hour: hour, minute: minute),
);

void main() {
  group('Phase 23 — plain-language capture', () {
    test('"noon"', () {
      final p = CaptureParser.parse('lunch with Sam at noon');
      expect(p.title, 'lunch with Sam');
      expect(p.startTime, const TimeOfDay(hour: 12, minute: 0));
    });

    test('lengths in words; a filler before them is dropped', () {
      final a = CaptureParser.parse('prepare slides, probably 2 hours');
      expect(a.title, 'prepare slides');
      expect(a.durationMinutes, 120);
      expect(CaptureParser.parse('handouts, 10 minutes').durationMinutes, 10);
      expect(CaptureParser.parse('call mom for an hour').title, 'call mom');
      expect(CaptureParser.parse('call mom for an hour').durationMinutes, 60);
      expect(CaptureParser.parse('stretch half an hour').durationMinutes, 30);
      expect(CaptureParser.parse('read 1.5 hours').durationMinutes, 90);
    });

    test('hours then minutes, as two words, are one length', () {
      final a = CaptureParser.parse('Investor update 1h 30m');
      expect(a.title, 'Investor update');
      expect(a.durationMinutes, 90);
      expect(CaptureParser.parse('Deck 1h30m').durationMinutes, 90);
      expect(CaptureParser.parse('Deck 2h 15m at 3').durationMinutes, 135);
      final b = CaptureParser.parse('write 1 hour 30 minutes');
      expect(b.title, 'write');
      expect(b.durationMinutes, 90);
      // Minutes of 60 or more aren't "and N minutes": not added up.
      expect(CaptureParser.parse('Deck 1h 75m').durationMinutes, 60);
    });

    test('"after work" is the end of the workday', () {
      final p = CaptureParser.parse(
        'pick up dry cleaning after work',
        workdayEndHour: 17,
      );
      expect(p.title, 'pick up dry cleaning');
      expect(p.startTime, const TimeOfDay(hour: 17, minute: 0));
    });

    test('a deadline ("by 4pm") stays in the title', () {
      final p = CaptureParser.parse('submit expense report by 4pm');
      expect(p.title, 'submit expense report by 4pm');
      expect(p.startTime, isNull);
    });

    test('priority shorthand', () {
      final high = CaptureParser.parse('Fix login bug ! 30m');
      expect(high.priority, TaskPriority.high);
      expect(high.title, 'Fix login bug');
      expect(CaptureParser.parse('Tidy desk !low').priority, TaskPriority.low);
      expect(CaptureParser.parse('Tidy desk').priority, isNull);
    });
  });

  group('Phase 23 — Now card', () {
    test('a set-time item starting does not hide the running task', () {
      final running = _entry(
        'Slides',
        16,
        0,
        TaskType.floating,
        status: TaskStatus.inProgress,
      );
      final setTime = _entry('Expense report', 17, 30, TaskType.pinned);
      final schedule = DaySchedule(committed: [running, setTime], overflow: []);
      expect(
        DayStats.currentItem(schedule, 17 * 60 + 35)!.task.title,
        'Slides',
      );
    });

    test('a meeting still takes the card from a running task', () {
      final running = _entry(
        'Slides',
        16,
        0,
        TaskType.floating,
        status: TaskStatus.inProgress,
      );
      final meeting = _entry('Sync', 17, 30, TaskType.hard);
      final schedule = DaySchedule(committed: [running, meeting], overflow: []);
      expect(DayStats.currentItem(schedule, 17 * 60 + 35)!.task.title, 'Sync');
    });
  });

  test(
    'Phase 23 — a set-time item is missed 10 minutes after its start',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final model = DayPlannerModel();
      await model.loadDate(DateTime.now());
      final now = TimeOfDay.now();
      final nowMin = now.hour * 60 + now.minute;
      Task at(String title, int minutesAgo) {
        final m = nowMin - minutesAgo;
        return Task(
          title: title,
          durationMinutes: 60,
          type: TaskType.pinned,
          startTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
          date: model.viewedDate,
        );
      }

      model
        ..addTask(at('Long ago', 75))
        ..addTask(at('Just started', 5));
      expect(model.missedItems.map((t) => t.title), ['Long ago']);

      model.removeTask(model.tasks.first.id);
      model.removeTask(model.tasks.first.id);
      model.addTask(at('Twelve minutes in', 12));
      expect(model.missedItems.map((t) => t.title), ['Twelve minutes in']);
      model.dispose();
    },
    // Needs room before now for the items (and before midnight after).
    skip: TimeOfDay.now().hour < 2 || TimeOfDay.now().hour >= 22,
  );
}
