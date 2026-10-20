import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/models/day_schedule.dart';
import 'package:planner/models/task.dart';
import 'package:planner/services/scheduler.dart';

final _day = DateTime(2026, 10, 10);

DaySchedule _run(List<Task> tasks, {required int nowMinutes}) =>
    Scheduler.schedule(
      tasks,
      dayStartHour: 6,
      dayEndHour: 23,
      nowMinutes: nowMinutes,
    );

int _startOf(DaySchedule s, Task t) =>
    s.committed.firstWhere((st) => st.task.id == t.id).startMinutes;

void main() {
  group('Phase 8 — status handling in Scheduler', () {
    test('inProgress floating task is anchored at startedAt, not re-placed',
        () {
      final active = Task(
        title: 'Active',
        durationMinutes: 60,
        type: TaskType.floating,
        status: TaskStatus.inProgress,
        startedAt: DateTime(2026, 10, 10, 9, 0),
        date: _day,
      );
      final other = Task(
        title: 'Other',
        durationMinutes: 30,
        type: TaskType.floating,
        priority: Priority.high,
        date: _day,
      );

      final s = _run([active, other], nowMinutes: 9 * 60 + 15);

      expect(_startOf(s, active), 9 * 60);
      // Higher-priority floating work must not displace active work.
      expect(_startOf(s, other), 10 * 60);
    });

    test('complete and cancelled floating tasks are excluded entirely', () {
      final done = Task(
        title: 'Done',
        durationMinutes: 30,
        type: TaskType.floating,
        status: TaskStatus.complete,
        date: _day,
      );
      final cancelled = Task(
        title: 'Cancelled',
        durationMinutes: 30,
        type: TaskType.floating,
        status: TaskStatus.cancelled,
        date: _day,
      );

      final s = _run([done, cancelled], nowMinutes: 8 * 60);

      expect(s.committed, isEmpty);
      expect(s.overflow, isEmpty);
    });

    test('completed pinned task still blocks its slot', () {
      final pinnedDone = Task(
        title: 'Pinned done',
        durationMinutes: 60,
        type: TaskType.pinned,
        startTime: const TimeOfDay(hour: 8, minute: 0),
        status: TaskStatus.complete,
        date: _day,
      );
      final floating = Task(
        title: 'Floating',
        durationMinutes: 30,
        type: TaskType.floating,
        date: _day,
      );

      final s = _run([pinnedDone, floating], nowMinutes: 8 * 60);

      expect(_startOf(s, floating), 9 * 60);
    });
  });

  group('Phase 9 — overrun uses elapsed time as effective duration', () {
    Task active() => Task(
          id: 'active',
          title: 'Active',
          durationMinutes: 30,
          type: TaskType.floating,
          status: TaskStatus.inProgress,
          startedAt: DateTime(2026, 10, 10, 9, 0),
          date: _day,
        );
    Task next() => Task(
          id: 'next',
          title: 'Next',
          durationMinutes: 30,
          type: TaskType.floating,
          date: _day,
        );

    test('within estimate: downstream task placed after estimated end', () {
      final s = _run([active(), next()], nowMinutes: 9 * 60 + 10);
      expect(_startOf(s, next()), 9 * 60 + 30);
    });

    test('overrunning: downstream task placed after elapsed time', () {
      final s = _run([active(), next()], nowMinutes: 10 * 60);
      expect(_startOf(s, next()), 10 * 60);
    });

    test('isOverrunning flags only once elapsed exceeds estimate', () {
      final t = active();
      expect(t.isOverrunning(DateTime(2026, 10, 10, 9, 30)), isFalse);
      expect(t.isOverrunning(DateTime(2026, 10, 10, 9, 31)), isTrue);
    });
  });
}
