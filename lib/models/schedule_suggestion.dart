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

/// A reschedule proposal generated after a mutation (add, edit, delete,
/// start, cancel, complete, or an overrun detection) changes the
/// computed schedule in a way that affects tasks other than the one
/// directly mutated.
class ScheduleSuggestion {
  const ScheduleSuggestion({
    required this.proposed,
    required this.moves,
    this.overflowChanged = false,
  });

  /// The full proposed schedule if the suggestion is accepted.
  final DaySchedule proposed;

  /// Individual task moves that differ from the current schedule.
  /// Empty if no floating tasks changed position.
  final List<TaskMove> moves;

  /// Whether tasks moved into or out of the overflow list (other than
  /// the task that directly triggered the mutation).
  final bool overflowChanged;

  /// Whether this suggestion actually proposes any changes.
  bool get hasChanges => moves.isNotEmpty || overflowChanged;

  /// A short human-readable summary, e.g. "2 tasks can shift earlier."
  String get summary {
    if (!hasChanges) return 'No changes needed.';
    if (moves.isEmpty) {
      return 'Your day shifted — some tasks may now fit differently. Accept?';
    }
    final count = moves.length;
    final noun = count == 1 ? 'task' : 'tasks';
    return '$count $noun can be rescheduled. Accept?';
  }
}
