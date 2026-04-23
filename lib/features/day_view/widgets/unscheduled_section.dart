import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../models/task.dart';
import 'task_card.dart';

/// A section shown below the timeline that lists floating tasks which
/// have not yet been placed by the scheduling engine.
///
/// In Phase 4, once the scheduler assigns time slots, floating tasks
/// move onto the timeline and this section shows only overflow items.
class UnscheduledSection extends StatelessWidget {
  const UnscheduledSection({
    super.key,
    required this.tasks,
    required this.onTap,
    required this.onDismissed,
  });

  /// Floating tasks that have no computed start time.
  final List<Task> tasks;

  /// Called when a task card is tapped (edit).
  final void Function(Task task) onTap;

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
          child: Text(
            'Unscheduled',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
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
              onDismissed: () => onDismissed(task),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.paddingLarge),
      ],
    );
  }
}
