import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/models/day_schedule.dart';
import 'package:planner/models/scheduled_task.dart';
import 'package:planner/models/task.dart';
import 'package:planner/services/scheduler.dart';
import 'package:planner/state/day_planner_model.dart';

final _day = DateTime(2026, 11, 19);

Task _meeting(String title, int h, int m, int minutes, {DateTime? date}) =>
    Task(
      title: title,
      durationMinutes: minutes,
      type: TaskType.hard,
      startTime: TimeOfDay(hour: h, minute: m),
      date: date ?? _day,
    );

Task _work(
  String title,
  int minutes, {
  bool outcome = false,
  DateTime? doNextAt,
}) => Task(
  title: title,
  durationMinutes: minutes,
  type: TaskType.floating,
  isOutcome: outcome,
  doNextAt: doNextAt,
  date: _day,
);

/// The round-5 testers' Thursday.
List<Task> _thursday() => [
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

int _free(DaySchedule s, {int now = 8 * 60}) {
  final busy = <int>{};
  for (final st in s.committed) {
    for (var m = st.startMinutes; m < st.endMinutes; m++) {
      if (m >= now && m < 18 * 60) busy.add(m);
    }
  }
  return 18 * 60 - now - busy.length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 23 — filling free time', () {
    test('office day: every minute used, no slivers', () {
      final report = _work('Weekly client report', 120, outcome: true);
      final contract = _work('Review contract draft', 60, outcome: true);
      final invoice = _work('Follow up Acme invoice', 15);
      final tasks = [
        report,
        contract,
        _work('Reply to Dana', 10),
        invoice,
        _work('Update client tracker', 45),
        _work('Prep notes for Acme call', 30),
        _work('Expense report', 30),
        _work('Book room', 5),
        _work('Clear inbox', 30),
        _work('Send timesheet', 10),
      ];
      final s = _run([..._thursday(), ...tasks], now: 7 * 60 + 45);

      // 355m of work, 285m free: what's left over doesn't fit.
      expect(_free(s), 0);
      // The 15m gap before 9:00 gets the 15m task.
      expect(_sessions(s, invoice).single.startMinutes, 8 * 60 + 45);
      // Short work is whole; long work is split into sessions of 15m or
      // more only.
      for (final t in tasks) {
        final parts = _sessions(s, t);
        if (parts.isEmpty) continue;
        if (t.durationMinutes <= 30) expect(parts.length, 1, reason: t.title);
        if (parts.length == 1) continue;
        for (final p in parts) {
          expect(p.durationMinutes, greaterThanOrEqualTo(15), reason: t.title);
        }
      }
      final parts = _sessions(s, report);
      expect(parts.fold<int>(0, (m, p) => m + p.durationMinutes), 120);
      // Outcomes take the earliest free time, split if need be.
      expect(
        _sessions(s, contract).fold<int>(0, (m, p) => m + p.durationMinutes),
        60,
      );
    });

    test('short work (30m or less) is never split', () {
      // Two 20m gaps: 8:00–8:20 and 8:40–9:00.
      final t = _work('Call back', 30);
      final s = Scheduler.schedule(
        [_meeting('A', 8, 20, 20), t],
        dayStartHour: 8,
        dayEndHour: 9,
      );
      expect(_sessions(s, t), isEmpty);
      expect(s.overflow, [t]);
    });

    test('a small gap gets the combination that fills it most', () {
      // 8:00–8:25 (25m), then a long gap.
      final a = _work('A', 20);
      final b = _work('B', 15);
      final c = _work('C', 10);
      final s = _run([_meeting('M', 8, 25, 35), a, b, c]);
      expect(_sessions(s, b).single.startMinutes, 8 * 60);
      expect(_sessions(s, c).single.startMinutes, 8 * 60 + 15);
      expect(_sessions(s, a).single.startMinutes, 9 * 60);
    });

    test('the most important work keeps the first free time', () {
      // 8:00–8:25 is free now; short work would fill it best.
      final deck = _work('Deck', 120, outcome: true);
      final reply = _work('Reply', 10);
      final invoice = _work('Invoice', 15);
      final s = _run([
        _meeting('Standup', 8, 25, 15),
        _meeting('1:1', 8, 55, 30),
        deck,
        reply,
        invoice,
      ]);
      final parts = _sessions(s, deck);
      expect([for (final p in parts) p.startMinutes], [8 * 60, 9 * 60 + 25]);
      expect([for (final p in parts) p.durationMinutes], [25, 95]);
      expect(_sessions(s, invoice).single.startMinutes, 8 * 60 + 40);
      expect(_sessions(s, reply).single.startMinutes, 11 * 60);
    });

    test('split Outcome: the earliest free time, gaps in order', () {
      // Gaps: 8:00–8:30, 9:00–9:45, 10:00–12:00.
      final o = _work('Deck', 150, outcome: true);
      final s = Scheduler.schedule(
        [_meeting('A', 8, 30, 30), _meeting('B', 9, 45, 15), o],
        dayStartHour: 8,
        dayEndHour: 12,
      );
      final parts = _sessions(s, o);
      expect(
        [for (final p in parts) p.startMinutes],
        [8 * 60, 9 * 60, 10 * 60],
      );
      expect([for (final p in parts) p.durationMinutes], [30, 45, 75]);
      expect(parts.first.parts, 3);
    });

    test('"Do next" takes the earliest free time, even a small gap', () {
      final first = _work('Write', 60, outcome: true);
      final next = _work('Quick fix', 20, doNextAt: DateTime(2026, 11, 19, 7));
      final s = _run([_meeting('M', 8, 20, 40), first, next]);
      expect(_sessions(s, next).single.startMinutes, 8 * 60);
    });

    test('an Outcome that doesn\'t fully fit is planned in part, before '
        'other work', () {
      // 60m free: 8:00–9:00.
      final o = _work('Deck', 100, outcome: true);
      final chore = _work('Chore', 15);
      final s = Scheduler.schedule([o, chore], dayStartHour: 8, dayEndHour: 9);
      expect(_sessions(s, o).single.durationMinutes, 60);
      expect(s.unplanned[o.id], 40);
      expect(s.overflow, [chore]);
    });

    test('a short Outcome that doesn\'t fit goes to "doesn\'t fit" whole', () {
      final o = _work('Call', 30, outcome: true);
      final s = Scheduler.schedule(
        [_meeting('A', 8, 20, 20), o],
        dayStartHour: 8,
        dayEndHour: 9,
      );
      expect(s.overflow, [o]);
      expect(s.unplanned, isEmpty);
    });
  });

  group('Phase 23 — meetings pause running work', () {
    // Times are relative to the real clock (the model reads it directly).
    final now = DateTime.now();
    final skip = now.hour < 2 || now.hour >= 22;
    final today = DateTime(now.year, now.month, now.day);
    DateTime ago(int minutes) {
      final m = now.hour * 60 + now.minute - minutes;
      return DateTime(now.year, now.month, now.day, m ~/ 60, m % 60);
    }

    Task meetingAt(DateTime start, int minutes, [String title = 'Review']) =>
        _meeting(title, start.hour, start.minute, minutes, date: today);

    late DayPlannerModel model;
    setUp(() => model = DayPlannerModel()..setWorkday(0, 24));
    tearDown(() => model.dispose());

    Task running(int startedMinutesAgo) {
      final t = Task(
        title: 'Write',
        durationMinutes: 240,
        type: TaskType.floating,
        date: today,
      );
      model.addTask(t);
      model.updateTask(
        t.id,
        t.copyWith(
          status: TaskStatus.inProgress,
          startedAt: () => ago(startedMinutesAgo),
        ),
      );
      return t;
    }

    Task get(Task t) => model.tasks.firstWhere((x) => x.id == t.id);

    test('pauses at the meeting\'s start, resumes at its end', () {
      final t = running(40);
      model.addTask(meetingAt(ago(20), 10));
      model.tick();

      final now = get(t);
      expect(now.status, TaskStatus.inProgress);
      expect(now.startedAt, ago(10));
      expect(now.actualDurationMinutes, 20);
      expect(now.pausedRuns.single.end, ago(20));
      final pause = model.takeMeetingPause()!;
      expect(pause.resumed, isTrue);
      expect(model.takeMeetingPause(), isNull);
    }, skip: skip);

    test('during the meeting it waits; Undo works through it', () {
      final t = running(30);
      model.addTask(meetingAt(ago(10), 30));
      model.tick();

      expect(get(t).status, TaskStatus.notStarted);
      expect(get(t).resumeAt, ago(-20));
      expect(get(t).actualDurationMinutes, 20);
      final pause = model.takeMeetingPause()!;
      expect(pause.resumed, isFalse);
      expect(pause.meetingTitle, 'Review');

      model.undoMeetingPause(pause);
      model.tick();
      expect(get(t).status, TaskStatus.inProgress);
      expect(get(t).startedAt, ago(30));
      expect(model.takeMeetingPause(), isNull);
    }, skip: skip);

    test('back-to-back meetings: resumes after the last one', () {
      final t = running(60);
      model
        ..addTask(meetingAt(ago(50), 20, 'One'))
        ..addTask(meetingAt(ago(30), 20, 'Two'));
      model.tick();

      expect(get(t).status, TaskStatus.inProgress);
      expect(get(t).startedAt, ago(10));
      expect(get(t).actualDurationMinutes, 10);
    }, skip: skip);

    test('starting something else cancels the resume', () {
      final t = running(30);
      model.addTask(meetingAt(ago(10), 30));
      model.tick();
      final other = _work('Other', 30).copyWith(date: today);
      model
        ..addTask(other)
        ..startTask(other.id);
      expect(get(t).resumeAt, isNull);
      expect(get(t).status, TaskStatus.notStarted);
    }, skip: skip);

    test('a task started during a meeting keeps running', () {
      model.addTask(meetingAt(ago(20), 40));
      final t = running(10);
      model.tick();
      expect(get(t).status, TaskStatus.inProgress);
      expect(model.takeMeetingPause(), isNull);
    }, skip: skip);

    test('resumeAt round-trips', () {
      final t = _work('A', 30).copyWith(resumeAt: () => DateTime(2026, 1, 1));
      expect(Task.fromJson(t.toJson())!.resumeAt, DateTime(2026, 1, 1));
    });
  });
}
