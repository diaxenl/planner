import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/app.dart';
import 'package:planner/features/day/widgets/now_card.dart';
import 'package:planner/features/day/widgets/now_drawer.dart';
import 'package:planner/features/day/widgets/outcomes_list.dart';
import 'package:planner/features/day/widgets/schedule_timeline.dart';
import 'package:planner/models/scheduled_task.dart';
import 'package:planner/models/task.dart';
import 'package:planner/state/day_planner_model.dart';
import 'package:planner/state/day_planner_provider.dart';
import 'package:planner/state/settings_model.dart';
import 'package:planner/state/settings_provider.dart';

Widget _app(DayPlannerModel model) => SettingsProvider(
  model: SettingsModel(),
  child: DayPlannerProvider(model: model, child: const HyperDayApp()),
);

/// A future day (nothing depends on the clock) with one Outcome and
/// one other item.
Future<DayPlannerModel> _futureDay(WidgetTester tester) async {
  final model = DayPlannerModel();
  await tester.runAsync(
    () => model.loadDate(DateTime.now().add(const Duration(days: 10))),
  );
  model
    ..addTask(
      Task(
        title: 'Prep board deck',
        durationMinutes: 60,
        type: TaskType.floating,
        isOutcome: true,
        date: model.viewedDate,
      ),
    )
    ..addTask(
      Task(
        title: 'Review PRs',
        durationMinutes: 30,
        type: TaskType.floating,
        date: model.viewedDate,
      ),
    );
  return model;
}

ScheduledTask _at(Task t, int startMinutes) => ScheduledTask(
  task: t,
  computedStartTime: TimeOfDay(
    hour: startMinutes ~/ 60,
    minute: startMinutes % 60,
  ),
  durationMinutes: t.durationMinutes,
);

void main() {
  testWidgets('Outcomes live only in the Now drawer, closed by default', (
    tester,
  ) async {
    final model = await _futureDay(tester);
    await tester.pumpWidget(_app(model));
    await tester.pump();

    expect(find.byType(NowDrawer), findsOneWidget);
    expect(find.byType(OutcomesList), findsNothing);
    // Not today: the bar shows the Outcomes count, no Now card.
    expect(find.text('0 of 1 done'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('now-drawer-open')));
    await tester.pumpAndSettle();
    expect(find.byType(OutcomesList), findsOneWidget);
    expect(find.byType(NowCard), findsNothing);

    await tester.tap(find.byKey(const ValueKey('now-drawer-close')));
    await tester.pumpAndSettle();
    expect(find.byType(OutcomesList), findsNothing);
    expect(tester.takeException(), isNull);
    model.dispose();
  });

  testWidgets('holding down on empty schedule adds an Outcome at that time', (
    tester,
  ) async {
    final model = await _futureDay(tester);
    await tester.pumpWidget(_app(model));
    await tester.pump();

    final empty = find.byKey(const ValueKey('timeline-empty'));
    // Bring the timeline's top into view, then press 3h in (on an hour
    // line, which lets it through): past the two placed items (1h 30m
    // from the start of the day).
    await tester.ensureVisible(find.byType(ScheduleTimeline));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    final box = tester.getRect(empty);
    final y = box.top + 180 * ScheduleTimeline.pxPerMinute;
    expect(y, lessThan(tester.getRect(find.byType(NowDrawer)).top));
    await tester.longPressAt(Offset(box.right - 10, y));
    await tester.pumpAndSettle();

    expect(find.text('New item'), findsOneWidget);
    final outcomeSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Outcome'),
    );
    expect(outcomeSwitch.value, isTrue);
    expect(tester.takeException(), isNull);
    model.dispose();
  });

  testWidgets('a long press on a block does not start a new Outcome', (
    tester,
  ) async {
    final model = await _futureDay(tester);
    await tester.pumpWidget(_app(model));
    await tester.pump();

    final block = find.descendant(
      of: find.byType(ScheduleTimeline),
      matching: find.text('Review PRs'),
    );
    await tester.longPress(block);
    await tester.pumpAndSettle();
    expect(find.text('New item'), findsNothing);
    model.dispose();
  });

  group('NowReadout', () {
    final now = DateTime(2030, 1, 7, 10, 22, 14);

    test('a running task: elapsed, estimate, and when it ends', () {
      final t = Task(
        title: 'Draft plan',
        durationMinutes: 60,
        type: TaskType.floating,
        status: TaskStatus.inProgress,
        startedAt: DateTime(2030, 1, 7, 10, 0),
        date: DateTime(2030, 1, 7),
      );
      final r = NowReadout.of(_at(t, 600), now);
      expect(r.label, 'NOW');
      expect(r.short, 'of 1h');
      expect(r.detail, contains('until'));
      expect(r.overMinutes, 0);
      expect(r.progress, closeTo(22.23 / 60, 0.01));
    });

    test('past the estimate: over, full progress', () {
      final t = Task(
        title: 'Draft plan',
        durationMinutes: 15,
        type: TaskType.floating,
        status: TaskStatus.inProgress,
        startedAt: DateTime(2030, 1, 7, 10, 0),
        date: DateTime(2030, 1, 7),
      );
      final r = NowReadout.of(_at(t, 600), now);
      expect(r.overMinutes, 7);
      expect(r.short, '+7m over');
      expect(r.progress, 1);
    });

    test('ahead and not started: a countdown, no progress', () {
      final t = Task(
        title: 'Later',
        durationMinutes: 30,
        type: TaskType.floating,
        date: DateTime(2030, 1, 7),
      );
      final r = NowReadout.of(_at(t, 660), now);
      expect(r.label, 'UP NEXT');
      expect(r.progress, isNull);
    });
  });
}
