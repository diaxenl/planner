import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/models/day_schedule.dart';
import 'package:planner/models/task.dart';
import 'package:planner/services/scheduler.dart';

final _day = DateTime(2026, 11, 16);

DateTime _at(int h, int m) => DateTime(2026, 11, 16, h, m);

Task _work(String title, int minutes, {TaskPriority? priority}) => Task(
  title: title,
  durationMinutes: minutes,
  type: TaskType.floating,
  priority: priority ?? TaskPriority.normal,
  date: _day,
);

Task _setTime(String title, int h, int m, int minutes) => Task(
  title: title,
  durationMinutes: minutes,
  type: TaskType.pinned,
  startTime: TimeOfDay(hour: h, minute: m),
  date: _day,
);

int _start(DaySchedule s, Task t) =>
    s.committed.firstWhere((st) => st.task.id == t.id).startMinutes;

void main() {
  group('Phase 22 — finished set-time items free their time', () {
    test('finishing early lets Anytime work move up to now', () {
      final done = _setTime('Set', 9, 0, 60).copyWith(
        status: TaskStatus.complete,
        startedAt: () => _at(9, 0),
        completedAt: () => _at(9, 20),
        actualDurationMinutes: () => 20,
      );
      final next = _work('Next', 30);
      final s = Scheduler.schedule(
        [done, next],
        dayStartHour: 8,
        dayEndHour: 18,
        nowMinutes: 9 * 60 + 20,
      );
      expect(_start(s, next), 9 * 60 + 20);
      // Still drawn on the timeline where it was.
      expect(_start(s, done), 9 * 60);
    });

    test('"Won\'t do" frees the whole slot', () {
      final dropped = _setTime(
        'Set',
        10,
        0,
        60,
      ).copyWith(status: TaskStatus.cancelled);
      final next = _work('Next', 60);
      final s = Scheduler.schedule(
        [_setTime('Busy', 8, 0, 120), dropped, next],
        dayStartHour: 8,
        dayEndHour: 18,
        nowMinutes: 9 * 60 + 55,
      );
      expect(_start(s, next), 10 * 60);
    });

    test('a not-finished set-time item still holds its slot', () {
      final next = _work('Next', 30);
      final s = Scheduler.schedule(
        [_setTime('Set', 9, 0, 60), next],
        dayStartHour: 9,
        dayEndHour: 18,
      );
      expect(_start(s, next), 10 * 60);
    });
  });

  group('Phase 22 — priority', () {
    test('High, then Normal, then Low; added first wins within each', () {
      final low = _work('Low', 15, priority: TaskPriority.low);
      final normal = _work('Normal', 30);
      final highLong = _work('High long', 60, priority: TaskPriority.high);
      final highShort = _work('High short', 30, priority: TaskPriority.high);
      final s = Scheduler.schedule(
        [low, normal, highLong, highShort],
        dayStartHour: 8,
        dayEndHour: 18,
      );
      expect(_start(s, highLong), 8 * 60);
      expect(_start(s, highShort), 9 * 60);
      expect(_start(s, normal), 9 * 60 + 30);
      expect(_start(s, low), 10 * 60);
    });

    test('Outcomes still come before High priority work', () {
      final high = _work('High', 30, priority: TaskPriority.high);
      final outcome = _work('Outcome', 30).copyWith(isOutcome: true);
      final s = Scheduler.schedule(
        [high, outcome],
        dayStartHour: 8,
        dayEndHour: 18,
      );
      expect(_start(s, outcome), 8 * 60);
      expect(_start(s, high), 8 * 60 + 30);
    });

    test('the most important work takes the first free time, split '
        'around a set-time item', () {
      final high = _work('High', 60, priority: TaskPriority.high);
      final low = _work('Low', 20, priority: TaskPriority.low);
      final s = Scheduler.schedule(
        [_setTime('Call', 8, 30, 30), high, low],
        dayStartHour: 8,
        dayEndHour: 18,
      );
      final highParts = s.committed.where((st) => st.task.id == high.id);
      expect([for (final p in highParts) p.startMinutes], [8 * 60, 9 * 60]);
      expect([for (final p in highParts) p.durationMinutes], [30, 30]);
      expect(_start(s, low), 9 * 60 + 30);
    });

    test('priority round-trips; missing reads as Normal', () {
      final t = _work('A', 30, priority: TaskPriority.low);
      expect(Task.fromJson(t.toJson())!.priority, TaskPriority.low);
      final json = t.toJson()..remove('priority');
      expect(Task.fromJson(json)!.priority, TaskPriority.normal);
    });
  });
}
