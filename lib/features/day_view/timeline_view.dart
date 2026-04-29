import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/day_schedule.dart';
import '../../models/scheduled_task.dart';
import '../../models/task.dart';
import 'widgets/empty_state_overlay.dart';
import 'widgets/task_card.dart';

/// Scrollable timeline covering [AppConstants.dayStartHour] to
/// [AppConstants.dayEndHour].
///
/// Uses a [Stack] for slot-based absolute positioning. All committed
/// tasks from the [DaySchedule] are rendered at their computed positions.
class TimelineView extends StatelessWidget {
  const TimelineView({
    super.key,
    required this.schedule,
    required this.hasAnyTasks,
    required this.onTaskTap,
    required this.onTaskComplete,
    required this.onTaskDismissed,
  });

  /// The computed schedule with committed + overflow tasks.
  final DaySchedule schedule;

  /// Whether any tasks exist at all (to control empty state).
  final bool hasAnyTasks;

  /// Called when a task card is tapped (to edit).
  final void Function(Task task) onTaskTap;

  /// Called when a task's complete button is tapped.
  final void Function(Task task) onTaskComplete;

  /// Called when a task card is swiped to dismiss (to delete).
  final void Function(Task task) onTaskDismissed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingXLarge),
      child: SizedBox(
        height: AppConstants.timelineHeight,
        child: Stack(
          children: [
            // Hour rows: labels + dividers
            for (int h = AppConstants.dayStartHour;
                h < AppConstants.dayEndHour;
                h++)
              _buildHourRow(context, h),

            // All committed task cards (hard, pinned, and scheduled floating)
            for (final scheduled in schedule.committed)
              _buildPlacedCard(scheduled),

            // Empty state overlay — only when zero tasks exist.
            if (!hasAnyTasks) const EmptyStateOverlay(),
          ],
        ),
      ),
    );
  }

  /// Renders a committed task card at its computed timeline position.
  Widget _buildPlacedCard(ScheduledTask scheduled) {
    final start = scheduled.computedStartTime;
    final top = AppUtils.timeToOffset(start.hour, start.minute);
    final height =
        (scheduled.task.durationMinutes / 60.0) * AppConstants.hourHeight;
    final timeLabel =
        _formatTimeRange(start, scheduled.task.durationMinutes);

    return Positioned(
      top: top,
      left: AppConstants.timeGutterWidth + AppConstants.paddingSmall,
      right: AppConstants.paddingMedium,
      height: height.clamp(48.0, double.infinity),
      child: TaskCard(
        task: scheduled.task,
        timeLabel: timeLabel,
        compact: height < 56,
        onTap: () => onTaskTap(scheduled.task),
        onComplete: scheduled.task.isComplete
            ? null
            : () => onTaskComplete(scheduled.task),
        onDismissed: () => onTaskDismissed(scheduled.task),
      ),
    );
  }

  Widget _buildHourRow(BuildContext context, int hour) {
    final top = AppUtils.timeToOffset(hour);
    final label = AppUtils.formatHourLabel(hour);
    final textTheme = Theme.of(context).textTheme;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: AppConstants.hourHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hour label in the left gutter
          SizedBox(
            width: AppConstants.timeGutterWidth,
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppConstants.paddingSmall,
                left: AppConstants.paddingMedium,
              ),
              child: Text(label, style: textTheme.bodySmall),
            ),
          ),
          // Divider line extending to the right edge
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppTheme.timelineDividerColor,
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Formats a time range label, e.g. "9:00 AM – 10:30 AM".
  static String _formatTimeRange(TimeOfDay start, int durationMinutes) {
    final endTotalMin = start.hour * 60 + start.minute + durationMinutes;
    final end = TimeOfDay(hour: endTotalMin ~/ 60, minute: endTotalMin % 60);
    return '${_fmt12(start)} – ${_fmt12(end)}';
  }

  static String _fmt12(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }
}
