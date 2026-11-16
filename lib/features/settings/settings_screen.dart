import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/calendar_event.dart';
import '../../state/day_planner_provider.dart';
import '../../state/settings_provider.dart';

/// Theme, outcome cap, and which calendars to import meetings from.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  @override
  Widget build(BuildContext context) {
    final model = SettingsProvider.of(context);
    final settings = model.settings;
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        // Clear the system nav bar (Android buttons, iOS home indicator).
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
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
          Text('WORKDAY', style: text.labelSmall),
          const SizedBox(height: 4),
          Text(
            'Work is planned, and free time counted, only in these hours. '
            'Meetings can still be at any time.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 8),
          _HourStepper(
            label: 'Starts',
            hour: settings.workdayStartHour,
            onChanged: (h) => model.setWorkday(h, settings.workdayEndHour),
            canDecrease: settings.workdayStartHour > 0,
            canIncrease:
                settings.workdayStartHour + 1 < settings.workdayEndHour,
          ),
          _HourStepper(
            label: 'Ends',
            hour: settings.workdayEndHour,
            onChanged: (h) => model.setWorkday(settings.workdayStartHour, h),
            canDecrease:
                settings.workdayEndHour - 1 > settings.workdayStartHour,
            canIncrease: settings.workdayEndHour < 24,
          ),
          const SizedBox(height: 16),
          Text('Breathing room', style: text.bodyLarge),
          const SizedBox(height: 2),
          Text(
            'Free time kept around meetings and between planned work. '
            'Skipped on days too full for it.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (final m in AppConstants.bufferChoices)
                ButtonSegment(
                  value: m,
                  label: Text(m == 0 ? 'None' : AppUtils.formatDuration(m)),
                ),
            ],
            selected: {settings.bufferMinutes},
            onSelectionChanged: (s) => model.setBufferMinutes(s.first),
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

/// A label with an hour value and − / + buttons, one hour per step.
class _HourStepper extends StatelessWidget {
  const _HourStepper({
    required this.label,
    required this.hour,
    required this.onChanged,
    required this.canDecrease,
    required this.canIncrease,
  });

  final String label;
  final int hour;
  final ValueChanged<int> onChanged;
  final bool canDecrease;
  final bool canIncrease;

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: text.bodyLarge)),
        IconButton(
          tooltip: '$label earlier',
          onPressed: canDecrease ? () => onChanged(hour - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 84,
          child: Text(
            hour == 24 ? 'Midnight' : AppUtils.formatClock(hour * 60),
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(
              color: colors.accent,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
        ),
        IconButton(
          tooltip: '$label later',
          onPressed: canIncrease ? () => onChanged(hour + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// The calendar connection, verified by reading the phone's calendars:
/// a check with the count when connected, a hint when access is allowed
/// but nothing was found, or the button to allow access. Below, a switch
/// per calendar. No selection saved means all calendars are imported.
class _CalendarPicker extends StatefulWidget {
  const _CalendarPicker();

  @override
  State<_CalendarPicker> createState() => _CalendarPickerState();
}

class _CalendarPickerState extends State<_CalendarPicker> {
  /// The last check; `null` until the first one finishes.
  CalendarCheck? _check;

  /// A check (or the permission prompt) is under way. The last result
  /// stays on screen meanwhile so the page doesn't jump.
  bool _checking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_check == null && !_checking) {
      _checking = true;
      _verify();
    }
  }

  Future<void> _verify() async {
    final result = await DayPlannerProvider.of(context).checkCalendars();
    if (!mounted) return;
    setState(() {
      _check = result;
      _checking = false;
    });
  }

  Future<void> _allowAccess() async {
    final model = DayPlannerProvider.of(context);
    setState(() => _checking = true);
    await model.requestCalendarAccess();
    if (!mounted) return;
    await _verify();
  }

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final settings = SettingsProvider.of(context);
    final selected = settings.settings.selectedCalendarIds;
    final check = _check;

    if (check == null) {
      return _status(
        context,
        icon: Icons.sync,
        color: colors.textMuted,
        title: 'Checking calendars…',
      );
    }

    final calendars = check.calendars;
    if (!check.access) {
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
            onPressed: _checking ? null : _allowAccess,
            child: Text(_checking ? 'Checking…' : 'Allow calendar access'),
          ),
        ],
      );
    }

    if (calendars.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _status(
            context,
            icon: Icons.error_outline,
            color: colors.accent,
            title: 'Access allowed, but no calendars found',
            detail:
                "Add your Google, Microsoft or iCloud account in the phone's "
                'Settings → Accounts, then check again.',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _checking ? null : _verify,
            child: Text(_checking ? 'Checking…' : 'Check again'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _status(
          context,
          icon: Icons.check_circle,
          color: colors.accent,
          title:
              'Connected · ${calendars.length} '
              '${calendars.length == 1 ? 'calendar' : 'calendars'}',
          detail:
              'Meetings show on your schedule. Pull down on the day to '
              'refresh.',
        ),
        const SizedBox(height: 8),
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
  }

  /// An icon, a title, and optional detail below it.
  Widget _status(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    String? detail,
  }) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.bodyLarge),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(detail, style: text.bodyMedium),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
