import 'package:flutter/material.dart';
import 'app.dart';
import 'services/local_day_repository.dart';
import 'state/day_planner_model.dart';
import 'state/day_planner_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = LocalDayRepository();
  final model = DayPlannerModel(repository: repository);
  await model.loadDate(DateTime.now());

  runApp(
    DayPlannerProvider(
      model: model,
      child: const HyperDayApp(),
    ),
  );
}
