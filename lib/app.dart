import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/day_view/day_screen.dart';

/// Root application widget.
///
/// Configures [MaterialApp] with the app theme and initial route.
/// In Phase 2, an [InheritedNotifier] will be inserted above this widget
/// in the tree to provide [DayPlannerModel] to all descendants.
class HyperDayApp extends StatelessWidget {
  const HyperDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HyperDay',
      theme: AppTheme.lightTheme,
      home: const DayScreen(),
    );
  }
}
