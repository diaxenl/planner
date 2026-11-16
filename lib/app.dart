import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/day/day_screen.dart';
import 'state/settings_provider.dart';

/// Root application widget.
///
/// Configures [MaterialApp] with the dark/light themes, following the
/// user's theme setting (dark by default).
class HyperDayApp extends StatelessWidget {
  const HyperDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsProvider.of(context).settings;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HyperDay',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: const DayScreen(),
    );
  }
}
