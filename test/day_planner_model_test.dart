import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/models/task.dart';
import 'package:planner/state/day_planner_model.dart';

/// Floating-task placement depends on the wall clock (tasks are never
/// placed in the past), so the suggestion tests need room left in the
/// day window.
final _tooLateForFloatingTests = TimeOfDay.now().hour >= 20;

Task _floating(String title,
        {int minutes = 30, Priority priority = Priority.medium}) =>
    Task(
      title: title,
      durationMinutes: minutes,
      type: TaskType.floating,
      priority: priority,
      date: DateTime.now(),
    );

int _startOf(DayPlannerModel m, Task t) => m.schedule.committed
    .firstWhere((st) => st.task.id == t.id)
    .startMinutes;

Task _get(DayPlannerModel m, Task t) => m.tasks.firstWhere((x) => x.id == t.id);

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

    test('displacing an already-placed task surfaces a suggestion', () {
      final low = _floating('Low', minutes: 60, priority: Priority.low);
      final high = _floating('High', minutes: 60, priority: Priority.high);
      model.addTask(low);
      model.addTask(high);

      expect(model.suggestion, isNotNull);
      expect(model.suggestion!.moves.map((m) => m.task.id), [low.id]);
    }, skip: _tooLateForFloatingTests);

    test('title-only edit does not surface a suggestion', () {
      final t = _floating('A');
      model.addTask(t);
      model.updateTask(t.id, t.copyWith(title: 'Renamed'));
      expect(model.suggestion, isNull);
    }, skip: _tooLateForFloatingTests);

    test('Dismiss keeps displaced tasks at their previous positions', () {
      final low = _floating('Low', minutes: 60, priority: Priority.low);
      model.addTask(low);
      final before = _startOf(model, low);

      model.addTask(_floating('High', minutes: 60, priority: Priority.high));
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
      final low = _floating('Low', minutes: 60, priority: Priority.low);
      model
        ..addTask(active)
        ..startTask(active.id)
        ..addTask(low)
        ..addTask(_floating('High', minutes: 60, priority: Priority.high));
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
}
