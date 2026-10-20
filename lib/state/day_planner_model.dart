import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/day_schedule.dart';
import '../models/schedule_suggestion.dart';
import '../models/task.dart';
import '../services/day_repository.dart';
import '../services/scheduler.dart';

/// Central state holder for the current day's tasks.
///
/// Holds a [List<Task>] for the [viewedDate] and exposes CRUD methods.
/// All mutations replace the task in the list (immutable model) and call
/// [notifyListeners].
///
/// Also maintains a cached [DaySchedule] that is recomputed when
/// schedule-affecting fields change (type, startTime, duration, priority,
/// status, startedAt). Title-only edits skip the reschedule.
///
/// Overlap validation: [addTask] and [updateTask] throw [ArgumentError]
/// if a hard/pinned task's time range overlaps with an existing hard task.
///
/// Persistence: when a [DayRepository] is provided, the model loads tasks
/// from storage on [loadDate] and saves them after every mutation with a
/// 500 ms debounce. On [AppLifecycleState.paused] the save is immediate.
class DayPlannerModel extends ChangeNotifier with WidgetsBindingObserver {
  DayPlannerModel({DateTime? initialDate, DayRepository? repository})
      : _viewedDate = _dateOnly(initialDate ?? DateTime.now()),
        _repository = repository;

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
  /// Non-null after a mutation (add/edit/delete/start/cancel/complete, or
  /// an overrun detection) causes the schedule to shift in a way that
  /// affects tasks other than the one directly mutated.
  ScheduleSuggestion? get suggestion => _suggestion;

  bool _isLoading = false;

  /// True while an async load is in progress.
  bool get isLoading => _isLoading;

  // ── Persistence ─────────────────────────────────────────────────────

  final DayRepository? _repository;
  Timer? _saveTimer;

  /// Loads tasks for [date] from the repository (if any) and replaces
  /// the in-memory state. Also registers this model as a lifecycle
  /// observer on the first call.
  Future<void> loadDate(DateTime date) async {
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);

    _viewedDate = _dateOnly(date);
    _tasks.clear();
    _suggestion = null;
    _schedule = DaySchedule.empty;
    _isLoading = true;
    notifyListeners();

    if (_repository != null) {
      final loaded = await _repository.load(_viewedDate);
      _tasks.addAll(loaded);
    }

