import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../state/settings_provider.dart';

/// Theme and outcome-cap preferences.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  @override
  Widget build(BuildContext context) {
    final model = SettingsProvider.of(context);
    final settings = model.settings;
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text('APPEARANCE', style: text.labelSmall),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => model.setThemeMode(s.first),
          ),
          const SizedBox(height: 32),
          Text('OUTCOMES', style: text.labelSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Outcomes per day', style: text.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Fewer is sharper. 3 is a good default.',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fewer',
                onPressed: settings.outcomeCap > AppConstants.minOutcomeCap
                    ? () => model.setOutcomeCap(settings.outcomeCap - 1)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '${settings.outcomeCap}',
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(
                    color: colors.accent,
                    fontFeatures: AppTheme.tabularFigures,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'More',
                onPressed: settings.outcomeCap < AppConstants.maxOutcomeCap
                    ? () => model.setOutcomeCap(settings.outcomeCap + 1)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
