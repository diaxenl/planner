import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/app.dart';
import 'package:planner/state/day_planner_model.dart';
import 'package:planner/state/day_planner_provider.dart';

void main() {
  testWidgets('DayScreen smoke test — shows date and empty state',
      (WidgetTester tester) async {
    final model = DayPlannerModel();

    await tester.pumpWidget(
      DayPlannerProvider(
        model: model,
        child: const HyperDayApp(),
      ),
    );

    // Day header should show today's date.
    // We check for the month abbreviation as a stable substring.
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final monthAbbrev = months[now.month - 1];
    expect(find.textContaining(monthAbbrev), findsOneWidget);

    // Empty state message should be visible.
    expect(
      find.text('No tasks yet — tap + to get started'),
      findsOneWidget,
    );

    // FAB should be present.
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Navigation arrows should be present.
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });
}
