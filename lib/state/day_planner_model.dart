import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/day_schedule.dart';
import '../models/schedule_suggestion.dart';
import '../models/scheduled_task.dart';
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
/// schedule-affecting fields change (type, startTime, duration, isOutcome,
/// status, startedAt). Title-only edits skip the reschedule.
///
/// Overlap validation: [addTask] and [updateTask] throw [ArgumentError]
/// if a hard/pinned task's time range overlaps with an existing hard task.
///
/// Outcome cap: [addTask] and [updateTask] throw [ArgumentError] if the
/// day would have more than [outcomeCap] Outcomes.
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

  /// The schedule as it was before the pending [_suggestion] was raised.
  /// Non-null exactly when [_suggestion] is non-null. Dismissing restores
  /// displaced tasks to their positions in this schedule.
  DaySchedule? _suggestionBase;

  /// Floating tasks held at a start time by a dismissed suggestion,
  /// keyed by task id. Held tasks are scheduled as if pinned at that time.
  /// Released by the next user mutation, or when the hold falls into the
  /// past or collides with a fixed block (e.g. an overrunning task).
  final Map<String, TimeOfDay> _heldStarts = {};

  /// Maximum number of Outcomes per day. Owned by settings; defaults to 3.
  int outcomeCap = 3;

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
    _suggestionBase = null;
    _heldStarts.clear();
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
    _validateOutcomeCap(task);
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
    _validateOutcomeCap(updated, excludeId: id);

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
    _suggestionBase = null;
    notifyListeners();
  }

  /// Dismisses the current suggestion without applying it.
  ///
  /// Floating tasks keep the positions they had before the suggestion was
  /// raised; the rest of the day is rescheduled around them.
  void dismissSuggestion() {
    if (_suggestion == null) return;
    for (final st in _suggestionBase!.committed) {
      if (st.task.type == TaskType.floating) {
        _heldStarts[st.task.id] = st.computedStartTime;
      }
    }
    _suggestion = null;
    _suggestionBase = null;
    _reschedule();
    notifyListeners();
  }

  // ── Multi-day navigation ─────────────────────────────────────────────

  /// Saves the current day, then switches to [newDate] and loads its tasks.
  Future<void> setViewedDate(DateTime newDate) async {
    _saveTimer?.cancel();
    await _saveNow();
    await loadDate(newDate);
  }

  /// Moves the task with [id] from the viewed day to [date], resetting it
  /// to not started. It keeps its Outcome flag unless [date] is already at
  /// the outcome cap. Pinned tasks become floating, since their time was
  /// chosen for the original day. Without a repository the task is only
  /// removed from the viewed day.
  Future<void> moveToDate(String id, DateTime date) async {
    final target = _dateOnly(date);
    if (target == _viewedDate) return;
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final task = _tasks[index];
    removeTask(id);

    if (_repository == null) return;
    final targetTasks = await _repository.load(target);
    final targetOutcomes = targetTasks
        .where((t) => t.isOutcome && t.status != TaskStatus.cancelled)
        .length;
    final moved = task.copyWith(
      date: target,
      carriedFromDate: () => task.carriedFromDate ?? _viewedDate,
      status: TaskStatus.notStarted,
      startedAt: () => null,
      completedAt: () => null,
      actualDurationMinutes: () => null,
      isOutcome: task.isOutcome && targetOutcomes < outcomeCap,
      type: task.type == TaskType.pinned ? TaskType.floating : null,
      startTime: task.type == TaskType.pinned ? () => null : null,
    );
    await _repository.save(target, [...targetTasks, moved]);
  }

  // ── Scheduling ──────────────────────────────────────────────────────

  /// Re-runs the scheduling engine on the current task list.
  void _reschedule() {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    _releaseInvalidHolds(nowMinutes);

    // Held tasks are handed to the scheduler as pinned at their held start,
    // then mapped back to the real (floating) task in the result.
    final result = Scheduler.schedule(
      [
        for (final t in _tasks)
          _heldStarts.containsKey(t.id)
              ? t.copyWith(
                  type: TaskType.pinned,
                  startTime: () => _heldStarts[t.id],
                )
              : t,
      ],
      dayStartHour: AppConstants.dayStartHour,
      dayEndHour: AppConstants.dayEndHour,
      nowMinutes: nowMinutes,
    );

    if (_heldStarts.isEmpty) {
      _schedule = result;
      return;
    }
    final byId = {for (final t in _tasks) t.id: t};
    _schedule = DaySchedule(
      committed: [
        for (final st in result.committed)
          _heldStarts.containsKey(st.task.id)
              ? ScheduledTask(
                  task: byId[st.task.id]!,
                  computedStartTime: st.computedStartTime,
                )
              : st,
      ],
      overflow: result.overflow,
    );
  }

  /// Drops holds that no longer make sense: the task is gone, no longer a
  /// not-started floating task, its held start is in the past (floating
  /// tasks are never placed in the past), or it collides with a fixed
  /// block such as a hard task or an overrunning in-progress task.
  void _releaseInvalidHolds(int nowMinutes) {
    if (_heldStarts.isEmpty) return;

    final fixedBlocks = <(int, int)>[];
    for (final t in _tasks) {
      if (_heldStarts.containsKey(t.id)) continue;
      if (t.status == TaskStatus.inProgress && t.startedAt != null) {
        final start = t.startedAt!.hour * 60 + t.startedAt!.minute;
        final elapsed = nowMinutes - start;
        final duration =
            elapsed > t.durationMinutes ? elapsed : t.durationMinutes;
        fixedBlocks.add((start, start + duration));
      } else if (t.startTime != null) {
        final start = _toMinutes(t.startTime!);
        fixedBlocks.add((start, start + t.durationMinutes));
      }
    }

    final byId = {for (final t in _tasks) t.id: t};
    _heldStarts.removeWhere((id, heldStart) {
      final task = byId[id];
      if (task == null ||
          task.type != TaskType.floating ||
          task.status != TaskStatus.notStarted) {
        return true;
      }
      final start = _toMinutes(heldStart);
      final end = start + task.durationMinutes;
      if (start < nowMinutes) return true;
      return fixedBlocks.any((b) => start < b.$2 && end > b.$1);
    });
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
  ///
  /// While a suggestion is pending, the diff is taken against the schedule
  /// from before that suggestion, so unanswered moves stay in the banner
  /// (e.g. across periodic overrun checks) until accepted or dismissed.
  ///
  /// [releaseHolds] clears positions held by a dismissed suggestion; user
  /// mutations pass `true` so the day is replanned fresh.
  void _rescheduleAndDiff({String? excludeTaskId, bool releaseHolds = true}) {
    if (releaseHolds) _heldStarts.clear();
    final base = _suggestionBase ?? _schedule;
    _reschedule();

    final candidate = _buildSuggestion(
      base,
      _schedule,
      excludeTaskId: excludeTaskId,
    );
    _suggestion = candidate.hasChanges ? candidate : null;
    _suggestionBase = candidate.hasChanges ? base : null;
  }

  /// Returns `true` if any schedule-affecting field differs between
  /// [oldTask] and [newTask]. Title-only edits return `false`.
  static bool _scheduleFieldsChanged(Task oldTask, Task newTask) {
    return oldTask.type != newTask.type ||
        oldTask.startTime != newTask.startTime ||
        oldTask.durationMinutes != newTask.durationMinutes ||
        oldTask.isOutcome != newTask.isOutcome ||
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
    _rescheduleAndDiff(releaseHolds: false);
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
      // In-progress tasks are never moved (PRD: excluded from suggestions).
      if (st.task.status == TaskStatus.inProgress) continue;
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

  /// Throws [ArgumentError] if [task] is an Outcome and the day already
  /// has [outcomeCap] active (non-cancelled) Outcomes besides [excludeId].
  void _validateOutcomeCap(Task task, {String? excludeId}) {
    if (!task.isOutcome) return;
    final count = _tasks
        .where((t) =>
            t.id != excludeId &&
            t.isOutcome &&
            t.status != TaskStatus.cancelled)
        .length;
    if (count >= outcomeCap) {
      throw ArgumentError(
        'You already have $outcomeCap outcome${outcomeCap == 1 ? '' : 's'} '
        'today. Finish or remove one first.',
      );
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
