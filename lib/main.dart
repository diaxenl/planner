import 'package:flutter/material.dart';
import 'app.dart';
import 'services/local_day_repository.dart';
import 'services/settings_repository.dart';
import 'state/day_planner_model.dart';
import 'state/day_planner_provider.dart';
import 'state/settings_model.dart';
import 'state/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsModel(repository: LocalSettingsRepository());
  await settings.load();

  final model = DayPlannerModel(repository: LocalDayRepository())
    ..outcomeCap = settings.settings.outcomeCap;
  settings.addListener(() => model.outcomeCap = settings.settings.outcomeCap);
  await model.loadDate(DateTime.now());

  runApp(
    SettingsProvider(
      model: settings,
      child: DayPlannerProvider(
        model: model,
        child: const HyperDayApp(),
      ),
    ),
  );
}
