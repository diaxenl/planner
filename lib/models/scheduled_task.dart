import 'package:flutter/material.dart';
import 'task.dart';

/// A read-only wrapper that pairs a [Task] with its computed position
/// on the timeline.
///
/// For [TaskType.hard] and [TaskType.pinned] tasks, [computedStartTime]
/// equals [Task.startTime]. For [TaskType.floating] tasks, it is assigned
/// by the scheduling engine.
///
/// An Outcome that doesn't fit one free gap is split into sessions: one
/// [ScheduledTask] per session, all sharing the same [task], numbered
/// [part] of [parts].
class ScheduledTask {
  const ScheduledTask({
    required this.task,
    required this.computedStartTime,
    int? durationMinutes,
    this.part = 1,
    this.parts = 1,
  }) : _durationMinutes = durationMinutes;

  /// The underlying task.
  final Task task;

  /// The time this entry starts on the timeline, as computed by the
  /// scheduler or taken directly from [Task.startTime].
  final TimeOfDay computedStartTime;

  final int? _durationMinutes;

  /// Minutes this entry occupies: the session length for a split task or
  /// the minutes left on a paused one; otherwise [Task.durationMinutes].
  int get durationMinutes => _durationMinutes ?? task.durationMinutes;

  /// 1-based session number, and how many sessions the task was split
  /// into (1 when not split).
  final int part;
  final int parts;

  /// Whether the task was split into more than one session.
  bool get isSplit => parts > 1;

  /// The time this entry ends: [computedStartTime] + [durationMinutes].
  TimeOfDay get computedEndTime {
    final totalMinutes = endMinutes;
    return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
  }

  /// Convenience — total minutes from midnight for the start time.
  int get startMinutes =>
      computedStartTime.hour * 60 + computedStartTime.minute;

  /// Convenience — total minutes from midnight for the end time.
  int get endMinutes => startMinutes + durationMinutes;

  @override
  String toString() {
    String fmt(TimeOfDay t) =>
        '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
    final split = isSplit ? ' [$part/$parts]' : '';
    return 'ScheduledTask(${task.title}, ${fmt(computedStartTime)}–${fmt(computedEndTime)}$split)';
  }
}
