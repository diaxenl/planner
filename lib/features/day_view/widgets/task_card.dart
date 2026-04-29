import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../models/task.dart';

/// A card representing a single task on the timeline or in the
/// unscheduled list.
///
/// Displays title, time range, duration, priority badge, and a type
/// indicator icon. Hard tasks get a distinct visual treatment.
///
/// - Tap → [onTap] (opens edit sheet)
/// - Check icon → [onComplete] (mark complete)
/// - Swipe to dismiss → [onDismissed] (delete with undo)
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.timeLabel,
    this.onTap,
    this.onComplete,
    this.onDismissed,
  });

  /// The task to display.
  final Task task;

  /// Optional formatted time range, e.g. "9:00 AM – 10:30 AM".
  /// Shown when the task has a computed position on the timeline.
  final String? timeLabel;

  /// Called when the card is tapped (edit).
  final VoidCallback? onTap;

  /// Called when the check icon is tapped (mark complete).
  final VoidCallback? onComplete;

  /// Called when the card is swiped away (delete).
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      color: _cardColor(context),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMedium,
            vertical: AppConstants.paddingMedium,
          ),
          child: Row(
            children: [
              // Type indicator icon
              _typeIcon(),
              const SizedBox(width: AppConstants.paddingMedium),

              // Title + time label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        decoration: task.isComplete
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.hourLabelColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Priority badge
              _priorityBadge(context),

              // Complete button — shown for incomplete tasks
              if (!task.isComplete && onComplete != null) ...[
                const SizedBox(width: AppConstants.paddingSmall),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    icon: Icon(
                      Icons.check_circle_outline,
                      color: Colors.green.shade600,
                    ),
                    tooltip: 'Mark complete',
                    onPressed: onComplete,
                  ),
                ),
              ],

              // Completed indicator — shown for completed tasks
              if (task.isComplete) ...[
                const SizedBox(width: AppConstants.paddingSmall),
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: Colors.green.shade400,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (onDismissed == null) return card;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppConstants.paddingLarge),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDismissed?.call(),
      child: card,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  Color _cardColor(BuildContext context) {
    if (task.isComplete) return Colors.grey.shade100;
    if (task.type == TaskType.hard) return Colors.blue.shade50;
    return Colors.white;
  }

  Widget _typeIcon() {
    switch (task.type) {
      case TaskType.hard:
        return Icon(Icons.lock, size: 16, color: Colors.blue.shade700);
      case TaskType.pinned:
        return Icon(Icons.push_pin, size: 16, color: Colors.orange.shade700);
      case TaskType.floating:
        return Icon(Icons.swap_vert, size: 16, color: Colors.grey.shade600);
    }
  }

  String _subtitle() {
    final parts = <String>[];
    if (timeLabel != null) {
      parts.add(timeLabel!);
    }
    parts.add('${task.durationMinutes} min');
    return parts.join(' · ');
  }

  Widget _priorityBadge(BuildContext context) {
    final (label, color) = switch (task.priority) {
      Priority.high => ('H', Colors.red.shade400),
      Priority.medium => ('M', Colors.orange.shade400),
      Priority.low => ('L', Colors.green.shade400),
    };

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
