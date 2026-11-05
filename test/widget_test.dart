import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/app.dart';
import 'package:planner/core/utils.dart';
import 'package:planner/state/day_planner_model.dart';
import 'package:planner/state/day_planner_provider.dart';
import 'package:planner/state/settings_model.dart';
import 'package:planner/state/settings_provider.dart';

Widget _app(DayPlannerModel model, SettingsModel settings) => SettingsProvider(
      model: settings,
      child: DayPlannerProvider(model: model, child: const HyperDayApp()),
    );

void main() {
  testWidgets('DayScreen shows today, dark by default', (tester) async {
    final model = DayPlannerModel();
    final settings = SettingsModel();

    await tester.pumpWidget(_app(model, settings));

    final now = DateTime.now();
    expect(find.text('Today'), findsOneWidget);
    expect(find.textContaining(AppUtils.monthName(now.month)), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    final context = tester.element(find.text('Today'));
    expect(Theme.of(context).brightness, Brightness.dark);

    model.dispose();
  });

  testWidgets('theme follows the setting', (tester) async {
    final model = DayPlannerModel();
    final settings = SettingsModel();
    await tester.pumpWidget(_app(model, settings));

    settings.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Today'));
    expect(Theme.of(context).brightness, Brightness.light);

    model.dispose();
  });

  testWidgets('capture shorthand adds the item directly', (tester) async {
    final model = DayPlannerModel();
    final settings = SettingsModel();
    await tester.pumpWidget(_app(model, settings));

    await tester.enterText(find.byType(TextField), 'Call Bob 20m *');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final added = model.tasks.single;
    expect(added.title, 'Call Bob');
    expect(added.durationMinutes, 20);
    expect(added.isOutcome, isTrue);
    expect(find.textContaining('Added "Call Bob"'), findsOneWidget);

    model.dispose();
  }, skip: TimeOfDay.now().hour >= 22);
}
