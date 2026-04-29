import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/day_schedule.dart';
import '../models/schedule_suggestion.dart';
import '../models/scheduled_task.dart';
import '../models/task.dart';
import '../services/scheduler.dart';

/// Central state holder for the current day's tasks.
///
/// Holds a [List<Task>] for the [viewedDate] and exposes CRUD methods.
/// All mutations replace the task in the list (immutable model) and call
/// [notifyListeners].
///
/// Also maintains a cached [DaySchedule] that is recomputed when
/// schedule-affecting fields change (type, startTime, duration, priority,
/// isComplete). Title-only edits skip the reschedule.
///
/// Overlap validation: [addTask] and [updateTask] throw [ArgumentError]
/// if a hard/pinned task's time range overlaps with an existing hard task.
class DayPlannerModel extends ChangeNotifier {
  DayPlannerModel({DateTime? initialDate})
      : _viewedDate = _dateOnly(initialDate ?? DateTime.now());

  // ── State ───────────────────────────────────────────────────────────

  DateTime _viewedDate;

  /// The calendar date currently being viewed (time component is midnight).
  DateTime get viewedDate => _viewedDate;

  final List<Task> _tasks = [];

  /// Unmodifiable view of the current day's tasks.
  List<Task> get tasks => List.unmodifiable(_tasks);

  DaySchedule _schedule = DaySchedule.empty;

  /// The current computed schedule for the viewed day.
  DaySchedule get schedule => _schedule;

  ScheduleSuggestion? _suggestion;

  /// A pending reschedule suggestion, if any.
  /// Non-null after a task is completed and floating tasks can shift.
  ScheduleSuggestion? get suggestion => _suggestion;

  // ── CRUD ────────────────────────────────────────────────────────────

  /// Adds a task to the current day.
  ///
  /// Throws [ArgumentError] if the task is hard/pinned and its time range
  /// overlaps with an existing hard task.
  void addTask(Task task) {
    _validateOverlap(task);
    _tasks.add(task);
    _reschedule();
    notifyListeners();
  }

