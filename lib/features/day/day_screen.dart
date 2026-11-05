import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/day_planner_provider.dart';
import '../settings/settings_screen.dart';
import 'widgets/day_header.dart';

/// Home screen — one day, built around its Outcomes.
class DayScreen extends StatelessWidget {
  const DayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = DayPlannerProvider.of(context);
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              DayHeader(
                date: model.viewedDate,
                onPreviousDay: () => model.setViewedDate(
                  model.viewedDate.subtract(const Duration(days: 1)),
                ),
                onNextDay: () => model.setViewedDate(
                  model.viewedDate.add(const Duration(days: 1)),
                ),
                onToday: () => model.setViewedDate(DateTime.now()),
                onSettings: () => SettingsScreen.open(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Text('LOAD', style: text.labelSmall),
                    const SizedBox(height: 24),
                    Text('NOW', style: text.labelSmall),
                    const SizedBox(height: 24),
                    Text('OUTCOMES', style: text.labelSmall),
                    const SizedBox(height: 24),
                    Text('LATER TODAY', style: text.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
