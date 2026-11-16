import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/app.dart';
import 'package:planner/models/task.dart';
import 'package:planner/state/day_planner_model.dart';
import 'package:planner/state/day_planner_provider.dart';
import 'package:planner/state/settings_model.dart';
import 'package:planner/state/settings_provider.dart';

Widget _app(DayPlannerModel model, SettingsModel settings) => SettingsProvider(
  model: settings,
  child: DayPlannerProvider(model: model, child: const HyperDayApp()),
);

void main() {
  testWidgets('Outcomes can be dragged; the sheet names the item once', (
    tester,
  ) async {
    // A future day: nothing depends on the clock.
    final model = DayPlannerModel();
    await tester.runAsync(
      () => model.loadDate(DateTime.now().add(const Duration(days: 10))),
    );
    final settings = SettingsModel();
    Task outcome(String title) => Task(
      title: title,
      durationMinutes: 60,
      type: TaskType.floating,
      isOutcome: true,
      date: model.viewedDate,
    );
    model
      ..addTask(outcome('Prep board deck'))
      ..addTask(outcome('Write Q1 OKRs'))
      ..addTask(
        Task(
          title: 'Review PRs',
          durationMinutes: 45,
          type: TaskType.floating,
          date: model.viewedDate,
        ),
      );

    await tester.pumpWidget(_app(model, settings));
    await tester.pump();
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));

    await tester.ensureVisible(find.text('Review PRs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review PRs'));
    await tester.pumpAndSettle();
    expect(find.text('Edit item'), findsOneWidget);
    expect(find.text('Review PRs'), findsNWidgets(2)); // agenda + field
    expect(find.text('Do next'), findsOneWidget);
    expect(find.text('Pick a day…'), findsOneWidget);
    expect(find.text('4h'), findsOneWidget);
    expect(find.text('Weekdays'), findsOneWidget);
    expect(tester.takeException(), isNull);

    model.dispose();
  });
}
