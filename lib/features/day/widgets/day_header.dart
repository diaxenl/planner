import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';

/// "Today" + full date, with prev/next day and settings.
///
/// When viewing another day, tapping the title jumps back to today.
class DayHeader extends StatelessWidget {
  const DayHeader({
    super.key,
    required this.date,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onToday,
    required this.onSettings,
  });

  final DateTime date;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onToday;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(date, now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isToday ? null : onToday,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppUtils.relativeDayLabel(date, now),
                    style: text.headlineSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppUtils.weekdayName(date.weekday)}, '
                    '${AppUtils.monthName(date.month)} ${date.day}'
                    '${isToday ? '' : '  ·  Back to today'}',
                    style: text.bodyMedium?.copyWith(
                      color: isToday ? colors.textSecondary : colors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Previous day',
            onPressed: onPreviousDay,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next day',
            onPressed: onNextDay,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: const Icon(Icons.tune, size: 20),
          ),
        ],
      ),
    );
  }
}
