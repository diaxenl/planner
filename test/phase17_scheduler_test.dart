import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/models/day_schedule.dart';
import 'package:planner/models/scheduled_task.dart';
import 'package:planner/models/task.dart';
import 'package:planner/services/scheduler.dart';

final _day = DateTime(2026, 11, 5);

Task _meeting(String title, int h, int m, int minutes) => Task(
  title: title,
  durationMinutes: minutes,
  type: TaskType.hard,
  startTime: TimeOfDay(hour: h, minute: m),
  date: _day,
);

Task _work(String title, int minutes, {bool outcome = false}) => Task(
  title: title,
  durationMinutes: minutes,
  type: TaskType.floating,
  isOutcome: outcome,
  date: _day,
);

/// The persona's Thursday (Round 4 review).
List<Task> _meetings() => [
  _meeting('Standup', 8, 30, 15),
  _meeting('1:1 Priya', 9, 0, 30),
  _meeting('1:1 Marco', 9, 30, 30),
  _meeting('Product review', 11, 0, 60),
  _meeting('Lunch w/ candidate', 12, 30, 60),
  _meeting('Customer call', 14, 0, 60),
  _meeting('Eng sync', 16, 0, 30),
  _meeting('Kids pickup', 17, 30, 30),
];

DaySchedule _run(List<Task> tasks, {int buffer = 0, int? now}) =>
    Scheduler.schedule(
      tasks,
      dayStartHour: 8,
      dayEndHour: 18,
      nowMinutes: now,
      bufferMinutes: buffer,
    );

List<ScheduledTask> _sessions(DaySchedule s, Task t) =>
    s.committed.where((st) => st.task.id == t.id).toList();

void main() {
  group('Phase 17 — Outcomes split across free gaps', () {
    test('the #1 Outcome no longer overflows on a meeting-heavy day', () {
      final deck = _work('Prep board deck', 120, outcome: true);
      final okrs = _work('Write Q1 OKRs', 90, outcome: true);
      final hiring = _work('Hiring plan', 60, outcome: true);
      final s = _run([..._meetings(), deck, okrs, hiring]);

      expect(s.overflow, isNot(contains(deck)));
      final parts = _sessions(s, deck);
      expect(parts.length, greaterThan(1));
      expect(parts.fold<int>(0, (sum, p) => sum + p.durationMinutes), 120);
      for (final p in parts) {
        expect(p.durationMinutes, greaterThanOrEqualTo(30));
        expect(p.parts, parts.length);
      }
      expect(
        [for (final p in parts) p.part],
        [for (var i = 1; i <= parts.length; i++) i],
      );
    });

    test('an Outcome that fits one gap is not split', () {
      final o = _work('Write', 60, outcome: true);
      final s = _run([..._meetings(), o]);
      expect(_sessions(s, o).single.isSplit, isFalse);
      expect(_sessions(s, o).single.startMinutes, 10 * 60);
    });

    test('other work is never split', () {
      final chore = _work('Big chore', 120);
      final s = _run([..._meetings(), chore]);
      expect(s.overflow, contains(chore));
      expect(_sessions(s, chore), isEmpty);
    });

    test('no session is shorter than 30 minutes', () {
      // Gaps: 8:00–8:20 (20m), 9:00–9:40 (40m), 10:00–11:00 (60m).
      final o = _work('Deep work', 80, outcome: true);
      final s = Scheduler.schedule(
        [
          _meeting('A', 8, 20, 40),
          _meeting('B', 9, 40, 20),
          _meeting('C', 11, 0, 60),
          o,
        ],
        dayStartHour: 8,
        dayEndHour: 12,
      );
      final parts = _sessions(s, o);
      expect([for (final p in parts) p.startMinutes], [9 * 60, 10 * 60]);
      // The 20m gap is too short for a session; the rest is 40m + 40m.
      expect([for (final p in parts) p.durationMinutes], [40, 40]);
    });

    test(
      'a running Outcome stops at the next meeting; the rest is planned',
      () {
        final deck = Task(
          title: 'Prep board deck',
          durationMinutes: 120,
          type: TaskType.floating,
          isOutcome: true,
          status: TaskStatus.inProgress,
          startedAt: DateTime(2026, 11, 5, 10, 0),
          date: _day,
        );
        final s = _run([..._meetings(), deck], now: 10 * 60 + 20);
        final parts = _sessions(s, deck);
        expect(parts.first.startMinutes, 10 * 60);
        expect(parts.first.endMinutes, 11 * 60);
        expect(parts.fold<int>(0, (sum, p) => sum + p.durationMinutes), 120);
        expect(parts.first.parts, parts.length);
      },
    );

    test('minutes tracked before a pause are not planned again', () {
      final o = _work(
        'Write',
        90,
        outcome: true,
      ).copyWith(actualDurationMinutes: () => 60);
      final s = _run([o]);
      expect(_sessions(s, o).single.durationMinutes, 30);
    });
  });

  group('Phase 17 — breathing room', () {
    test('a buffer is kept after meetings and between items', () {
      final a = _work('A', 30);
      final b = _work('B', 30);
      final s = Scheduler.schedule(
        [_meeting('M', 8, 0, 30), a, b],
        dayStartHour: 8,
        dayEndHour: 18,
        bufferMinutes: 10,
      );
      expect(_sessions(s, a).single.startMinutes, 8 * 60 + 40);
      expect(_sessions(s, b).single.startMinutes, 9 * 60 + 20);
    });

    test('a buffer is kept before a meeting, not at the day start', () {
      final a = _work('A', 30);
      final s = Scheduler.schedule(
        [_meeting('M', 8, 35, 30), a],
        dayStartHour: 8,
        dayEndHour: 18,
        bufferMinutes: 10,
      );
      // 8:00–8:25 is only 25m, so A goes after the meeting + buffer.
      expect(_sessions(s, a).single.startMinutes, 9 * 60 + 15);
    });
  });

  group('Phase 17 — Do next', () {
    test('"Do next" work goes before Outcomes, latest choice first', () {
      final outcome = _work('Outcome', 60, outcome: true);
      final first = _work(
        'First',
        30,
      ).copyWith(doNextAt: () => DateTime(2026, 11, 5, 9));
      final second = _work(
        'Second',
        30,
      ).copyWith(doNextAt: () => DateTime(2026, 11, 5, 10));
      final s = _run([outcome, first, second]);
      expect(_sessions(s, second).single.startMinutes, 8 * 60);
      expect(_sessions(s, first).single.startMinutes, 8 * 60 + 30);
      expect(_sessions(s, outcome).single.startMinutes, 9 * 60);
    });
  });
}
