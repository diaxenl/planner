import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/app.dart';
import 'package:planner/features/day/widgets/capture_bar.dart';
import 'package:planner/features/day/widgets/schedule_timeline.dart';
import 'package:planner/features/day/widgets/start_prompt.dart';
import 'package:planner/models/scheduled_task.dart';
import 'package:planner/models/task.dart';
import 'package:planner/services/capture_parser.dart';
import 'package:planner/state/day_planner_model.dart';
import 'package:planner/state/day_planner_provider.dart';
import 'package:planner/state/settings_model.dart';
import 'package:planner/state/settings_provider.dart';

Widget _app(DayPlannerModel model, SettingsModel settings) => SettingsProvider(
  model: settings,
  child: DayPlannerProvider(model: model, child: const HyperDayApp()),
);

final _day = DateTime(2030, 1, 7);

ScheduledTask _at(
  String title,
  int hour,
  int minute,
  int duration, {
  TaskType type = TaskType.floating,
}) => ScheduledTask(
  task: Task(title: title, durationMinutes: duration, type: type, date: _day),
  computedStartTime: TimeOfDay(hour: hour, minute: minute),
);

/// A future day, so nothing depends on the clock.
Future<DayPlannerModel> _futureDay(WidgetTester tester) async {
  final model = DayPlannerModel();
  await tester.runAsync(
    () => model.loadDate(DateTime.now().add(const Duration(days: 10))),
  );
  return model;
}

void main() {
  group('TimelineLayout', () {
    test('shows the workday on whole hours, widened for items outside it', () {
      final layout = TimelineLayout.of(
        [_at('Early call', 7, 30, 30, type: TaskType.hard)],
        dayStartHour: 9,
        dayEndHour: 17,
      );
      expect(layout.startMinutes, 7 * 60);
      expect(layout.endMinutes, 17 * 60);

      final late = TimelineLayout.of(
        [_at('Late', 18, 0, 45, type: TaskType.pinned)],
        dayStartHour: 9,
        dayEndHour: 17,
      );
      expect(late.endMinutes, 19 * 60);
    });

    test(
      'overlapping meetings sit side by side; others get the full width',
      () {
        final layout = TimelineLayout.of(
          [
            _at('A', 9, 0, 60, type: TaskType.hard),
            _at('B', 9, 30, 60, type: TaskType.hard),
            _at('C', 10, 0, 30, type: TaskType.hard), // A's lane is free again
            _at('D', 12, 0, 30),
          ],
          dayStartHour: 9,
          dayEndHour: 17,
        );
        final byTitle = {for (final b in layout.blocks) b.entry.task.title: b};
        expect((byTitle['A']!.lane, byTitle['A']!.lanes), (0, 2));
        expect((byTitle['B']!.lane, byTitle['B']!.lanes), (1, 2));
        expect((byTitle['C']!.lane, byTitle['C']!.lanes), (0, 2));
        expect((byTitle['D']!.lane, byTitle['D']!.lanes), (0, 1));
      },
    );

    test('free gaps of 15m+ inside the workday, from now on', () {
      final entries = [
        _at('A', 9, 0, 60),
        _at('B', 10, 10, 50), // 10m gap: too short to label
        _at('C', 13, 0, 60),
      ];
      final gaps = TimelineLayout.of(
        entries,
        dayStartHour: 9,
        dayEndHour: 17,
      ).gaps.map((g) => (g.startMinutes, g.endMinutes));
      expect(gaps, [(11 * 60, 13 * 60), (14 * 60, 17 * 60)]);

      final fromNow = TimelineLayout.of(
        entries,
        dayStartHour: 9,
        dayEndHour: 17,
        nowMinutes: 12 * 60 + 30,
      ).gaps.map((g) => (g.startMinutes, g.endMinutes));
      expect(fromNow, [(12 * 60 + 30, 13 * 60), (14 * 60, 17 * 60)]);
    });
  });

  test('shorthand chip tokens parse together', () {
    final p = CaptureParser.parse(
      'Call Bob 1h tomorrow *',
      today: DateTime(2030, 1, 7),
    );
    expect(p.title, 'Call Bob');
    expect(p.durationMinutes, 60);
    expect(p.isOutcome, isTrue);
    expect(p.date, DateTime(2030, 1, 8));
  });

  testWidgets('an empty day asks for one thing and plans it as an Outcome', (
    tester,
  ) async {
    final model = await _futureDay(tester);
    await tester.pumpWidget(_app(model, SettingsModel()));
    await tester.pump();

    expect(find.byType(StartPrompt), findsOneWidget);
    expect(find.text('OUTCOMES'), findsNothing);

    await tester.enterText(
      find.descendant(
        of: find.byType(StartPrompt),
        matching: find.byType(TextField),
      ),
      'Finish the proposal',
    );
    await tester.pump();
    await tester.tap(find.text('Plan it'));
    await tester.pump();

    final added = model.tasks.single;
    expect(added.title, 'Finish the proposal');
    expect(added.isOutcome, isTrue);
    expect(added.durationMinutes, 60);
    expect(find.byType(StartPrompt), findsNothing);
    expect(find.text('OUTCOMES'), findsOneWidget);
    expect(find.byType(ScheduleTimeline), findsOneWidget);
    expect(tester.takeException(), isNull);

    model.dispose();
  });

  testWidgets('the timeline shows blocks and free time; tap opens the item', (
    tester,
  ) async {
    final model = await _futureDay(tester);
    model
      ..addTask(
        Task(
          title: 'Standup',
          durationMinutes: 15,
          type: TaskType.pinned,
          startTime: const TimeOfDay(hour: 9, minute: 0),
          date: model.viewedDate,
        ),
      )
      ..addTask(
        Task(
          title: 'Board deck',
          durationMinutes: 90,
          type: TaskType.floating,
          isOutcome: true,
          date: model.viewedDate,
        ),
      );
    await tester.pumpWidget(_app(model, SettingsModel()));
    await tester.pump();

    final timeline = find.byType(ScheduleTimeline);
    expect(
      find.descendant(of: timeline, matching: find.text('Standup')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: timeline, matching: find.textContaining(' free')),
      findsWidgets,
    );
    // Not today: no now line.
    expect(find.byKey(const ValueKey('timeline-now')), findsNothing);

    final standup = find.descendant(
      of: timeline,
      matching: find.text('Standup'),
    );
    await tester.ensureVisible(standup);
    await tester.pumpAndSettle();
    await tester.tap(standup);
    await tester.pumpAndSettle();
    expect(find.text('Edit item'), findsOneWidget);
    expect(tester.takeException(), isNull);

    model.dispose();
  });

  testWidgets('shorthand chips appear on focus and append their token', (
    tester,
  ) async {
    final model = await _futureDay(tester);
    await tester.pumpWidget(_app(model, SettingsModel()));
    await tester.pump();

    final field = find.descendant(
      of: find.byType(CaptureBar),
      matching: find.byType(TextField),
    );
    expect(find.byKey(const ValueKey('capture-shorthand')), findsNothing);

    await tester.enterText(field, 'Call Bob');
    await tester.pump();
    expect(find.byKey(const ValueKey('capture-shorthand')), findsOneWidget);

    await tester.tap(find.text('1h'));
    await tester.pump();
    await tester.tap(find.text('★ Outcome'));
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, 'Call Bob 1h *');
    expect(find.byKey(const ValueKey('capture-shorthand')), findsOneWidget);

    model.dispose();
  });
}