    _reschedule();
    _ensureOverrunMonitor();
    _isLoading = false;
    notifyListeners();
  }

  /// Saves the current tasks to the repository immediately.
  Future<void> _saveNow() async {
    if (_repository == null) return;
    await _repository.save(_viewedDate, List.of(_tasks));
  }

  /// Cancels any pending debounced save and schedules a new one in 500 ms.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveTimer?.cancel();
      _saveNow();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _overrunTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── CRUD ────────────────────────────────────────────────────────────

  /// Adds a task to the current day.
  ///
  /// Throws [ArgumentError] if the task is hard/pinned and its time range
  /// overlaps with an existing hard task.
  void addTask(Task task) {
    _validateOverlap(task);
    _tasks.add(task);
    _rescheduleAndDiff(excludeTaskId: task.id);
    _ensureOverrunMonitor();
    _scheduleSave();
    notifyListeners();
  }

  /// Removes the task with the given [id].
  ///
  /// Returns `true` if a task was removed, `false` if no task matched.
  bool removeTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return false;
    _tasks.removeAt(index);
    _rescheduleAndDiff(excludeTaskId: id);
    _ensureOverrunMonitor();
    _scheduleSave();
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
      _rescheduleAndDiff(excludeTaskId: id);
    }

    _ensureOverrunMonitor();
    _scheduleSave();
    notifyListeners();
  }

  /// Marks the task with [id] as [TaskStatus.inProgress] and starts its
  /// live time tracker (`startedAt = now`). No-op if the task is not
  /// currently [TaskStatus.notStarted].
  void startTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;
    if (_tasks[index].status != TaskStatus.notStarted) return;

    _tasks[index] = _tasks[index].copyWith(
      status: TaskStatus.inProgress,
      startedAt: () => DateTime.now(),
    );
    _rescheduleAndDiff(excludeTaskId: id);
    _ensureOverrunMonitor();
    _scheduleSave();
    notifyListeners();
  }

  /// Marks the task with [id] as [TaskStatus.cancelled], freeing its slot.
  /// Available from [TaskStatus.notStarted] or [TaskStatus.inProgress];
  /// no-op if the task is already `complete` or `cancelled`.
  void cancelTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final current = _tasks[index];
    if (current.status == TaskStatus.complete ||
        current.status == TaskStatus.cancelled) {
      return;
    }

    _tasks[index] = current.copyWith(status: TaskStatus.cancelled);
    _rescheduleAndDiff(excludeTaskId: id);
    _ensureOverrunMonitor();
    _scheduleSave();
    notifyListeners();
  }

  /// Marks the task with [id] as complete at the given [completedAt] time.
  ///
  /// Computes [Task.actualDurationMinutes] from [Task.startedAt] to
  /// [completedAt]; if the task was never started, `startedAt` is backfilled
  /// to [completedAt] (zero tracked time).
  ///
  /// After marking complete, computes a proposed reschedule and generates
  /// a [ScheduleSuggestion] if any other tasks would shift.
  void markComplete(String id, DateTime completedAt) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final current = _tasks[index];
    if (current.status == TaskStatus.complete ||
        current.status == TaskStatus.cancelled) {
      return;
    }

    final startedAt = current.startedAt ?? completedAt;
    final rawMinutes = completedAt.difference(startedAt).inMinutes;
    final actualDurationMinutes = rawMinutes < 0 ? 0 : rawMinutes;

    _tasks[index] = current.copyWith(
      status: TaskStatus.complete,
      completedAt: () => completedAt,
      startedAt: () => startedAt,
      actualDurationMinutes: () => actualDurationMinutes,
    );

    _rescheduleAndDiff(excludeTaskId: id);
    _ensureOverrunMonitor();
    _scheduleSave();
    notifyListeners();
  }

  /// Accepts the current suggestion, committing the proposed schedule.
  void acceptSuggestion() {
    if (_suggestion == null) return;
    // The proposed schedule is already _schedule (reschedule ran as part
    // of the triggering mutation). We just clear the suggestion.
    _suggestion = null;
    notifyListeners();
  }

  /// Dismisses the current suggestion without applying it.
  void dismissSuggestion() {
    if (_suggestion == null) return;
    _suggestion = null;
    notifyListeners();
  }

  // ── Multi-day navigation ─────────────────────────────────────────────

  /// Saves the current day (if dirty), switches to [newDate], and loads
  /// its tasks. Incomplete non-hard tasks from the previous day that
  /// have not already been carried to [newDate] are added as carry-forward
  /// tasks.
  Future<void> setViewedDate(DateTime newDate) async {
    // Save the current day before switching.
    _saveTimer?.cancel();
    await _saveNow();

    final previousDate = _viewedDate;
    final previousTasks = List<Task>.of(_tasks);

    // Load the new date from the repository.
    await loadDate(newDate);

    // Carry forward: only when moving forward in time (next-day navigation).
    // We carry incomplete, non-hard tasks that haven't been carried yet or
    // that originated on the previous day.
    final targetDate = _dateOnly(newDate);
    final isForwardNavigation =
        targetDate.isAfter(_dateOnly(previousDate));

    if (isForwardNavigation) {
      final alreadyCarriedIds = _tasks
          .where((t) =>
              t.carriedFromDate != null &&
              _dateOnly(t.carriedFromDate!) == _dateOnly(previousDate))
          .map((t) => t.id)
          .toSet();

      for (final old in previousTasks) {
        if (old.status == TaskStatus.complete) continue;
        if (old.status == TaskStatus.cancelled) continue;
        if (old.type == TaskType.hard) continue;
        if (alreadyCarriedIds.contains(old.id)) continue;

        final carried = old.copyWith(
          // New ID so the task is treated as a new entity on the new day.
          id: null,
          date: targetDate,
          carriedFromDate: () => _dateOnly(previousDate),
          // Pinned tasks become floating when carried to preserve scheduling
          // flexibility; the user can re-pin if desired.
          type: old.type == TaskType.pinned ? TaskType.floating : null,
          startTime: old.type == TaskType.pinned ? () => null : null,
        );
        _tasks.add(carried);
      }

      if (previousTasks.any((t) =>
          t.status != TaskStatus.complete &&
          t.status != TaskStatus.cancelled &&
          t.type != TaskType.hard &&
          !alreadyCarriedIds.contains(t.id))) {
        _reschedule();
        _ensureOverrunMonitor();
        await _saveNow();
        notifyListeners();
      }
    }
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

  /// Re-runs [_reschedule] and diffs the result against the previous
  /// schedule to decide whether the change should be surfaced as a
  /// [ScheduleSuggestion] banner.
  ///
  /// [excludeTaskId], when provided, is the id of the task that directly
  /// triggered the mutation (e.g. the task just added, started, cancelled,
  /// or completed) — its own repositioning is a direct, expected effect
  /// of the mutation and is never itself reported as a move.
  ///
  /// The recompute is always applied (this._schedule reflects the latest
  /// truth). A suggestion is only populated — surfacing the Accept/Dismiss
  /// banner — when it would move an already-committed task, or change
  /// which tasks are in the overflow list, other than [excludeTaskId].
  /// Otherwise the change is auto-committed silently (no banner).
  void _rescheduleAndDiff({String? excludeTaskId}) {
    final oldSchedule = _schedule;
    _reschedule();

    final candidate = _buildSuggestion(
      oldSchedule,
      _schedule,
      excludeTaskId: excludeTaskId,
    );
    _suggestion = candidate.hasChanges ? candidate : null;
  }

  /// Returns `true` if any schedule-affecting field differs between
  /// [oldTask] and [newTask]. Title-only edits return `false`.
  static bool _scheduleFieldsChanged(Task oldTask, Task newTask) {
    return oldTask.type != newTask.type ||
        oldTask.startTime != newTask.startTime ||
        oldTask.durationMinutes != newTask.durationMinutes ||
        oldTask.priority != newTask.priority ||
        oldTask.status != newTask.status ||
        oldTask.startedAt != newTask.startedAt;
  }

  // ── Overrun monitoring ──────────────────────────────────────────────

  Timer? _overrunTimer;

  /// Starts or stops the periodic overrun-check timer depending on
  /// whether any task is currently [TaskStatus.inProgress]. While such a
  /// task exists, the schedule is periodically recomputed so a task
  /// running past its estimate is reflected in downstream floating-task
  /// placement without requiring another user action.
  void _ensureOverrunMonitor() {
    final hasInProgress = _tasks.any((t) => t.status == TaskStatus.inProgress);
    if (hasInProgress) {
      _overrunTimer ??= Timer.periodic(
        AppConstants.overrunCheckInterval,
        (_) => _checkOverrun(),
      );
    } else {
      _overrunTimer?.cancel();
      _overrunTimer = null;
    }
  }

  /// Recomputes the schedule so an in-progress task that has started
  /// overrunning its estimate is reflected in downstream placement,
  /// surfacing a suggestion if the recompute displaces other tasks.
  void _checkOverrun() {
    _rescheduleAndDiff();
    notifyListeners();
  }

  // ── Suggestion diff ─────────────────────────────────────────────────

  /// Compares [oldSchedule] against the new [proposed] schedule.
  ///
  /// Produces a [ScheduleSuggestion] containing moves for any incomplete
  /// non-hard task whose computed start time changed, and flags whether
  /// any task moved into/out of the overflow list — excluding
  /// [excludeTaskId], whose own repositioning is a direct effect of the
  /// mutation that produced [proposed], not a side effect on other tasks.
  static ScheduleSuggestion _buildSuggestion(
    DaySchedule oldSchedule,
    DaySchedule proposed, {
    String? excludeTaskId,
  }) {
    // Build a lookup: taskId → old start minutes.
    final oldStarts = <String, TimeOfDay>{};
    for (final st in oldSchedule.committed) {
      oldStarts[st.task.id] = st.computedStartTime;
    }

    final moves = <TaskMove>[];
    for (final st in proposed.committed) {
      if (st.task.id == excludeTaskId) continue;
      // Hard tasks are never moved.
      if (st.task.type == TaskType.hard) continue;
      // Only report moves for tasks that are still active.
      if (st.task.status == TaskStatus.complete) continue;
      if (st.task.status == TaskStatus.cancelled) continue;

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

    Set<String> overflowIds(List<Task> tasks) => tasks
        .where((t) => t.id != excludeTaskId)
        .map((t) => t.id)
        .toSet();

    final oldOverflowIds = overflowIds(oldSchedule.overflow);
    final newOverflowIds = overflowIds(proposed.overflow);
    final overflowChanged = !setEquals(oldOverflowIds, newOverflowIds);

    return ScheduleSuggestion(
      proposed: proposed,
      moves: moves,
      overflowChanged: overflowChanged,
    );
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
