import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../models/day_schedule.dart';
import '../../../models/scheduled_task.dart';
import '../../../models/task.dart';
import 'schedule_timeline.dart';

/// The day on a timeline ([ScheduleTimeline]), followed by anything
/// that doesn't fit and anything already finished off the plan. A split
/// item has one block per session.
class AgendaList extends StatelessWidget {
  const AgendaList({
    super.key,
    required this.schedule,
    required this.tasks,
    required this.current,
    required this.onTap,
    required this.dayStartHour,
    required this.dayEndHour,
    required this.isToday,
    this.onLongPressAt,
  });

  final DaySchedule schedule;

  /// Holding down on empty timeline (see [ScheduleTimeline]).
  final ValueChanged<int>? onLongPressAt;

  /// The workday, for the timeline's range and free time.
  final int dayStartHour;
  final int dayEndHour;

  /// Shows the now line on the timeline.
  final bool isToday;

  /// All tasks on the day — used to list finished floating work, which
  /// the scheduler no longer places.
  final List<Task> tasks;

  /// The Now card's item (that session is highlighted).
  final ScheduledTask? current;
  final ValueChanged<Task> onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final placedIds = schedule.committed.map((st) => st.task.id).toSet();
    // Finished work the scheduler no longer places goes back on the
    // timeline where it happened: ending when it was marked Done. Work
    // done before a pause is shown where it happened too.
    final finishedEntries = [
      for (final t in tasks)
        if (!placedIds.contains(t.id) && _finishedOnItsDay(t))
          ..._whenFinished(t)
        else if (t.status != TaskStatus.cancelled &&
            t.status != TaskStatus.complete)
          ..._pausedRuns(t),
    ];
    final onTimeline = {for (final e in finishedEntries) e.task.id};
    final finishedOffPlan = tasks
        .where(
          (t) =>
              !placedIds.contains(t.id) &&
              !onTimeline.contains(t.id) &&
              (t.status == TaskStatus.complete ||
                  t.status == TaskStatus.cancelled),
        )
        .toList();
    final entries = [...schedule.committed, ...finishedEntries];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SCHEDULE', style: text.labelSmall),
        const SizedBox(height: 8),
        // Drawn even when empty: the workday's hours and the now line.
        const SizedBox(height: 8),
        ScheduleTimeline(
          entries: entries,
          current: current,
          dayStartHour: dayStartHour,
          dayEndHour: dayEndHour,
          isToday: isToday,
          onTap: onTap,
          onLongPressAt: onLongPressAt,
        ),
        if (schedule.overflow.isNotEmpty || schedule.unplanned.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text("DOESN'T FIT", style: text.labelSmall),
          const SizedBox(height: 8),
          for (final t in schedule.overflow)
            _Row(
              time: '—',
              task: t,
              minutes: t.remainingMinutes,
              isCurrent: false,
              onTap: () => onTap(t),
            ),
          // Outcomes planned in part: the rest that doesn't fit.
          for (final st in schedule.committed)
            if (schedule.unplanned.containsKey(st.task.id) &&
                st.part == st.parts)
              _Row(
                time: 'Rest',
                task: st.task,
                minutes: schedule.unplanned[st.task.id]!,
                isCurrent: false,
                onTap: () => onTap(st.task),
              ),
        ],
        if (finishedOffPlan.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('FINISHED', style: text.labelSmall),
          const SizedBox(height: 8),
          for (final t in finishedOffPlan)
            _Row(
              time: '',
              task: t,
              minutes: t.durationMinutes,
              isCurrent: false,
              onTap: () => onTap(t),
            ),
        ],
      ],
    );
  }
}

/// Whether [t] was marked Done on the day it belongs to.
bool _finishedOnItsDay(Task t) {
  final at = t.completedAt;
  return t.status == TaskStatus.complete &&
      at != null &&
      at.year == t.date.year &&
      at.month == t.date.month &&
      at.day == t.date.day;
}

/// [t]'s runs before it was paused, on its own day, as timeline entries
/// (at least 5 minutes, so they stay visible).
List<ScheduledTask> _pausedRuns(Task t) {
  final dayEnd = DateTime(t.date.year, t.date.month, t.date.day + 1);
  int minutesOf(DateTime d) =>
      d.isBefore(dayEnd) ? d.hour * 60 + d.minute : 24 * 60;
  return [
    for (final r in t.pausedRuns)
      if (r.start.year == t.date.year &&
          r.start.month == t.date.month &&
          r.start.day == t.date.day)
        () {
          final start = math.min(minutesOf(r.start), 24 * 60 - 5);
          final end = math.max(start + 5, minutesOf(r.end));
          return ScheduledTask(
            task: t,
            computedStartTime: TimeOfDay(hour: start ~/ 60, minute: start % 60),
            durationMinutes: end - start,
            isPausedRun: true,
          );
        }(),
  ];
}

/// [t] on the timeline as worked: any runs before a pause, then the last
/// run, ending at its completion time. Without runs, one entry ending
/// at completion, as long as the time spent on it (at least 5 minutes, so
/// it stays visible).
List<ScheduledTask> _whenFinished(Task t) {
  final runs = _pausedRuns(t);
  final started = t.startedAt;
  if (runs.isNotEmpty) {
    // Resumed after the last pause: the final run ends at completion.
    final resumed = started != null && !started.isBefore(t.pausedRuns.last.end);
    return [
      ...runs,
      if (resumed)
        _ending(
          t,
          t.completedAt!,
          t.completedAt!.difference(started).inMinutes,
        ),
    ];
  }
  return [
    _ending(t, t.completedAt!, t.actualDurationMinutes ?? t.durationMinutes),
  ];
}

/// [t] as one entry of [minutes] (at least 5) ending at [at].
ScheduledTask _ending(Task t, DateTime at, int minutes) {
  final end = at.hour * 60 + at.minute;
  final start = math.max<int>(0, end - math.max(5, minutes));
  return ScheduledTask(
    task: t,
    computedStartTime: TimeOfDay(hour: start ~/ 60, minute: start % 60),
    durationMinutes: math.max(5, end - start),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.time,
    required this.task,
    required this.minutes,
    required this.isCurrent,
    required this.onTap,
  });

  final String time;
  final Task task;

  final int minutes;
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
                    : AppUtils.formatDuration(minutes),
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
