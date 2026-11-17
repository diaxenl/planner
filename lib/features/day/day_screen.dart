import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils.dart';
import '../../models/scheduled_task.dart';
import '../../models/task.dart';
import '../../services/capture_parser.dart';
import '../../services/day_stats.dart';
import '../../state/day_planner_model.dart';
import '../../state/day_planner_provider.dart';
import '../../state/settings_provider.dart';
import '../review/review_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/agenda_list.dart';
import 'widgets/capture_bar.dart';
import 'widgets/day_header.dart';
import 'widgets/day_picker.dart';
import 'widgets/interruption_sheet.dart';
import 'widgets/item_sheet.dart';
import 'widgets/load_bar.dart';
import 'widgets/missed_list.dart';
import 'widgets/now_card.dart';
import 'widgets/outcomes_list.dart';
import 'widgets/start_prompt.dart';
import 'widgets/suggestion_banner.dart';

/// Home screen — one day, built around its Outcomes.
///
/// Top to bottom: header, load bar, suggestion banner, Now card (today
/// only), Outcomes, Schedule; capture bar pinned at the bottom. A day
/// (today or later) with nothing of your own on it shows only the
/// [StartPrompt] and any meetings, so there is one obvious first step.
class DayScreen extends StatefulWidget {
  const DayScreen({super.key});

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  /// Re-flows today's schedule on each turn of the clock's minute, so
  /// nothing sits in the past and a meeting that just ended leaves the
  /// Now card at once (a free-running 1-minute timer could lag by ~60s).
  Timer? _minuteTicker;

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  void _scheduleTick() {
    final now = DateTime.now();
    final untilNextMinute =
        const Duration(minutes: 1) -
        Duration(seconds: now.second, milliseconds: now.millisecond);
    _minuteTicker = Timer(untilNextMinute, () {
      if (!mounted) return;
      DayPlannerProvider.of(context).tick();
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _minuteTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = DayPlannerProvider.of(context);
    // Depend on settings so a changed outcome cap is reflected at once.
    SettingsProvider.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isToday = model.isViewingToday;
    final current = model.currentItem;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Imported meetings don't count: the day still needs its first step.
    final isEmptyDay =
        !model.viewedDate.isBefore(today) &&
        model.tasks.every(model.isImported);

    final dayLabel = switch (AppUtils.relativeDayLabel(model.viewedDate, now)) {
      'Today' => 'today',
      'Tomorrow' => 'tomorrow',
      'Yesterday' => 'yesterday',
      final weekday => 'on $weekday',
    };

    final load = DayStats.loadBreakdown(
      model.schedule,
      nowMinutes: isToday
          ? now.hour * 60 + now.minute
          : model.workdayStartHour * 60,
      dayStartHour: model.workdayStartHour,
      dayEndHour: model.workdayEndHour,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              DayHeader(
                date: model.viewedDate,
                onPreviousDay: () => model.setViewedDate(
                  model.viewedDate.subtract(const Duration(days: 1)),
                ),
                onNextDay: () => model.setViewedDate(
                  model.viewedDate.add(const Duration(days: 1)),
                ),
                onToday: () => model.setViewedDate(DateTime.now()),
                onReview: () => ReviewScreen.open(context),
                onSettings: () => SettingsScreen.open(context),
              ),
              if (model.allDayEvents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'All day · ${model.allDayEvents.map((e) => e.title).join(' · ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: model.refreshCalendar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      if (isEmptyDay) ...[
                        StartPrompt(
                          dayLabel: dayLabel,
                          onSubmit: (raw) =>
                              _capture(model, raw, asOutcome: true),
                        ),
                        // The day's hours, even when empty: free time
                        // to plan into, and meetings once connected.
                        const SizedBox(height: 28),
                        _agenda(model, current),
                      ] else
                        ..._daySections(
                          model,
                          load: load,
                          dayLabel: dayLabel,
                          isToday: isToday,
                          current: current,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: CaptureBar(
              onSubmit: (raw) => _capture(model, raw),
              onSomethingCameUp: isToday ? () => _somethingCameUp(model) : null,
            ),
          ),
        ),
      ),
    );
  }

  /// The usual sections, once the day has something of your own on it.
  List<Widget> _daySections(
    DayPlannerModel model, {
    required LoadBreakdown load,
    required String dayLabel,
    required bool isToday,
    required ScheduledTask? current,
  }) => [
    LoadBar(load: load, dayLabel: dayLabel),
    if (model.suggestion != null) ...[
      const SizedBox(height: 20),
      SuggestionBanner(
        suggestion: model.suggestion!,
        onAccept: model.acceptSuggestion,
        onDismiss: model.dismissSuggestion,
      ),
    ],
    if (model.missedItems.isNotEmpty) ...[
      const SizedBox(height: 20),
      MissedList(
        tasks: model.missedItems,
        nextDayLabel: AppUtils.friendlyDate(
          AppUtils.nextWorkday(model.viewedDate),
          DateTime.now(),
        ),
        onLaterToday: (t) => _laterToday(model, t),
        onNextDay: (t) => _act(ItemAction.tomorrow, t),
        onDone: (t) => _act(ItemAction.done, t),
        fitsToday: (t) => model.fitsLaterToday(t.id),
      ),
    ],
    if (isToday) ...[
      const SizedBox(height: 20),
      NowCard(
        item: current,
        hasAnyTasks: model.tasks.isNotEmpty,
        onStart: () => _act(ItemAction.start, current!.task),
        onDone: () => _act(ItemAction.done, current!.task),
        onCancel: () => _act(ItemAction.cancel, current!.task),
        onTap: () => _edit(model, current!.task),
        onReview: () => ReviewScreen.open(context),
        running: model.runningBehindCurrent,
        startingSoon: model.fixedItemStartingSoon,
        onPause: () {
          final running = model.runningBehindCurrent;
          if (running != null) _pause(model, running.task);
        },
        onPauseCurrent: () {
          if (current != null) _pause(model, current.task);
        },
      ),
    ],
    const SizedBox(height: 28),
    OutcomesList(
      tasks: model.tasks.where((t) => t.isOutcome).toList(),
      schedule: model.schedule,
      cap: model.outcomeCap,
      dayLabel: dayLabel.startsWith('on ') ? 'this day' : dayLabel,
      onDone: (t) => _act(ItemAction.done, t),
      onTap: (t) => _edit(model, t),
      onReorder: model.reorderOutcomes,
      onAdd: () => ItemSheet.show(
        context,
        model: model,
        draft: Task(
          title: '',
          durationMinutes: 60,
          type: TaskType.floating,
          isOutcome: true,
          date: model.viewedDate,
        ),
      ),
    ),
    const SizedBox(height: 28),
    _agenda(model, current),
  ];

  Widget _agenda(DayPlannerModel model, ScheduledTask? current) => AgendaList(
    schedule: model.schedule,
    tasks: model.tasks,
    current: current,
    onTap: (t) => _edit(model, t),
    dayStartHour: model.workdayStartHour,
    dayEndHour: model.workdayEndHour,
    isToday: model.isViewingToday,
  );

  /// Parses capture shorthand, reading day words from today and times
  /// without am/pm against the workday.
  ParsedCapture _parse(DayPlannerModel model, String raw) =>
      CaptureParser.parse(
        raw,
        today: DateTime.now(),
        workdayStartHour: model.workdayStartHour,
        workdayEndHour: model.workdayEndHour,
      );

  /// Builds a task from capture shorthand: parsed duration (default 30m,
  /// or 1h for an Outcome), a parsed time makes it Set-time, `*` or
  /// [asOutcome] makes it an Outcome. The day named in the text is
  /// ignored here (see [_capture]).
  Task _fromCapture(
    DayPlannerModel model,
    String raw, {
    bool interruption = false,
    bool asOutcome = false,
  }) {
    final p = _parse(model, raw);
    return Task(
      title: p.title.isEmpty ? raw.trim() : p.title,
      durationMinutes: p.durationMinutes ?? (asOutcome ? 60 : 30),
      type: p.startTime != null ? TaskType.pinned : TaskType.floating,
      startTime: p.startTime,
      isOutcome: asOutcome || p.isOutcome,
      isInterruption: interruption,
      priority: p.priority ?? TaskPriority.normal,
      date: model.viewedDate,
    );
  }

  /// Adds straight away and confirms with an Edit shortcut; if the model
  /// rejects it (overlap, cap, out of range), opens the sheet to fix it.
  void _capture(DayPlannerModel model, String raw, {bool asOutcome = false}) {
    final task = _fromCapture(model, raw, asOutcome: asOutcome);
    final date = _parse(model, raw).date;
    if (date != null && date != model.viewedDate) {
      _captureToDay(model, task, date);
      return;
    }
    try {
      model.addTask(task);
    } on ArgumentError {
      ItemSheet.show(context, model: model, draft: task);
      return;
    }
    final now = TimeOfDay.now();
    final inThePast =
        model.isViewingToday &&
        task.startTime != null &&
        task.startTime!.hour * 60 + task.startTime!.minute <
            now.hour * 60 + now.minute;
    _snack(
      inThePast
          ? 'Added "${task.title}" at a time that has already passed'
          : 'Added "${task.title}" · ${_describe(task)}',
      actionLabel: 'Edit',
      onAction: () => _edit(model, task),
    );
  }

  /// Adds a captured item to another day ("Book flight 9am Friday"),
  /// with a shortcut to that day. If that day can't take it (overlap,
  /// out of range), goes there and opens the sheet to fix it.
  Future<void> _captureToDay(
    DayPlannerModel model,
    Task task,
    DateTime date,
  ) async {
    final Task saved;
    try {
      saved = await model.addTaskToDate(task, date);
    } on ArgumentError {
      await model.setViewedDate(date);
      if (!mounted) return;
      ItemSheet.show(
        context,
        model: model,
        draft: task.copyWith(date: model.viewedDate),
      );
      return;
    }
    final day = AppUtils.dayPhrase(date, DateTime.now());
    final lostOutcome = task.isOutcome && !saved.isOutcome;
    _snack(
      lostOutcome
          ? 'Added "${task.title}" to $day — not as an Outcome, that day is full'
          : 'Added "${task.title}" to $day · ${_describe(saved)}',
      actionLabel: 'Show',
      onAction: () => model.setViewedDate(date),
    );
  }

  Future<void> _somethingCameUp(DayPlannerModel model) async {
    final result = await InterruptionSheet.show(
      context,
      laterLabel: AppUtils.friendlyDate(
        AppUtils.nextWorkday(model.viewedDate),
        DateTime.now(),
      ),
    );
    if (result == null || !mounted) return;
    final (raw, choice) = result;
    final parsed = _fromCapture(model, raw, interruption: true);
    // An interruption isn't planned for a time; "Later today" lets the
    // scheduler place it.
    final task = parsed.copyWith(
      type: TaskType.floating,
      startTime: () => null,
    );
    try {
      model.addTask(task);
    } on ArgumentError {
      ItemSheet.show(context, model: model, draft: task);
      return;
    }
    switch (choice) {
      case InterruptionChoice.now:
        await _act(ItemAction.start, task);
      case InterruptionChoice.laterToday:
        _snack('Added "${task.title}" for later today');
      case InterruptionChoice.tomorrow:
        await _act(ItemAction.tomorrow, task);
    }
  }

  static String _describe(Task t) {
    final parts = <String>[
      AppUtils.formatDuration(t.durationMinutes),
      if (t.startTime != null)
        'at ${AppUtils.formatClock(t.startTime!.hour * 60 + t.startTime!.minute)}',
      if (t.isOutcome) 'Outcome',
      if (!t.isOutcome && t.priority == TaskPriority.high) 'High priority',
      if (!t.isOutcome && t.priority == TaskPriority.low) 'Low priority',
    ];
    return parts.join(' · ');
  }

  /// Opens [task] in the item sheet. If a saved edit moves Anytime work
  /// to a new time, says where it went, with Undo.
  Future<void> _edit(DayPlannerModel model, Task task) async {
    final index = model.tasks.indexWhere((t) => t.id == task.id);
    final startBefore = _firstStart(model, task.id);
    var actionTaken = false;
    final saved = await ItemSheet.show(
      context,
      model: model,
      existing: task,
      onAction: (action, t) {
        actionTaken = true;
        _act(action, t);
      },
      onDeleted: (deleted) => _snack(
        'Deleted "${deleted.title}"',
        undo: () => model.addTask(deleted, index: index),
      ),
    );
    if (saved != true || actionTaken || !mounted) return;
    final updated = model.tasks.where((t) => t.id == task.id).firstOrNull;
    if (updated == null || updated.type != TaskType.floating) return;
    final startAfter = _firstStart(model, task.id);
    if (startAfter == null || startAfter == startBefore) return;
    _snack(
      'Moved "${updated.title}" to ${AppUtils.formatClock(startAfter)}',
      undo: () => model.updateTask(task.id, task),
    );
  }

  /// When [id]'s first (or only) session starts, or `null` if unplaced.
  static int? _firstStart(DayPlannerModel model, String id) {
    final starts = [
      for (final st in model.schedule.committed)
        if (st.task.id == id) st.startMinutes,
    ];
    return starts.isEmpty ? null : starts.reduce((a, b) => a < b ? a : b);
  }

  /// Plans a missed set-time item into later today, with Undo.
  void _laterToday(DayPlannerModel model, Task task) {
    final before = model.planLaterToday(task.id);
    if (before == null) return;
    final start = _firstStart(model, task.id);
    _snack(
      start == null
          ? "\"${task.title}\" doesn't fit today"
          : 'Planned "${task.title}" for ${AppUtils.formatClock(start)}',
      undo: () => model.updateTask(before.id, before),
    );
  }

  /// Performs a status action and offers Undo, which restores the task as
  /// it was (or brings it back to this day, for Tomorrow).
  Future<void> _act(ItemAction action, Task task) async {
    final model = DayPlannerProvider.of(context);
    switch (action) {
      case ItemAction.start:
        final paused = model.startTask(task.id);
        if (paused.isNotEmpty) {
          _snack(
            'Paused "${paused.first.title}"',
            undo: () {
              model.updateTask(
                task.id,
                task.copyWith(
                  status: TaskStatus.notStarted,
                  startedAt: () => null,
                ),
              );
              for (final p in paused) {
                model.updateTask(p.id, p);
              }
            },
          );
        }
      case ItemAction.pause:
        _pause(model, task);
      case ItemAction.done:
        model.markComplete(task.id, DateTime.now());
        _snack(
          'Done: "${task.title}"',
          undo: () => model.updateTask(task.id, task),
        );
      case ItemAction.cancel:
        model.cancelTask(task.id);
        _snack(
          "Won't do: \"${task.title}\"",
          undo: () => model.updateTask(task.id, task),
        );
      case ItemAction.tomorrow:
        await _moveTo(model, task, AppUtils.nextWorkday(model.viewedDate));
      case ItemAction.pickDay:
        final day = await pickMoveDay(context, model.viewedDate);
        if (day != null) await _moveTo(model, task, day);
      case ItemAction.doNext:
        model.updateTask(
          task.id,
          task.copyWith(doNextAt: () => DateTime.now()),
        );
        _snack(
          'Doing "${task.title}" next',
          undo: () => model.updateTask(task.id, task),
        );
    }
  }

  /// Moves [task] to [day] with Undo.
  Future<void> _moveTo(DayPlannerModel model, Task task, DateTime day) async {
    final from = model.viewedDate;
    final index = model.tasks.indexWhere((t) => t.id == task.id);
    final moved = await model.moveToDate(task.id, day);
    final phrase = AppUtils.dayPhrase(day, DateTime.now());
    final lostOutcome = task.isOutcome && moved != null && !moved.isOutcome;
    final lostTime =
        task.type == TaskType.pinned &&
        moved != null &&
        moved.type != TaskType.pinned;
    final at = moved?.startTime == null
        ? ''
        : ' at ${AppUtils.formatClock(moved!.startTime!.hour * 60 + moved.startTime!.minute)}';
    _snack(
      lostOutcome
          ? 'Moved "${task.title}" to $phrase — not as an Outcome, '
                'that day is full'
          : lostTime
          ? 'Moved "${task.title}" to $phrase — as Anytime, '
                'that time is taken'
          : 'Moved "${task.title}" to $phrase$at',
      undo: () {
        // Only meaningful while still on the day it came from.
        if (model.viewedDate == from) {
          model.undoMoveToDate(task, day, index: index);
        }
      },
    );
  }

  /// Pauses a running task (minutes tracked so far are kept), with Undo.
  void _pause(DayPlannerModel model, Task task) {
    final before = model.pauseTask(task.id);
    if (before == null) return;
    _snack(
      'Paused "${task.title}"',
      undo: () => model.updateTask(before.id, before),
    );
  }

  void _snack(
    String message, {
    VoidCallback? undo,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final action = undo ?? onAction;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          // With an action Flutter keeps a toast up until dismissed; let
          // it go after a few seconds so it doesn't cover the schedule.
          persist: false,
          // Long enough to read and reach Undo.
          duration: const Duration(seconds: 8),
          action: action == null
              ? null
              : SnackBarAction(
                  label: undo != null ? 'Undo' : actionLabel!,
                  onPressed: () {
                    try {
                      action();
                    } on ArgumentError catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text("Couldn't undo: ${e.message}")),
                      );
                    }
                  },
                ),
        ),
      );
  }
}