  /// Removes the task with the given [id].
  ///
  /// Returns `true` if a task was removed, `false` if no task matched.
  bool removeTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return false;
    _tasks.removeAt(index);
    _reschedule();
    notifyListeners();
    return true;
  }

  /// Replaces the task with matching [id] with [updated].
  ///
  /// Throws [ArgumentError] if [updated] is hard/pinned and overlaps
  /// with an existing hard task (excluding itself).
  void updateTask(String id, Task updated) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;
    _validateOverlap(updated, excludeId: id);

    final old = _tasks[index];
    _tasks[index] = updated;

    // Only reschedule if schedule-affecting fields changed.
    if (_scheduleFieldsChanged(old, updated)) {
      _reschedule();
    }

    notifyListeners();
  }

  /// Marks the task with [id] as complete at the given [completedAt] time.
  ///
  /// After marking complete, computes a proposed reschedule and generates
  /// a [ScheduleSuggestion] if any floating tasks would shift.
  void markComplete(String id, DateTime completedAt) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;

    // Snapshot the current committed schedule before the change.
    final oldCommitted = _schedule.committed;

    _tasks[index] = _tasks[index].copyWith(
      isComplete: true,
      completedAt: () => completedAt,
    );
    _reschedule();

    // Generate suggestion by diffing old vs new schedules.
    _suggestion = _buildSuggestion(oldCommitted, _schedule);
    if (!_suggestion!.hasChanges) {
      _suggestion = null;
    }

    notifyListeners();
  }

  /// Accepts the current suggestion, committing the proposed schedule.
  void acceptSuggestion() {
    if (_suggestion == null) return;
    // The proposed schedule is already _schedule (reschedule ran on
    // markComplete). We just clear the suggestion.
    _suggestion = null;
    notifyListeners();
  }

  /// Dismisses the current suggestion without applying it.
  void dismissSuggestion() {
    if (_suggestion == null) return;
    _suggestion = null;
    notifyListeners();
  }

  // ── Scheduling ──────────────────────────────────────────────────────

  /// Re-runs the scheduling engine on the current task list.
  void _reschedule() {
    final now = TimeOfDay.now();
    _schedule = Scheduler.schedule(
      _tasks,
      dayStartHour: AppConstants.dayStartHour,
      dayEndHour: AppConstants.dayEndHour,
      nowMinutes: now.hour * 60 + now.minute,
    );
  }

  /// Returns `true` if any schedule-affecting field differs between
  /// [oldTask] and [newTask]. Title-only edits return `false`.
  static bool _scheduleFieldsChanged(Task oldTask, Task newTask) {
    return oldTask.type != newTask.type ||
        oldTask.startTime != newTask.startTime ||
        oldTask.durationMinutes != newTask.durationMinutes ||
        oldTask.priority != newTask.priority ||
        oldTask.isComplete != newTask.isComplete;
  }

  // ── Suggestion diff ─────────────────────────────────────────────────

  /// Compares the old committed list against the new [proposed] schedule.
  ///
  /// Produces a [ScheduleSuggestion] containing moves for any incomplete
  /// non-hard task whose computed start time changed.
  static ScheduleSuggestion _buildSuggestion(
    List<ScheduledTask> oldCommitted,
    DaySchedule proposed,
  ) {
    // Build a lookup: taskId → old start minutes.
    final oldStarts = <String, TimeOfDay>{};
    for (final st in oldCommitted) {
      oldStarts[st.task.id] = st.computedStartTime;
    }

    final moves = <TaskMove>[];
    for (final st in proposed.committed) {
      // Hard tasks are never moved.
      if (st.task.type == TaskType.hard) continue;
      // Only report moves for incomplete tasks.
      if (st.task.isComplete) continue;

      final oldStart = oldStarts[st.task.id];
      if (oldStart == null) continue; // newly scheduled, not a move

      if (oldStart.hour != st.computedStartTime.hour ||
          oldStart.minute != st.computedStartTime.minute) {
        moves.add(TaskMove(
          task: st.task,
          oldStart: oldStart,
          newStart: st.computedStartTime,
        ));
      }
    }

    return ScheduleSuggestion(proposed: proposed, moves: moves);
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  /// Strips time from a [DateTime], keeping only the date.
  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Throws [ArgumentError] if [task] is hard or pinned and its time
  /// range overlaps with any existing hard task.
  ///
  /// [excludeId] — when updating a task, pass its own id so it doesn't
  /// conflict with itself.
  void _validateOverlap(Task task, {String? excludeId}) {
    // Only validate tasks that have a fixed start time.
    if (task.type == TaskType.floating || task.startTime == null) return;

    final newStart = _toMinutes(task.startTime!);
    final newEnd = newStart + task.durationMinutes;

    // Clamp to day window.
    final dayStart = AppConstants.dayStartHour * 60;
    final dayEnd = AppConstants.dayEndHour * 60;
    if (newStart < dayStart || newEnd > dayEnd) {
      throw ArgumentError(
        'Task time range ${_fmtTime(task.startTime!)}–'
        '${_fmtMinutes(newEnd)} falls outside the day window '
        '(${AppConstants.dayStartHour}:00–${AppConstants.dayEndHour}:00).',
      );
    }

    for (final existing in _tasks) {
      if (existing.id == excludeId) continue;
      if (existing.type != TaskType.hard) continue;
      if (existing.startTime == null) continue;

      final existStart = _toMinutes(existing.startTime!);
      final existEnd = existStart + existing.durationMinutes;

      // Two ranges overlap if one starts before the other ends.
      if (newStart < existEnd && newEnd > existStart) {
        throw ArgumentError(
          'Overlaps with hard task "${existing.title}" '
          '(${_fmtTime(existing.startTime!)}–${_fmtMinutes(existEnd)}).',
        );
      }
    }
  }

  static int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  static String _fmtTime(TimeOfDay t) =>
      '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

  static String _fmtMinutes(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }
}
