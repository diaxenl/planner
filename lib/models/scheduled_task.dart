import 'package:flutter/material.dart';
import 'task.dart';

/// A read-only wrapper that pairs a [Task] with its computed position
/// on the timeline.
///
/// For [TaskType.hard] and [TaskType.pinned] tasks, [computedStartTime]
/// equals [Task.startTime]. For [TaskType.floating] tasks, it is assigned
/// by the scheduling engine (Phase 4).
///
/// Defined in Phase 2 so Phase 3 widgets can reference it. Populated by
/// the scheduler in Phase 4.
class ScheduledTask {
  const ScheduledTask({
    required this.task,
    required this.computedStartTime,
  });

  /// The underlying task.
  final Task task;

  /// The time this task starts on the timeline, as computed by the
  /// scheduler or taken directly from [Task.startTime].
  final TimeOfDay computedStartTime;

  /// The time this task ends, computed from [computedStartTime] +
  /// [Task.durationMinutes].
  TimeOfDay get computedEndTime {
    final totalMinutes =
        computedStartTime.hour * 60 +
        computedStartTime.minute +
        task.durationMinutes;
    return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
  }

  /// Convenience — total minutes from midnight for the start time.
  int get startMinutes =>
      computedStartTime.hour * 60 + computedStartTime.minute;

  /// Convenience — total minutes from midnight for the end time.
  int get endMinutes => startMinutes + task.durationMinutes;

  @override
  String toString() {
    String _fmt(TimeOfDay t) =>
        '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
    return 'ScheduledTask(${task.title}, ${_fmt(computedStartTime)}–${_fmt(computedEndTime)})';
  }
}
