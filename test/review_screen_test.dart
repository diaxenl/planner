import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/features/review/review_screen.dart';
import 'package:planner/core/theme.dart';
import 'package:planner/models/task.dart';
import 'package:planner/state/day_planner_model.dart';
import 'package:planner/state/day_planner_provider.dart';

void main() {
  testWidgets('Review shows outcomes hit and resolves left-over items',
      (tester) async {
    final model = DayPlannerModel();
    final day = DateTime.now();
    Task t(String title, {bool outcome = false}) => Task(
          title: title,
          durationMinutes: 30,
          type: TaskType.floating,
          isOutcome: outcome,
          date: day,
        );
    final done = t('Ship memo', outcome: true);
    final open = t('Hiring plan', outcome: true);
    final other = t('Inbox');
    model
      ..addTask(done)
      ..addTask(open)
      ..addTask(other)
      ..markComplete(done.id, DateTime.now());

    await tester.pumpWidget(DayPlannerProvider(
      model: model,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ReviewScreen(),
      ),
    ));

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Hiring plan'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);

    await tester.tap(find.text('Drop').last);
    await tester.pump();
    expect(model.tasks.firstWhere((x) => x.id == other.id).status,
        TaskStatus.cancelled);
    expect(find.text('Inbox'), findsNothing);

    // Dropping an open Outcome here doesn't rewrite the day's score.
    await tester.tap(find.text('Drop').first);
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Hiring plan'), findsNothing);

    model.dispose();
  }, skip: TimeOfDay.now().hour >= 22);
}
