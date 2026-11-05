import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/models/day_schedule.dart';
import 'package:planner/models/scheduled_task.dart';
import 'package:planner/models/task.dart';
import 'package:planner/services/day_stats.dart';

final _day = DateTime(2026, 10, 10);

ScheduledTask _at(
  int hour,
  int minutes, {
  TaskType type = TaskType.floating,
  bool outcome = false,
  TaskStatus status = TaskStatus.notStarted,
  String title = 'T',
}) =>
    ScheduledTask(
      task: Task(
        title: title,
        durationMinutes: minutes,
        type: type,
        isOutcome: outcome,
        status: status,
        startedAt: status == TaskStatus.inProgress ? DateTime(2026, 10, 10, hour) : null,
        date: _day,
      ),
      computedStartTime: TimeOfDay(hour: hour, minute: 0),
    );

LoadBreakdown _load(List<ScheduledTask> committed, int now,
        {List<Task> overflow = const []}) =>
    DayStats.loadBreakdown(
      DaySchedule(committed: committed, overflow: overflow),
      nowMinutes: now,
      dayStartHour: 6,
      dayEndHour: 23,
    );

void main() {
  group('Phase 12 — loadBreakdown', () {
    test('splits the remaining window by kind', () {
      final l = _load([
        _at(10, 60, type: TaskType.hard),
        _at(11, 90, outcome: true),
        _at(13, 30),
      ], 9 * 60);
      expect(l.meetings, 60);
      expect(l.outcomes, 90);
      expect(l.other, 30);
      expect(l.free, 14 * 60 - 180);
      expect(l.total, 14 * 60);
    });

    test('counts only what is left of an item already under way', () {
      final l = _load([_at(9, 60, type: TaskType.hard)], 9 * 60 + 45);
      expect(l.meetings, 15);
    });

    test('ignores finished items and past items; reports overflow', () {
      final l = _load(
        [
          _at(7, 60),
          _at(10, 60, status: TaskStatus.complete),
        ],
        9 * 60,
        overflow: [
          Task(title: 'X', durationMinutes: 45, type: TaskType.floating, date: _day),
        ],
      );
      expect(l.other, 0);
      expect(l.free, 14 * 60);
      expect(l.overflow, 45);
    });
  });

  group('Phase 12 — currentItem', () {
    DaySchedule s(List<ScheduledTask> c) => DaySchedule(committed: c, overflow: const []);

    test('prefers the in-progress item', () {
      final a = _at(9, 30, title: 'A');
      final b = _at(10, 30, title: 'B', status: TaskStatus.inProgress);
      expect(DayStats.currentItem(s([a, b]), 9 * 60 + 10)!.task.title, 'B');
    });

    test('else the item whose window contains now', () {
      final a = _at(9, 30, title: 'A');
      final b = _at(10, 30, title: 'B');
      expect(DayStats.currentItem(s([a, b]), 9 * 60 + 10)!.task.title, 'A');
    });

    test('else the next upcoming; null when nothing is left', () {
      final a = _at(9, 30, title: 'A');
      final b = _at(10, 30, title: 'B');
      final done = _at(11, 30, title: 'C', status: TaskStatus.complete);
      expect(DayStats.currentItem(s([a, b, done]), 9 * 60 + 40)!.task.title, 'B');
      expect(DayStats.currentItem(s([a, b, done]), 11 * 60 + 5), isNull);
    });
  });

  group('Phase 15 — review stats', () {
    Task t(
      int est, {
      TaskType type = TaskType.floating,
      bool outcome = false,
      bool interruption = false,
      TaskStatus status = TaskStatus.notStarted,
      int? actual,
    }) =>
        Task(
          title: 'T',
          durationMinutes: est,
          type: type,
          startTime: type == TaskType.floating ? null : const TimeOfDay(hour: 9, minute: 0),
          isOutcome: outcome,
          isInterruption: interruption,
          status: status,
          actualDurationMinutes: actual,
          date: _day,
        );

    test('timeSplit buckets planned vs actual', () {
      final meeting = t(60, type: TaskType.hard);
      final tasks = [
        meeting,
        t(90, outcome: true, status: TaskStatus.complete, actual: 120),
        t(60, outcome: true),
        t(30, status: TaskStatus.complete, actual: 20),
        t(15, interruption: true, status: TaskStatus.complete, actual: 25),
        t(45, status: TaskStatus.cancelled),
      ];
      final schedule = DaySchedule(
        committed: [ScheduledTask(task: meeting, computedStartTime: const TimeOfDay(hour: 9, minute: 0))],
        overflow: const [],
      );

      final split = DayStats.timeSplit(tasks, schedule);
      expect(split.planned[TimeBucket.meetings], 60);
      expect(split.actual[TimeBucket.meetings], 60);
      expect(split.planned[TimeBucket.outcomes], 150);
      expect(split.actual[TimeBucket.outcomes], 120);
      expect(split.planned[TimeBucket.other], 30);
      expect(split.actual[TimeBucket.other], 20);
      expect(split.planned[TimeBucket.interruptions], 0);
      expect(split.actual[TimeBucket.interruptions], 25);
    });

    test('estimateAccuracy ignores zero-tracked, meetings, cancelled', () {
      expect(DayStats.estimateAccuracy([]), isNull);
      final tasks = [
        t(60, status: TaskStatus.complete, actual: 90),
        t(40, status: TaskStatus.complete, actual: 30),
        t(30, status: TaskStatus.complete, actual: 0),
        t(30, type: TaskType.hard, status: TaskStatus.complete, actual: 60),
        t(30, status: TaskStatus.cancelled, actual: 60),
      ];
      expect(DayStats.estimateAccuracy(tasks), 20);
    });

    test('outcomesHit ignores cancelled', () {
      final tasks = [
        t(30, outcome: true, status: TaskStatus.complete),
        t(30, outcome: true),
        t(30, outcome: true, status: TaskStatus.cancelled),
        t(30),
      ];
      expect(DayStats.outcomesHit(tasks), (1, 2));
    });
  });
}
