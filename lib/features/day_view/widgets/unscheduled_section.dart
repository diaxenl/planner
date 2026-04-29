import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../models/task.dart';
import 'task_card.dart';

/// A section shown below the timeline that lists overflow tasks — floating
/// tasks that could not be placed into any available gap by the scheduler.
///
/// Each overflow task is displayed with a small warning badge to indicate
/// it did not fit into the day.
class UnscheduledSection extends StatelessWidget {
  const UnscheduledSection({
    super.key,
    required this.tasks,
    required this.onTap,
    required this.onComplete,
    required this.onDismissed,
  });

  /// Overflow tasks that did not fit into the day's schedule.
  final List<Task> tasks;

  /// Called when a task card is tapped (edit).
  final void Function(Task task) onTap;

  /// Called when a task's complete button is tapped.
  final void Function(Task task) onComplete;

  /// Called when a task card is swiped to dismiss (delete).
  final void Function(Task task) onDismissed;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: AppTheme.timelineDividerColor),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLarge,
            vertical: AppConstants.paddingMedium,
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: AppConstants.paddingSmall),
              Text(
                'Overflow (${tasks.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
        ...tasks.map(
          (task) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingLarge,
              vertical: AppConstants.paddingSmall,
            ),
            child: TaskCard(
              task: task,
              onTap: () => onTap(task),
              onComplete: task.isComplete ? null : () => onComplete(task),
              onDismissed: () => onDismissed(task),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.paddingLarge),
      ],
    );
  }
}
