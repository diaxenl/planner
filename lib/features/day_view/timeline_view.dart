import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/task.dart';
import 'widgets/empty_state_overlay.dart';
import 'widgets/task_card.dart';

/// Scrollable timeline covering [AppConstants.dayStartHour] to
/// [AppConstants.dayEndHour].
///
/// Uses a [Stack] for slot-based absolute positioning. Hour labels and
/// dividers are placed at fixed pixel offsets so that future task cards
/// can be positioned using the same time → pixel mapping via
/// [AppUtils.timeToOffset].
class TimelineView extends StatelessWidget {
  const TimelineView({
    super.key,
    required this.tasks,
    required this.onTaskTap,
    required this.onTaskDismissed,
  });

  /// All tasks for the viewed day (the view filters for hard/pinned).
  final List<Task> tasks;

  /// Called when a task card is tapped (to edit).
  final void Function(Task task) onTaskTap;

  /// Called when a task card is swiped to dismiss (to delete).
  final void Function(Task task) onTaskDismissed;

  @override
  Widget build(BuildContext context) {
    // Tasks that have a fixed position on the timeline.
    final placedTasks = tasks
        .where((t) => t.type != TaskType.floating && t.startTime != null)
        .toList();

    final hasAnyTasks = tasks.isNotEmpty;

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

            // Placed task cards (hard / pinned)
            for (final task in placedTasks) _buildPlacedCard(task),

            // Empty state overlay — only when zero tasks exist.
            if (!hasAnyTasks) const EmptyStateOverlay(),
          ],
        ),
      ),
    );
  }

  /// Renders a hard or pinned task card at its fixed timeline position.
  Widget _buildPlacedCard(Task task) {
    final start = task.startTime!;
    final top = AppUtils.timeToOffset(start.hour, start.minute);
    final height =
        (task.durationMinutes / 60.0) * AppConstants.hourHeight;
    final timeLabel = _formatTimeRange(start, task.durationMinutes);

    return Positioned(
      top: top,
      left: AppConstants.timeGutterWidth + AppConstants.paddingSmall,
      right: AppConstants.paddingMedium,
      height: height.clamp(36.0, double.infinity),
      child: TaskCard(
        task: task,
        timeLabel: timeLabel,
        onTap: () => onTaskTap(task),
        onDismissed: () => onTaskDismissed(task),
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
