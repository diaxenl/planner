import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../models/day_schedule.dart';
import '../../../models/task.dart';

/// The day's Outcomes with check state, when each is scheduled, and an
/// add affordance while under the cap. Open Outcomes are listed in
/// priority order and can be dragged to reorder ([onReorder]); the first
/// is planned first.
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
    required this.onReorder,
  });

  /// Every Outcome on the day, any status.
  final List<Task> tasks;
  final DaySchedule schedule;
  final int cap;
  final ValueChanged<Task> onDone;
  final ValueChanged<Task> onTap;
  final VoidCallback onAdd;

  /// The open Outcomes' ids in their new order.
  final ValueChanged<List<String>> onReorder;

  /// "today", "tomorrow", or "this day" — for the empty prompt.
  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final active = tasks.where((t) => t.status != TaskStatus.cancelled);
    final done = active.where((t) => t.status == TaskStatus.complete).length;
    final open = [
      for (final t in tasks)
        if (t.status != TaskStatus.complete && t.status != TaskStatus.cancelled)
          t,
    ];
    final finished = [
      for (final t in tasks)
        if (!open.contains(t)) t,
    ];

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
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (oldIndex, newIndex) {
              final ids = [for (final t in open) t.id];
              ids.insert(newIndex, ids.removeAt(oldIndex));
              onReorder(ids);
            },
            children: [
              for (var i = 0; i < open.length; i++)
                KeyedSubtree(
                  key: ValueKey(open[i].id),
                  child: _row(
                    context,
                    open[i],
                    dragIndex: open.length > 1 ? i : null,
                  ),
                ),
            ],
          ),
          for (final t in finished) _row(context, t),
          if (active.length < cap)
            _AddRow(label: 'Add an outcome', onTap: onAdd),
        ],
      ],
    );
  }

  /// One Outcome. [dragIndex] (open Outcomes, when there are several)
  /// adds a drag handle.
  Widget _row(BuildContext context, Task task, {int? dragIndex}) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final isDone = task.status == TaskStatus.complete;
    final isCancelled = task.status == TaskStatus.cancelled;
    final sessions = schedule.committed
        .where((st) => st.task.id == task.id)
        .toList();
    final placed = sessions.firstOrNull;
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
      when = "Doesn't fit, even split up — shorten it or move it";
    } else if (placed != null && placed.isSplit) {
      final total = sessions.fold<int>(0, (m, st) => m + st.durationMinutes);
      when =
          '${AppUtils.formatClock(placed.startMinutes)}'
          ' · ${AppUtils.formatDuration(total)} in ${placed.parts} sessions';
    } else if (placed != null) {
      when =
          '${AppUtils.formatClock(placed.startMinutes)}'
          ' · ${AppUtils.formatDuration(placed.durationMinutes)}';
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
            if (dragIndex != null)
              ReorderableDragStartListener(
                index: dragIndex,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Tooltip(
                    message: 'Drag to reorder',
                    child: Icon(Icons.drag_indicator, color: colors.textMuted),
                  ),
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
