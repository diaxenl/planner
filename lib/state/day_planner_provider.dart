import 'package:flutter/material.dart';
import 'day_planner_model.dart';

/// Provides [DayPlannerModel] to the widget tree via [InheritedNotifier].
///
/// Place this above [MaterialApp] so that all screens can access the model.
///
/// Usage:
/// ```dart
/// DayPlannerProvider.of(context) // returns DayPlannerModel
/// ```
class DayPlannerProvider extends InheritedNotifier<DayPlannerModel> {
  const DayPlannerProvider({
    super.key,
    required DayPlannerModel model,
    required super.child,
  }) : super(notifier: model);

  /// Retrieves the nearest [DayPlannerModel] from the widget tree.
  ///
  /// Widgets that call this will rebuild when [DayPlannerModel] calls
  /// [ChangeNotifier.notifyListeners].
  static DayPlannerModel of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<DayPlannerProvider>();
    assert(provider != null, 'No DayPlannerProvider found in widget tree');
    return provider!.notifier!;
  }
}
