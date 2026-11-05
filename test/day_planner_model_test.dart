import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/models/task.dart';
import 'package:planner/models/calendar_event.dart';
import 'package:planner/services/calendar_source.dart';
import 'package:planner/services/day_repository.dart';
import 'package:planner/state/day_planner_model.dart';

/// Floating-task placement depends on the wall clock (tasks are never
/// placed in the past), so the suggestion tests need room left in the
/// day window.
final _tooLateForFloatingTests = TimeOfDay.now().hour >= 20;

Task _floating(String title,
        {int minutes = 30, bool outcome = false}) =>
    Task(
      title: title,
      durationMinutes: minutes,
      type: TaskType.floating,
      isOutcome: outcome,
      date: DateTime.now(),
    );

int _startOf(DayPlannerModel m, Task t) => m.schedule.committed
    .firstWhere((st) => st.task.id == t.id)
    .startMinutes;

Task _get(DayPlannerModel m, Task t) => m.tasks.firstWhere((x) => x.id == t.id);

/// A 30-minute Meeting placed exactly where [t] is currently scheduled,
/// which pushes [t] later.
Task _meetingOn(DayPlannerModel m, Task t) {
  final start = _startOf(m, t);
  return Task(
    title: 'Meeting',
    durationMinutes: 30,
    type: TaskType.hard,
    startTime: TimeOfDay(hour: start ~/ 60, minute: start % 60),
    date: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 9 — status transitions', () {
    late DayPlannerModel model;
    setUp(() => model = DayPlannerModel());
    tearDown(() => model.dispose());

    test('startTask: notStarted → inProgress with startedAt', () {
      final t = _floating('A');
      model.addTask(t);
      model.startTask(t.id);

      expect(_get(model, t).status, TaskStatus.inProgress);
      expect(_get(model, t).startedAt, isNotNull);
    });

    test('starting one task pauses whatever else was running', () {
      final a = _floating('A');
      final b = _floating('B');
      model
        ..addTask(a)
        ..addTask(b)
        ..startTask(a.id);
      final paused = model.startTask(b.id);
      expect(paused.map((t) => t.id), [a.id]);
      expect(_get(model, a).status, TaskStatus.notStarted);
      expect(_get(model, a).startedAt, isNull);
      expect(_get(model, b).status, TaskStatus.inProgress);
    });

    test('startTask is a no-op unless notStarted', () {
      final t = _floating('A');
      model.addTask(t);
      model.startTask(t.id);
      final firstStart = _get(model, t).startedAt;
      model.startTask(t.id);
      expect(_get(model, t).startedAt, firstStart);

      model.markComplete(t.id, DateTime.now());
      model.startTask(t.id);
      expect(_get(model, t).status, TaskStatus.complete);
    });

    test('cancelTask allowed from notStarted and inProgress', () {
      final a = _floating('A');
      final b = _floating('B');
      model
        ..addTask(a)
        ..addTask(b)
        ..startTask(b.id)
        ..cancelTask(a.id)
        ..cancelTask(b.id);

      expect(_get(model, a).status, TaskStatus.cancelled);
      expect(_get(model, b).status, TaskStatus.cancelled);
    });

    test('cancelTask is a no-op on a complete task', () {
      final t = _floating('A');
      model
        ..addTask(t)
        ..markComplete(t.id, DateTime.now())
        ..cancelTask(t.id);
      expect(_get(model, t).status, TaskStatus.complete);
    });

    test('markComplete on a never-started task records zero tracked time',
        () {
      final t = _floating('A');
      final at = DateTime.now();
      model
        ..addTask(t)
        ..markComplete(t.id, at);

      final done = _get(model, t);
      expect(done.status, TaskStatus.complete);
      expect(done.startedAt, at);
      expect(done.completedAt, at);
      expect(done.actualDurationMinutes, 0);
    });

    test('markComplete on an inProgress task records elapsed minutes', () {
      final t = _floating('A');
      model
        ..addTask(t)
        ..startTask(t.id);
      final startedAt = _get(model, t).startedAt!;
      model.markComplete(t.id, startedAt.add(const Duration(minutes: 42)));

      expect(_get(model, t).actualDurationMinutes, 42);
    });
  });

  group('Phase 9 — adaptive replanning & suggestions', () {
    late DayPlannerModel model;
    setUp(() => model = DayPlannerModel());
    tearDown(() => model.dispose());

    test('adding a floating task into empty space is silent', () {
      model.addTask(_floating('A'));
      expect(model.suggestion, isNull);
    }, skip: _tooLateForFloatingTests);

    test('pushing an Outcome later surfaces a suggestion', () {
      final low = _floating('Low', minutes: 60, outcome: true);
      model.addTask(low);
      model.addTask(_meetingOn(model, low));

      expect(model.suggestion, isNotNull);
      expect(model.suggestion!.moves.map((m) => m.task.id), [low.id]);
    }, skip: _tooLateForFloatingTests);

    test('reshuffling non-outcome work is silent', () {
      model.addTask(_floating('Long', minutes: 60));
      model.addTask(_floating('Short', minutes: 15));
      expect(model.suggestion, isNull);
    }, skip: _tooLateForFloatingTests);

    test('an Outcome moving earlier is silent', () {
      final first = _floating('First', minutes: 30, outcome: true);
      final second = _floating('Second', minutes: 60, outcome: true);
      model.addTask(first);
      model.addTask(second);
      model.acceptSuggestion();
      model.removeTask(first.id);
      expect(model.suggestion, isNull);
    }, skip: _tooLateForFloatingTests);

    test('work pushed out of the day is reported', () {
      final now = TimeOfDay.now();
      final left = 23 * 60 - (now.hour * 60 + now.minute);
      final filler = _floating('Filler', minutes: left);
      model.addTask(filler);
      model.addTask(_floating('Urgent', minutes: 5, outcome: true));
      expect(model.suggestion?.pushedOut.map((t) => t.id), [filler.id]);
    }, skip: TimeOfDay.now().hour >= 15 || TimeOfDay.now().hour < 6);

    test('title-only edit does not surface a suggestion', () {
      final t = _floating('A');
      model.addTask(t);
      model.updateTask(t.id, t.copyWith(title: 'Renamed'));
      expect(model.suggestion, isNull);
    }, skip: _tooLateForFloatingTests);

    test('Dismiss keeps displaced tasks at their previous positions', () {
      final first = _floating('First', minutes: 30, outcome: true);
      final low = _floating('Low', minutes: 60, outcome: true);
      model
        ..addTask(first)
        ..addTask(low);
      final before = _startOf(model, low);

      // Lengthening the first Outcome pushes the second one later.
      model.updateTask(first.id, first.copyWith(durationMinutes: 90));
      expect(model.suggestion, isNotNull);

      model.dismissSuggestion();
      expect(_startOf(model, low), before,
          reason: 'Dismiss should discard the proposed move');
    }, skip: _tooLateForFloatingTests);
  });

  group('Phase 9 — overrun monitor', () {
    testWidgets('periodic check does not wipe a pending suggestion',
        (tester) async {
      final model = DayPlannerModel();
      final active = _floating('Active');
      final first = _floating('First', minutes: 30, outcome: true);
      final low = _floating('Low', minutes: 60, outcome: true);
      model
        ..addTask(active)
        ..startTask(active.id)
        ..addTask(first)
        ..addTask(low)
        ..updateTask(first.id, first.copyWith(durationMinutes: 90));
      expect(model.suggestion, isNotNull);

      await tester.pump(const Duration(seconds: 31));
      final survived = model.suggestion != null;
      model.dispose();

      expect(survived, isTrue,
          reason: 'User has not accepted/dismissed the banner yet');
    }, skip: _tooLateForFloatingTests);
  });

  group('Phase 8 — persistence of new fields', () {
    test('toJson/fromJson round-trips status, startedAt, actualDuration', () {
      final t = Task(
        title: 'A',
        durationMinutes: 30,
        type: TaskType.floating,
        status: TaskStatus.complete,
        startedAt: DateTime(2026, 10, 10, 9),
        completedAt: DateTime(2026, 10, 10, 9, 42),
        actualDurationMinutes: 42,
        date: DateTime(2026, 10, 10),
      );
      final back = Task.fromJson(t.toJson())!;
      expect(back.status, TaskStatus.complete);
      expect(back.startedAt, t.startedAt);
      expect(back.actualDurationMinutes, 42);
    });
  });

  group('Phase 10 — outcomes', () {
    late DayPlannerModel model;
    setUp(() => model = DayPlannerModel());
    tearDown(() => model.dispose());

    test('adding beyond the outcome cap is rejected', () {
      for (var i = 0; i < 3; i++) {
        model.addTask(_floating('O$i', outcome: true));
      }
      expect(() => model.addTask(_floating('O3', outcome: true)),
          throwsArgumentError);
      expect(model.tasks.length, 3);
    });

    test('the cap is configurable', () {
      model.outcomeCap = 1;
      model.addTask(_floating('O0', outcome: true));
      expect(() => model.addTask(_floating('O1', outcome: true)),
          throwsArgumentError);
    });

    test('cancelled outcomes free a slot; editing one does not self-count',
        () {
      model.outcomeCap = 1;
      final first = _floating('O0', outcome: true);
      model.addTask(first);
      model.updateTask(first.id, first.copyWith(title: 'Renamed'));
      model.cancelTask(first.id);
      model.addTask(_floating('O1', outcome: true));
      expect(model.tasks.where((t) => t.isOutcome).length, 2);
    });

    test('isOutcome / isInterruption round-trip; legacy priority ignored', () {
      final t = _floating('A', outcome: true).copyWith(isInterruption: true);
      final back = Task.fromJson(t.toJson())!;
      expect(back.isOutcome, isTrue);
      expect(back.isInterruption, isTrue);

      final legacy = t.toJson()
        ..remove('isOutcome')
        ..remove('isInterruption')
        ..['priority'] = 'high';
      final old = Task.fromJson(legacy)!;
      expect(old.isOutcome, isFalse);
      expect(old.isInterruption, isFalse);
    });
  });

  group('Phase 10 — moveToDate', () {
    final today = DateTime(2026, 10, 10);
    final tomorrow = DateTime(2026, 10, 11);
    late _MemoryRepository repo;
    late DayPlannerModel model;

    setUp(() async {
      repo = _MemoryRepository();
      model = DayPlannerModel(initialDate: today, repository: repo);
      await model.loadDate(today);
    });
    tearDown(() => model.dispose());

    Task task(String title, {bool outcome = false}) => Task(
          title: title,
          durationMinutes: 30,
          type: TaskType.pinned,
          startTime: const TimeOfDay(hour: 22, minute: 0),
          isOutcome: outcome,
          date: today,
        );

    test('moves to the target day, reset and unpinned', () async {
      final t = task('A');
      model.addTask(t);
      model.startTask(t.id);

      await model.moveToDate(t.id, tomorrow);

      expect(model.tasks, isEmpty);
      final moved = (await repo.load(tomorrow)).single;
      expect(moved.id, t.id);
      expect(moved.date, tomorrow);
      expect(moved.carriedFromDate, today);
      expect(moved.status, TaskStatus.notStarted);
      expect(moved.startedAt, isNull);
      expect(moved.type, TaskType.floating);
      expect(moved.startTime, isNull);
    });

    test('keeps Outcome unless the target day is full', () async {
      model.outcomeCap = 1;
      final a = task('A', outcome: true);
      model.addTask(a);
      await model.moveToDate(a.id, tomorrow);
      expect((await repo.load(tomorrow)).single.isOutcome, isTrue);

      final b = task('B', outcome: true);
      model.addTask(b);
      await model.moveToDate(b.id, tomorrow);
      final bMoved =
          (await repo.load(tomorrow)).firstWhere((t) => t.id == b.id);
      expect(bMoved.isOutcome, isFalse);
    });

    test('a future day is planned from the start of the day window',
        () async {
      final future = DateTime.now().add(const Duration(days: 2));
      await model.setViewedDate(future);
      final t = Task(
        title: 'F',
        durationMinutes: 30,
        type: TaskType.floating,
        date: future,
      );
      model.addTask(t);
      expect(_startOf(model, t), 6 * 60);
      expect(model.isViewingToday, isFalse);
      expect(model.currentItem, isNull);
    });

    test('undoMoveToDate brings the task back', () async {
      final t = task('A', outcome: true);
      model.addTask(t);
      await model.moveToDate(t.id, tomorrow);
      await model.undoMoveToDate(t, tomorrow);
      expect(model.tasks.single.id, t.id);
      expect(model.tasks.single.isOutcome, isTrue);
      expect(await repo.load(tomorrow), isEmpty);
    });

    test('day navigation no longer carries tasks forward', () async {
      model.addTask(task('A'));
      await model.setViewedDate(tomorrow);
      expect(model.tasks, isEmpty);
    });
  });

  group('Phase 12 review — validation', () {
    late DayPlannerModel model;
    setUp(() => model = DayPlannerModel());
    tearDown(() => model.dispose());

    Task fixed(String title, TaskType type, int hour, {int minutes = 60}) =>
        Task(
          title: title,
          durationMinutes: minutes,
          type: type,
          startTime: TimeOfDay(hour: hour, minute: 0),
          date: DateTime.now(),
        );

    test('a Meeting may not overlap a Set-time item, and vice versa', () {
      model.addTask(fixed('Pinned', TaskType.pinned, 10));
      expect(() => model.addTask(fixed('Meeting', TaskType.hard, 10)),
          throwsArgumentError);
      model.addTask(fixed('Meeting', TaskType.hard, 12));
      expect(() => model.addTask(fixed('Pinned 2', TaskType.pinned, 12)),
          throwsArgumentError);
    });

    test('finished fixed items free their slot', () {
      final a = fixed('A', TaskType.pinned, 10);
      model.addTask(a);
      model.cancelTask(a.id);
      model.addTask(fixed('B', TaskType.hard, 10));
      expect(model.tasks.length, 2);
    });

    test('lowering the cap never locks editing existing Outcomes', () {
      final outcomes = [
        for (var i = 0; i < 3; i++) _floating('O$i', outcome: true),
      ];
      outcomes.forEach(model.addTask);
      model.outcomeCap = 2;
      model.updateTask(outcomes[0].id, outcomes[0].copyWith(title: 'Renamed'));
      expect(model.tasks.first.title, 'Renamed');
      final plain = _floating('Plain');
      model.addTask(plain);
      expect(() => model.updateTask(plain.id, plain.copyWith(isOutcome: true)),
          throwsArgumentError);
    });
  });

  group('Phase 14 — calendar import', () {
    final day = DateTime.now();
    DateTime at(int h, [int m = 0]) =>
        DateTime(day.year, day.month, day.day, h, m);

    test('timed events become read-only Meetings; all-day are labels',
        () async {
      final source = _FakeCalendar([
        CalendarEvent(
            id: 'e1',
            calendarId: 'work',
            title: 'Board prep',
            start: at(14),
            end: at(15)),
        CalendarEvent(
            id: 'e2',
            calendarId: 'work',
            title: 'Offsite',
            start: at(0),
            end: at(23, 59),
            isAllDay: true),
      ]);
      final model = DayPlannerModel(calendarSource: source);
      await model.loadDate(day);

      final meeting = model.schedule.committed.single.task;
      expect(meeting.title, 'Board prep');
      expect(meeting.type, TaskType.hard);
      expect(meeting.durationMinutes, 60);
      expect(model.isImported(meeting), isTrue);
      expect(model.tasks, isEmpty, reason: 'imported events are not tasks');
      expect(model.allDayEvents.single.title, 'Offsite');
      model.dispose();
    });

    test('imported meetings block overlapping fixed items', () async {
      final model = DayPlannerModel(
        calendarSource: _FakeCalendar([
          CalendarEvent(
              id: 'e1',
              calendarId: 'c',
              title: 'Sync',
              start: at(9),
              end: at(10)),
        ]),
      );
      await model.loadDate(day);
      expect(
        () => model.addTask(Task(
          title: 'Call',
          durationMinutes: 30,
          type: TaskType.pinned,
          startTime: const TimeOfDay(hour: 9, minute: 30),
          date: day,
        )),
        throwsArgumentError,
      );
      model.dispose();
    });

    test('calendar selection is passed to the source; failures are ignored',
        () async {
      final source = _FakeCalendar([], fail: true);
      final model = DayPlannerModel(calendarSource: source)
        ..calendarIds = {'work'};
      await model.loadDate(day);
      expect(source.lastIds, {'work'});
      expect(model.schedule.committed, isEmpty);
      model.dispose();
    });
  });
}

class _MemoryRepository implements DayRepository {
  final _days = <DateTime, List<Task>>{};

  @override
  Future<List<Task>> load(DateTime date) async => List.of(_days[date] ?? []);

  @override
  Future<void> save(DateTime date, List<Task> tasks) async =>
      _days[date] = List.of(tasks);
}

class _FakeCalendar implements CalendarSource {
  _FakeCalendar(this.events, {this.fail = false});

  final List<CalendarEvent> events;
  final bool fail;
  Set<String>? lastIds;

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<List<DeviceCalendarInfo>> listCalendars() async => const [];

  @override
  Future<List<CalendarEvent>> eventsFor(
    DateTime date,
    Set<String>? calendarIds,
  ) async {
    lastIds = calendarIds;
    if (fail) throw StateError('no access');
    return events;
  }
}
