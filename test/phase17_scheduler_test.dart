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

DaySchedule _run(List<Task> tasks, {int? now}) =>
    Scheduler.schedule(tasks, dayStartHour: 8, dayEndHour: 18, nowMinutes: now);

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
        expect(p.durationMinutes, greaterThanOrEqualTo(5));
        expect(p.parts, parts.length);
      }
      expect(
        [for (final p in parts) p.part],
        [for (var i = 1; i <= parts.length; i++) i],
      );
    });

    test('an Outcome that fits the earliest gap is not split', () {
      final o = _work('Write', 30, outcome: true);
      final s = _run([..._meetings(), o]);
      expect(_sessions(s, o).single.isSplit, isFalse);
      expect(_sessions(s, o).single.startMinutes, 8 * 60);
    });

    test('other work is split too, starting at the earliest free time', () {
      final chore = _work('Big chore', 120);
      final s = _run([..._meetings(), chore]);
      expect(s.overflow, isNot(contains(chore)));
      final parts = _sessions(s, chore);
      expect(parts.first.startMinutes, 8 * 60);
      expect(parts.fold<int>(0, (sum, p) => sum + p.durationMinutes), 120);
    });

    test('no session is shorter than 15 minutes; short work is never '
        'split', () {
      // Gaps: 8:00–8:10 (too short for a session), 9:00–12:00.
      final o = _work('Deep work', 80, outcome: true);
      final s = Scheduler.schedule(
        [_meeting('A', 8, 10, 50), o],
        dayStartHour: 8,
        dayEndHour: 12,
      );
      expect(_sessions(s, o).single.startMinutes, 9 * 60);

      // 23m doesn't fit the 20m gap: it waits for one it fits whole.
      final p = _work('Write', 23, outcome: true);
      final s2 = Scheduler.schedule(
        [_meeting('A', 8, 20, 40), p],
        dayStartHour: 8,
        dayEndHour: 12,
      );
      expect(_sessions(s2, p).single.startMinutes, 9 * 60);

      // 45m over a 40m and a 20m gap: 40m would leave a 5m piece, so
      // 30m + 15m instead.
      final q = _work('Report', 45, outcome: true);
      final s3 = Scheduler.schedule(
        [_meeting('A', 8, 40, 20), _meeting('B', 9, 20, 40), q],
        dayStartHour: 8,
        dayEndHour: 10,
      );
      final parts = _sessions(s3, q);
      expect([for (final x in parts) x.startMinutes], [8 * 60, 9 * 60]);
      expect([for (final x in parts) x.durationMinutes], [30, 15]);
    });

    test('finishing early: the top item takes the freed time and splits '
        'around the meeting; the rest move after it', () {
      final item1 = Task(
        title: 'Item 1',
        durationMinutes: 30,
        type: TaskType.floating,
        status: TaskStatus.inProgress,
        startedAt: DateTime(2026, 11, 5, 9, 0),
        date: _day,
      );
      final meeting = _meeting('Meeting', 9, 30, 30);
      final big = _work('Big', 60, outcome: true);
      final a = _work('A', 15);
      final b = Task(
        title: 'B',
        durationMinutes: 20,
        type: TaskType.floating,
        priority: TaskPriority.low,
        date: _day,
      );

      // While Item 1 runs up to the meeting, everything goes after it.
      var s = _run([item1, meeting, big, a, b], now: 9 * 60 + 5);
      expect(_sessions(s, big).single.startMinutes, 10 * 60);
      expect(_sessions(s, a).single.startMinutes, 11 * 60);
      expect(_sessions(s, b).single.startMinutes, 11 * 60 + 15);

      // Finished at 9:10: Big fills 9:10–9:30, then 10:00–10:40.
      final done = item1.copyWith(
        status: TaskStatus.complete,
        completedAt: () => DateTime(2026, 11, 5, 9, 10),
        actualDurationMinutes: () => 10,
      );
      s = _run([done, meeting, big, a, b], now: 9 * 60 + 10);
      final parts = _sessions(s, big);
      expect([for (final p in parts) p.startMinutes], [550, 600]);
      expect([for (final p in parts) p.durationMinutes], [20, 40]);
      expect(_sessions(s, a).single.startMinutes, 10 * 60 + 40);
      expect(_sessions(s, b).single.startMinutes, 10 * 60 + 55);
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
