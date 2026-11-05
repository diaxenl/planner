import 'dart:async';

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/day_schedule.dart';
import '../models/schedule_suggestion.dart';
import '../models/scheduled_task.dart';
import '../models/task.dart';
import '../models/calendar_event.dart';
import '../services/calendar_source.dart';
import '../services/day_repository.dart';
import '../services/day_stats.dart';
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
  DayPlannerModel({
    DateTime? initialDate,
    DayRepository? repository,
    CalendarSource calendarSource = const NoCalendarSource(),
  })  : _viewedDate = _dateOnly(initialDate ?? DateTime.now()),
        _repository = repository,
        _calendarSource = calendarSource;

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
    _events = await _fetchEvents();

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

  // ── Calendar ────────────────────────────────────────────────────────

  final CalendarSource _calendarSource;

  /// Calendars to import from. `null` = all. Owned by settings; call
  /// [refreshCalendar] after changing it.
  Set<String>? calendarIds;

  List<CalendarEvent> _events = const [];

  static const _importedPrefix = 'cal:';

  /// All-day events on the viewed day, shown as labels, not blocks.
  List<CalendarEvent> get allDayEvents =>
      _events.where((e) => e.isAllDay).toList(growable: false);

  /// Whether [task] is an imported calendar meeting (read-only; it never
  /// appears in [tasks] and is never persisted).
  bool isImported(Task task) => task.id.startsWith(_importedPrefix);

  /// Re-reads the viewed day's calendar events and replans. Surfaces a
  /// suggestion if a new or moved meeting displaces scheduled work.
  Future<void> refreshCalendar() async {
    _events = await _fetchEvents();
    _rescheduleAndDiff(releaseHolds: false);
    notifyListeners();
  }

  Future<List<CalendarEvent>> _fetchEvents() async {
    try {
      return await _calendarSource.eventsFor(_viewedDate, calendarIds);
    } catch (_) {
      // Calendar access is best-effort; the planner works without it.
      return const [];
    }
  }

  /// Timed events as read-only Meeting tasks, clipped to the viewed day.
  List<Task> get _eventTasks {
    final dayStart = _viewedDate;
    final dayEnd = dayStart.add(const Duration(days: 1));
    return [
      for (final e in _events)
        if (!e.isAllDay && e.end.isAfter(dayStart) && e.start.isBefore(dayEnd))
          () {
            final start = e.start.isBefore(dayStart) ? dayStart : e.start;
            final end = e.end.isAfter(dayEnd) ? dayEnd : e.end;
            final minutes = end.difference(start).inMinutes;
            return Task(
              id: '$_importedPrefix${e.id}',
              title: e.title.isEmpty ? 'Busy' : e.title,
              durationMinutes: minutes < 1 ? 1 : minutes,
              type: TaskType.hard,
              startTime: TimeOfDay.fromDateTime(start),
              date: _viewedDate,
            );
          }(),
    ];
  }

  // ── Scheduling ──────────────────────────────────────────────────────

  /// Re-runs the scheduling engine on the current task list.
  void _reschedule() {
    final nowMinutes = _nowMinutesForViewedDay;
    _releaseInvalidHolds(nowMinutes ?? AppConstants.dayStartHour * 60);

    // Held tasks are handed to the scheduler as pinned at their held start,
    // then mapped back to the real (floating) task in the result.
    final result = Scheduler.schedule(
      [
        ..._eventTasks,
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

  /// The current time in minutes from midnight when viewing today;
  /// `null` for any other day, so the whole day window is plannable.
  int? get _nowMinutesForViewedDay {
    final now = DateTime.now();
    if (_dateOnly(now) != _viewedDate) return null;
    return now.hour * 60 + now.minute;
  }

  /// Re-flows today's schedule as the clock moves, so not-started work
  /// never sits in the past. Silent: no suggestion is raised, and a
  /// pending one is left as is. No-op when not viewing today.
  void tick() {
    if (!isViewingToday) return;
    _reschedule();
    notifyListeners();
  }

  /// Whether the viewed day is today.
  bool get isViewingToday => _dateOnly(DateTime.now()) == _viewedDate;

  /// What to show on the Now card: see [DayStats.currentItem]. Always
  /// `null` when not viewing today.
  ScheduledTask? get currentItem {
    final nowMinutes = _nowMinutesForViewedDay;
    if (nowMinutes == null) return null;
    return DayStats.currentItem(_schedule, nowMinutes);
  }

  /// Drops holds that no longer make sense: the task is gone, no longer a
  /// not-started floating task, its held start is in the past (floating
  /// tasks are never placed in the past), or it collides with a fixed
  /// block such as a hard task or an overrunning in-progress task.
  void _releaseInvalidHolds(int nowMinutes) {
    if (_heldStarts.isEmpty) return;

    final fixedBlocks = <(int, int)>[];
    for (final t in [..._eventTasks, ..._tasks]) {
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

  /// Compares [oldSchedule] against the new [proposed] schedule and
  /// keeps only what deserves the user's attention:
  /// - an active Outcome that now starts *later* (earlier is good news and
  ///   other work reshuffling is noise — both are applied silently), and
  /// - any task newly pushed out of the day into overflow.
  /// [excludeTaskId] — the task the user just acted on — is never reported.
  static ScheduleSuggestion _buildSuggestion(
    DaySchedule oldSchedule,
    DaySchedule proposed, {
    String? excludeTaskId,
  }) {
    final oldStarts = {
      for (final st in oldSchedule.committed) st.task.id: st.startMinutes,
    };

    final moves = <TaskMove>[];
    for (final st in proposed.committed) {
      final t = st.task;
      if (t.id == excludeTaskId) continue;
      if (!t.isOutcome || t.status != TaskStatus.notStarted) continue;
      final oldStart = oldStarts[t.id];
      if (oldStart == null || st.startMinutes <= oldStart) continue;
      moves.add(TaskMove(
        task: t,
        oldStart: TimeOfDay(hour: oldStart ~/ 60, minute: oldStart % 60),
        newStart: st.computedStartTime,
      ));
    }

    final oldOverflowIds = oldSchedule.overflow.map((t) => t.id).toSet();
    final pushedOut = [
      for (final t in proposed.overflow)
        if (t.id != excludeTaskId && !oldOverflowIds.contains(t.id)) t,
    ];

    return ScheduleSuggestion(
      proposed: proposed,
      moves: moves,
      pushedOut: pushedOut,
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

    final dayStart = AppConstants.dayStartHour * 60;
    final dayEnd = AppConstants.dayEndHour * 60;
    if (newStart < dayStart || newEnd > dayEnd) {
      throw ArgumentError(
        '${AppUtils.formatClock(newStart)}–${AppUtils.formatClock(newEnd)} '
        'is outside your day (${AppUtils.formatClock(dayStart)}–'
        '${AppUtils.formatClock(dayEnd)}).',
      );
    }

    // Fixed-time items (Meetings and Set-time items) may not overlap each
    // other. Finished items no longer hold their slot for this purpose.
    for (final existing in [..._eventTasks, ..._tasks]) {
      if (existing.id == excludeId) continue;
      if (existing.type == TaskType.floating) continue;
      if (existing.startTime == null) continue;
      if (existing.status == TaskStatus.cancelled ||
          existing.status == TaskStatus.complete) {
        continue;
      }

      final existStart = _toMinutes(existing.startTime!);
      final existEnd = existStart + existing.durationMinutes;

      if (newStart < existEnd && newEnd > existStart) {
        throw ArgumentError(
          'Overlaps "${existing.title}" '
          '(${AppUtils.formatClock(existStart)}–'
          '${AppUtils.formatClock(existEnd)}).',
        );
      }
    }
  }

  /// Throws [ArgumentError] if [task] is an Outcome and the day already
  /// has [outcomeCap] active (non-cancelled) Outcomes besides [excludeId].
  /// Edits that keep an existing Outcome an Outcome are always allowed, so
  /// lowering the cap never locks today's Outcomes.
  void _validateOutcomeCap(Task task, {String? excludeId}) {
    if (!task.isOutcome) return;
    if (excludeId != null &&
        _tasks.any((t) => t.id == excludeId && t.isOutcome)) {
      return;
    }
    final count = _tasks
        .where((t) =>
            t.id != excludeId &&
            t.isOutcome &&
            t.status != TaskStatus.cancelled)
        .length;
    if (count >= outcomeCap) {
      throw ArgumentError(
        "That's your limit of $outcomeCap outcome${outcomeCap == 1 ? '' : 's'} "
        'for the day. Remove one, or raise the limit in Settings.',
      );
    }
  }

  static int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
}
