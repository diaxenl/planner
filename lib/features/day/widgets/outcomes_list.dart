import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../models/day_schedule.dart';
import '../../../models/task.dart';

/// The day's Outcomes with check state, when each is scheduled, and an
/// add affordance while under the cap.
class OutcomesList extends StatelessWidget {
  const OutcomesList({
    super.key,
    required this.tasks,
    required this.schedule,
    required this.cap,
    required this.onDone,
    required this.onTap,
    required this.onAdd,
    required this.dayLabel,
  });

  /// Every Outcome on the day, any status.
  final List<Task> tasks;
  final DaySchedule schedule;
  final int cap;
  final ValueChanged<Task> onDone;
  final ValueChanged<Task> onTap;
  final VoidCallback onAdd;

  /// "today", "tomorrow", or "this day" — for the empty prompt.
  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final active = tasks.where((t) => t.status != TaskStatus.cancelled);
    final done = active.where((t) => t.status == TaskStatus.complete).length;
    final ordered = _ordered();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('OUTCOMES', style: text.labelSmall),
            const Spacer(),
            if (active.isNotEmpty)
              Text(
                '$done / ${active.length}',
                style: text.bodySmall?.copyWith(color: colors.accent),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          _AddRow(label: 'What would make $dayLabel a win?', onTap: onAdd)
        else ...[
          for (final t in ordered) _row(context, t),
          if (active.length < cap)
            _AddRow(label: 'Add an outcome', onTap: onAdd),
        ],
      ],
    );
  }

  /// Next up first: scheduled by start time, then ones that don't fit,
  /// then finished ones.
  List<Task> _ordered() {
    int rank(Task t) {
      if (t.status == TaskStatus.complete || t.status == TaskStatus.cancelled) {
        return 1 << 20;
      }
      final placed = schedule.committed
          .where((st) => st.task.id == t.id)
          .firstOrNull;
      return placed?.startMinutes ?? (1 << 19);
    }

    return [...tasks]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  Widget _row(BuildContext context, Task task) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final isDone = task.status == TaskStatus.complete;
    final isCancelled = task.status == TaskStatus.cancelled;
    final placed = schedule.committed
        .where((st) => st.task.id == task.id)
        .firstOrNull;
    final overflowing = schedule.overflow.any((t) => t.id == task.id);

    final String when;
    if (isCancelled) {
      when = 'Cancelled';
    } else if (isDone) {
      when =
          task.actualDurationMinutes != null && task.actualDurationMinutes! > 0
          ? 'Done · took ${AppUtils.formatDuration(task.actualDurationMinutes!)}'
          : 'Done';
    } else if (overflowing) {
      when = "Doesn't fit — shorten it or move it to tomorrow";
    } else if (placed != null) {
      when =
          '${AppUtils.formatClock(placed.startMinutes)}'
          ' · ${AppUtils.formatDuration(task.durationMinutes)}';
    } else {
      when = AppUtils.formatDuration(task.durationMinutes);
    }

    return InkWell(
      onTap: () => onTap(task),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isDone || isCancelled ? null : () => onDone(task),
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? colors.accent : null,
                    border: Border.all(
                      color: isCancelled ? colors.textMuted : colors.accent,
                      width: 2,
                    ),
                  ),
                  child: isDone
                      ? Icon(Icons.check, size: 16, color: colors.onAccent)
                      : null,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: text.titleMedium?.copyWith(
                      color: isDone || isCancelled ? colors.textMuted : null,
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    when,
                    style: text.bodySmall?.copyWith(
                      color: overflowing ? colors.accent : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.hairline, width: 2),
                ),
                child: Icon(Icons.add, size: 14, color: colors.textMuted),
              ),
            ),
            Text(
              label,
              style: text.bodyLarge?.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
