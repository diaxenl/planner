import 'package:flutter/material.dart';
import 'day_schedule.dart';
import 'task.dart';

/// A single proposed time change for one task.
class TaskMove {
  const TaskMove({
    required this.task,
    required this.oldStart,
    required this.newStart,
  });

  /// The task that would move.
  final Task task;

  /// Where the task is currently scheduled.
  final TimeOfDay oldStart;

  /// Where the task would move to in the proposed schedule.
  final TimeOfDay newStart;
}

/// A reschedule proposal generated after a task is marked complete.
///
/// Contains the proposed [DaySchedule] and a list of [TaskMove] diffs
/// showing which tasks would shift and by how much.
class ScheduleSuggestion {
  const ScheduleSuggestion({
    required this.proposed,
    required this.moves,
  });

  /// The full proposed schedule if the suggestion is accepted.
  final DaySchedule proposed;

  /// Individual task moves that differ from the current schedule.
  /// Empty if no floating tasks changed position.
  final List<TaskMove> moves;

  /// Whether this suggestion actually proposes any changes.
  bool get hasChanges => moves.isNotEmpty;

  /// A short human-readable summary, e.g. "2 tasks can shift earlier."
  String get summary {
    if (moves.isEmpty) return 'No changes needed.';
    final count = moves.length;
    final noun = count == 1 ? 'task' : 'tasks';
    return '$count $noun can be rescheduled. Accept?';
  }
}
