import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/core/utils.dart';
import 'package:planner/models/recurring_task.dart';
import 'package:planner/models/settings.dart';
import 'package:planner/models/task.dart';
import 'package:planner/services/capture_parser.dart';
import 'package:planner/services/day_repository.dart';
import 'package:planner/services/day_stats.dart';
import 'package:planner/services/recurring_repository.dart';
import 'package:planner/services/scheduler.dart';
import 'package:planner/state/day_planner_model.dart';

/// Thursday 5 November 2026.
final _thu = DateTime(2026, 11, 5);

ParsedCapture _p(String s) => CaptureParser.parse(s, today: _thu);

DateTime _d(DateTime t) => DateTime(t.year, t.month, t.day);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 17 — capture parser reads ordinary sentences', () {
    test('a time inside the sentence stays in the title', () {
      final p = _p('Email team re 2pm meeting');
      expect(p.title, 'Email team re 2pm meeting');
      expect(p.startTime, isNull);
    });

    test('a time after "at" counts anywhere', () {
      final p = _p('Lunch at 1pm with Sam');
      expect(p.title, 'Lunch with Sam');
      expect(p.startTime, const TimeOfDay(hour: 13, minute: 0));
    });

    test('a weekday at the end sets the day', () {
      final p = _p('Book flight 9am Friday');
      expect(p.title, 'Book flight');
      expect(p.startTime, const TimeOfDay(hour: 9, minute: 0));
      expect(p.date, DateTime(2026, 11, 6));
    });

    test('"tomorrow", "today", and "on <weekday>"', () {
      final t = _p('Prep deck tomorrow 1h');
      expect(t.title, 'Prep deck');
      expect(t.durationMinutes, 60);
      expect(t.date, DateTime(2026, 11, 6));
      expect(_p('Pay rent today').date, _thu);
      final on = _p('Dentist on Monday at 3');
      expect(on.title, 'Dentist');
      expect(on.date, DateTime(2026, 11, 9));
      expect(on.startTime, const TimeOfDay(hour: 15, minute: 0));
    });

    test('the same weekday means today; a weekday mid-sentence is title', () {
      expect(_p('Standup notes Thursday').date, _thu);
      final p = _p('Plan Friday party');
      expect(p.title, 'Plan Friday party');
      expect(p.date, isNull);
    });

    test('"at 3" is a time, read inside the workday', () {
      final p = _p('Call Bob at 3');
      expect(p.title, 'Call Bob');
      expect(p.startTime, const TimeOfDay(hour: 15, minute: 0));
      expect(
        _p('Call Bob at 9').startTime,
        const TimeOfDay(hour: 9, minute: 0),
      );
      expect(
        _p('Call Bob at 3:30').startTime,
        const TimeOfDay(hour: 15, minute: 30),
      );
      // A bare number without "at" is just a number.
      expect(_p('Q1 plan for 3 teams').startTime, isNull);
      expect(_p('Look at 3 options').startTime, isNull);
    });

    test('"*" only marks an Outcome alone or at either end', () {
      final mid = _p('Fix 5* rating bug');
      expect(mid.isOutcome, isFalse);
      expect(mid.title, 'Fix 5* rating bug');
      expect(_p('Ship the memo*').isOutcome, isTrue);
      expect(_p('*Ship the memo').title, 'Ship the memo');
      expect(_p('Prep board deck 2h *').isOutcome, isTrue);
    });
  });

  group('Phase 17 — a running task does not hide a meeting', () {
    final running = Task(
      title: 'Write',
      durationMinutes: 90,
      type: TaskType.floating,
      status: TaskStatus.inProgress,
      startedAt: DateTime(2026, 11, 5, 10, 20),
      date: _thu,
    );
    final meeting = Task(
      title: 'Product review',
      durationMinutes: 60,
      type: TaskType.hard,
      startTime: const TimeOfDay(hour: 11, minute: 0),
      date: _thu,
    );
    final schedule = Scheduler.schedule(
      [running, meeting],
      dayStartHour: 8,
      dayEndHour: 18,
      nowMinutes: 11 * 60 + 2,
    );

    test('the meeting that has started takes the Now card', () {
      expect(DayStats.currentItem(schedule, 11 * 60 + 2)!.task, meeting);
      expect(DayStats.runningItem(schedule)!.task, running);
    });

    test('before the meeting, the running task keeps the card', () {
      expect(DayStats.currentItem(schedule, 10 * 60 + 56)!.task, running);
      expect(DayStats.nextFixedItem(schedule, 10 * 60 + 56)!.task, meeting);
    });
  });

  group('Phase 17 — days', () {
    test('the next workday skips the weekend', () {
      expect(
        AppUtils.nextWorkday(DateTime(2026, 11, 6)),
        DateTime(2026, 11, 9),
      );
      expect(
        AppUtils.nextWorkday(DateTime(2026, 11, 7)),
        DateTime(2026, 11, 9),
      );
      expect(AppUtils.nextWorkday(_thu), DateTime(2026, 11, 6));
    });

    test('friendly dates', () {
      expect(AppUtils.dayPhrase(DateTime(2026, 11, 6), _thu), 'tomorrow');
      expect(AppUtils.dayPhrase(DateTime(2026, 11, 9), _thu), 'Monday');
      expect(AppUtils.dayPhrase(DateTime(2026, 11, 24), _thu), 'Tue, Nov 24');
    });
  });

  group('Phase 17 — model', () {
    late _MemoryRepository repo;
    late _MemoryRecurring recurring;
    late DayPlannerModel model;
    final future = _d(DateTime.now().add(const Duration(days: 10)));

    setUp(() {
      repo = _MemoryRepository();
      recurring = _MemoryRecurring();
      model = DayPlannerModel(repository: repo, recurringRepository: recurring);
    });
    tearDown(() => model.dispose());

    test('pauseTask keeps tracked minutes; only the rest is planned', () async {
      await model.loadDate(future);
      final t = Task(
        title: 'Write',
        durationMinutes: 60,
        type: TaskType.floating,
        date: future,
      );
      model.addTask(t);
      model.updateTask(
        t.id,
        t.copyWith(
          status: TaskStatus.inProgress,
          startedAt: () => DateTime.now().subtract(const Duration(minutes: 20)),
        ),
      );
      expect(model.pauseTask(t.id), isNotNull);
      final paused = model.tasks.single;
      expect(paused.status, TaskStatus.notStarted);
      expect(paused.actualDurationMinutes, 20);
      expect(model.schedule.committed.single.durationMinutes, 40);
    });

    test('reorderOutcomes changes which Outcome is planned first', () async {
      await model.loadDate(future);
      final a = Task(
        title: 'A',
        durationMinutes: 60,
        type: TaskType.floating,
        isOutcome: true,
        date: future,
      );
      final b = a.copyWith(id: 'b', title: 'B');
      model
        ..addTask(a)
        ..addTask(b)
        ..reorderOutcomes([b.id, a.id]);
      expect(model.tasks.map((t) => t.title), ['B', 'A']);
      expect(model.schedule.committed.first.task.title, 'B');
      expect(model.suggestion, isNull);
    });

    test('addTaskToDate saves to another day without opening it', () async {
      await model.loadDate(future);
      final other = future.add(const Duration(days: 1));
      final t = Task(
        title: 'Book flight',
        durationMinutes: 30,
        type: TaskType.pinned,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        date: future,
      );
      final saved = await model.addTaskToDate(t, other);
      expect(saved.date, other);
      expect(model.tasks, isEmpty);
      expect((await repo.load(other)).single.title, 'Book flight');

      // A clash on that day is rejected.
      expect(
        () => model.addTaskToDate(t.copyWith(id: 'x'), other),
        throwsArgumentError,
      );
    });

    test('a repeating task gets a copy on each day it repeats', () async {
      await model.loadDate(future);
      final t = Task(
        title: 'Inbox zero',
        durationMinutes: 30,
        type: TaskType.floating,
        date: future,
      );
      model.addTask(t);
      await model.setRepeat(t.id, Repeat.daily);
      expect(model.repeatOf(model.tasks.single), Repeat.daily);
      expect(recurring.saved.single.title, 'Inbox zero');

      await model.setViewedDate(future.add(const Duration(days: 1)));
      final copy = model.tasks.single;
      expect(copy.title, 'Inbox zero');
      expect(copy.id, isNot(t.id));
      expect(copy.recurringId, recurring.saved.single.id);

      // Deleting a copy keeps that day free of it.
      model.removeTask(copy.id);
      await model.setViewedDate(future);
      await model.setViewedDate(future.add(const Duration(days: 1)));
      expect(model.tasks, isEmpty);
    });

    test('weekday and weekly series skip the right days', () {
      final base = Task(
        title: 'x',
        durationMinutes: 30,
        type: TaskType.floating,
        date: _thu,
      );
      final weekdays = RecurringTask.fromTask(
        base,
        repeat: Repeat.weekdays,
        weekday: _thu.weekday,
        startDate: _thu,
      );
      expect(weekdays.occursOn(DateTime(2026, 11, 6)), isTrue);
      expect(weekdays.occursOn(DateTime(2026, 11, 7)), isFalse);
      expect(weekdays.occursOn(DateTime(2026, 11, 4)), isFalse);
      final weekly = RecurringTask.fromTask(
        base,
        repeat: Repeat.weekly,
        weekday: _thu.weekday,
        startDate: _thu,
      );
      expect(weekly.occursOn(DateTime(2026, 11, 12)), isTrue);
      expect(weekly.occursOn(DateTime(2026, 11, 11)), isFalse);
      expect(RecurringTask.fromJson(weekly.toJson())!.repeat, Repeat.weekly);
    });

    test('breathing room gives way when it would push work out', () async {
      // A 2-hour workday with 15 minutes of breathing room.
      model
        ..setWorkday(8, 10)
        ..setBufferMinutes(15);
      await model.loadDate(future);
      final a = Task(
        title: 'A',
        durationMinutes: 60,
        type: TaskType.floating,
        date: future,
      );
      final b = a.copyWith(id: 'b', title: 'B', durationMinutes: 30);
      model
        ..addTask(a)
        ..addTask(b);
      // 30m + 15m + 60m fits: the room is kept (B first, shorter).
      expect(model.schedule.overflow, isEmpty);
      expect(
        model.schedule.committed
            .firstWhere((st) => st.task.id == a.id)
            .startMinutes,
        8 * 60 + 45,
      );

      // 50m + 15m + 60m doesn't, but 50m + 60m does: the room gives way.
      model.updateTask(b.id, b.copyWith(durationMinutes: 50));
      expect(model.schedule.overflow, isEmpty);
      expect(
        model.schedule.committed
            .firstWhere((st) => st.task.id == a.id)
            .startMinutes,
        8 * 60 + 50,
      );
    });

    test('lastSevenDays returns the viewed day and the six before', () async {
      final earlier = future.subtract(const Duration(days: 3));
      await repo.save(earlier, [
        Task(
          title: 'Done earlier',
          durationMinutes: 30,
          type: TaskType.floating,
          isOutcome: true,
          status: TaskStatus.complete,
          actualDurationMinutes: 30,
          date: earlier,
        ),
      ]);
      await model.loadDate(future);
      final days = await model.lastSevenDays();
      expect(days.length, 7);
      expect(days.last.$1, future);
      final (_, tasks) = days.firstWhere((d) => d.$1 == earlier);
      expect(DayStats.outcomesHit(tasks), (1, 1));
      expect(DayStats.workedMinutes(tasks), (30, 30));
    });
  });

  test('breathing room round-trips; invalid falls back to 5m', () {
    const s = Settings(bufferMinutes: 10);
    expect(Settings.fromJson(s.toJson()).bufferMinutes, 10);
    expect(Settings.fromJson({'bufferMinutes': 7}).bufferMinutes, 5);
  });
}

class _MemoryRepository implements DayRepository {
  final _days = <DateTime, List<Task>>{};

  @override
  Future<List<Task>> load(DateTime date) async =>
      List.of(_days[_d(date)] ?? const []);

  @override
  Future<void> save(DateTime date, List<Task> tasks) async =>
      _days[_d(date)] = List.of(tasks);
}

class _MemoryRecurring implements RecurringRepository {
  List<RecurringTask> saved = [];

  @override
  Future<List<RecurringTask>> load() async => List.of(saved);

  @override
  Future<void> save(List<RecurringTask> series) async =>
      saved = List.of(series);
}
