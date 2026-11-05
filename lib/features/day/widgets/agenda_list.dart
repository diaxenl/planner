import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../models/day_schedule.dart';
import '../../../models/task.dart';

/// The day in time order, one line per item, followed by anything that
/// doesn't fit and anything already finished off the plan.
class AgendaList extends StatelessWidget {
  const AgendaList({
    super.key,
    required this.schedule,
    required this.tasks,
    required this.currentTaskId,
    required this.onTap,
  });

  final DaySchedule schedule;

  /// All tasks on the day — used to list finished floating work, which
  /// the scheduler no longer places.
  final List<Task> tasks;
  final String? currentTaskId;
  final ValueChanged<Task> onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final placedIds = schedule.committed.map((st) => st.task.id).toSet();
    final finishedOffPlan = tasks
        .where((t) =>
            !placedIds.contains(t.id) &&
            (t.status == TaskStatus.complete ||
                t.status == TaskStatus.cancelled))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SCHEDULE', style: text.labelSmall),
        const SizedBox(height: 8),
        if (schedule.committed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text('Nothing scheduled.', style: text.bodyMedium),
          ),
        for (final st in schedule.committed)
          _Row(
            time: AppUtils.formatClock(st.startMinutes),
            task: st.task,
            isCurrent: st.task.id == currentTaskId,
            onTap: () => onTap(st.task),
          ),
        if (schedule.overflow.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('DOESN\'T FIT TODAY', style: text.labelSmall),
          const SizedBox(height: 8),
          for (final t in schedule.overflow)
            _Row(time: '—', task: t, isCurrent: false, onTap: () => onTap(t)),
        ],
        if (finishedOffPlan.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('FINISHED', style: text.labelSmall),
          const SizedBox(height: 8),
          for (final t in finishedOffPlan)
            _Row(time: '', task: t, isCurrent: false, onTap: () => onTap(t)),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.time,
    required this.task,
    required this.isCurrent,
    required this.onTap,
  });

  final String time;
  final Task task;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final isMeeting = task.type == TaskType.hard;
    final isDone = task.status == TaskStatus.complete;
    final isCancelled = task.status == TaskStatus.cancelled;
    final muted = isMeeting || isDone || isCancelled;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.hairline)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Text(
                time,
                style: text.bodySmall?.copyWith(
                  color: isCurrent ? colors.accent : null,
                ),
              ),
            ),
            if (task.isOutcome)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyLarge?.copyWith(
                  color: muted ? colors.textSecondary : null,
                  fontWeight: isMeeting ? FontWeight.w400 : null,
                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (isDone)
              Icon(Icons.check, size: 16, color: colors.textMuted)
            else
              Text(
                task.status == TaskStatus.inProgress
                    ? 'In progress'
                    : AppUtils.formatDuration(task.durationMinutes),
                style: text.bodySmall?.copyWith(
                  color: task.status == TaskStatus.inProgress
                      ? colors.accent
                      : colors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
