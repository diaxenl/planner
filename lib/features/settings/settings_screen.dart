import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/calendar_event.dart';
import '../../state/day_planner_provider.dart';
import '../../state/settings_provider.dart';

/// Theme, outcome cap, and which calendars to import meetings from.
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
          const SizedBox(height: 32),
          Text('CALENDARS', style: text.labelSmall),
          const SizedBox(height: 12),
          const _CalendarPicker(),
        ],
      ),
    );
  }
}

/// Lists the phone's calendars with a switch each. No selection saved
/// means all calendars are imported.
class _CalendarPicker extends StatefulWidget {
  const _CalendarPicker();

  @override
  State<_CalendarPicker> createState() => _CalendarPickerState();
}

class _CalendarPickerState extends State<_CalendarPicker> {
  Future<List<DeviceCalendarInfo>>? _calendars;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calendars ??= DayPlannerProvider.of(context).listCalendars();
  }

  Future<void> _allowAccess() async {
    final model = DayPlannerProvider.of(context);
    await model.requestCalendarAccess();
    if (!mounted) return;
    setState(() => _calendars = model.listCalendars());
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final settings = SettingsProvider.of(context);
    final selected = settings.settings.selectedCalendarIds;

    return FutureBuilder<List<DeviceCalendarInfo>>(
      future: _calendars,
      builder: (context, snapshot) {
        final calendars = snapshot.data ?? const [];
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 48);
        }
        if (calendars.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Meetings are imported from the calendars on this phone — '
                'Google, Microsoft (Outlook / 365) and iCloud. Make sure your '
                'accounts are synced to the phone, then allow access.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _allowAccess,
                child: const Text('Allow calendar access'),
              ),
            ],
          );
        }
        return Column(
          children: [
            for (final cal in calendars)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(cal.name, style: text.bodyLarge),
                subtitle: cal.accountName == null
                    ? null
                    : Text(cal.accountName!, style: text.bodyMedium),
                value: selected == null || selected.contains(cal.id),
                onChanged: (on) {
                  final ids = selected ?? calendars.map((c) => c.id).toSet();
                  final next = {...ids};
                  on ? next.add(cal.id) : next.remove(cal.id);
                  settings.setSelectedCalendarIds(
                    next.length == calendars.length ? null : next,
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
