import 'package:flutter/material.dart';
import 'package:planner/core/constants.dart';
import 'package:planner/core/utils.dart';

/// Shows the current date with prev/next navigation arrows.
class DayHeader extends StatelessWidget {
  const DayHeader({
    super.key,
    required this.date,
    this.onPreviousDay,
    this.onNextDay,
  });

  final DateTime date;

  /// Called when the user taps the left (previous day) arrow.
  final VoidCallback? onPreviousDay;

  /// Called when the user taps the right (next day) arrow.
  final VoidCallback? onNextDay;

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
            onPressed: onPreviousDay,
            tooltip: 'Previous day',
          ),
          Text(formatted, style: textTheme.titleLarge),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNextDay,
            tooltip: 'Next day',
          ),
        ],
      ),
    );
  }
}
