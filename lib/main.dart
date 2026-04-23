import 'package:flutter/material.dart';
import 'app.dart';
import 'state/day_planner_model.dart';
import 'state/day_planner_provider.dart';

void main() {
  final model = DayPlannerModel();

  runApp(
    DayPlannerProvider(
      model: model,
      child: const HyperDayApp(),
    ),
  );
}
