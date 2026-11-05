import 'package:flutter/material.dart';
import 'day_schedule.dart';
import 'task.dart';

/// A single time change for one task.
class TaskMove {
  const TaskMove({
    required this.task,
    required this.oldStart,
    required this.newStart,
  });

  /// The task that moved.
  final Task task;

  /// Where the task was scheduled before.
  final TimeOfDay oldStart;

  /// Where the task is scheduled now.
  final TimeOfDay newStart;
}

/// A replan worth telling the user about, raised after a mutation.
///
/// The new schedule is already applied; the user can keep it (OK) or undo
/// it, which holds the affected work where it was.
class ScheduleSuggestion {
  const ScheduleSuggestion({
    required this.proposed,
    required this.moves,
    this.pushedOut = const [],
  });

  /// The schedule now in effect.
  final DaySchedule proposed;

  /// Outcomes that now start later than before.
  final List<TaskMove> moves;

  /// Tasks that no longer fit in the day.
  final List<Task> pushedOut;

  /// Whether this suggestion actually reports anything.
  bool get hasChanges => moves.isNotEmpty || pushedOut.isNotEmpty;

  /// A short human-readable headline.
  String get summary {
    if (pushedOut.length == 1 && moves.isEmpty) {
      return '"${pushedOut.single.title}" no longer fits.';
    }
    if (pushedOut.isNotEmpty) {
      return '${pushedOut.length + moves.length} things were affected.';
    }
    if (moves.length == 1) return '"${moves.single.task.title}" moved later.';
    return '${moves.length} outcomes moved later.';
  }
}
