import 'package:flutter/material.dart';
import 'package:planner/core/constants.dart';
import 'package:planner/core/utils.dart';

/// Shows the current date with prev/next navigation arrows.
///
/// The arrows are visual placeholders — they become functional in Phase 7.
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Format: "Tuesday, Apr 22"
    final dayName = AppUtils.weekdayName(date.weekday);
    final monthName = AppUtils.monthAbbrev(date.month);
    final formatted = '$dayName, $monthName ${date.day}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLarge,
        vertical: AppConstants.paddingMedium,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              // Non-functional until Phase 7.
            },
            tooltip: 'Previous day',
          ),
          Text(formatted, style: textTheme.titleLarge),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              // Non-functional until Phase 7.
            },
            tooltip: 'Next day',
          ),
        ],
      ),
    );
  }
}
