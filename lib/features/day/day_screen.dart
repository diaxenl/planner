import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
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
import 'widgets/interruption_sheet.dart';
import 'widgets/item_sheet.dart';
import 'widgets/load_bar.dart';
import 'widgets/now_card.dart';
import 'widgets/outcomes_list.dart';
import 'widgets/suggestion_banner.dart';

/// Home screen — one day, built around its Outcomes.
///
/// Top to bottom: header, load bar, suggestion banner, Now card (today
/// only), Outcomes, Schedule; capture bar pinned at the bottom.
class DayScreen extends StatefulWidget {
  const DayScreen({super.key});

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  /// Once a minute, re-flow today's schedule so nothing sits in the past.
  late final Timer _minuteTicker;

  @override
  void initState() {
    super.initState();
    _minuteTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) DayPlannerProvider.of(context).tick();
    });
  }

  @override
  void dispose() {
    _minuteTicker.cancel();
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
          : AppConstants.dayStartHour * 60,
      dayStartHour: AppConstants.dayStartHour,
      dayEndHour: AppConstants.dayEndHour,
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
                      LoadBar(load: load, dayLabel: dayLabel),
                      if (model.suggestion != null) ...[
                        const SizedBox(height: 20),
                        SuggestionBanner(
                          suggestion: model.suggestion!,
                          onAccept: model.acceptSuggestion,
                          onDismiss: model.dismissSuggestion,
                        ),
                      ],
                      if (isToday) ...[
                        const SizedBox(height: 20),
                        NowCard(
                          item: current,
                          hasAnyTasks: model.tasks.isNotEmpty,
                          onStart: () => _act(ItemAction.start, current!.task),
                          onDone: () => _act(ItemAction.done, current!.task),
                          onCancel: () =>
                              _act(ItemAction.cancel, current!.task),
                          onTap: () => _edit(model, current!.task),
                          onReview: () => ReviewScreen.open(context),
                        ),
                      ],
                      const SizedBox(height: 28),
                      OutcomesList(
                        tasks: model.tasks.where((t) => t.isOutcome).toList(),
                        schedule: model.schedule,
                        cap: model.outcomeCap,
                        dayLabel: dayLabel.startsWith('on ')
                            ? 'this day'
                            : dayLabel,
                        onDone: (t) => _act(ItemAction.done, t),
                        onTap: (t) => _edit(model, t),
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
                      AgendaList(
                        schedule: model.schedule,
                        tasks: model.tasks,
                        currentTaskId: current?.task.id,
                        onTap: (t) => _edit(model, t),
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

  /// Builds a task from capture shorthand: parsed duration (default 30m),
  /// a parsed time makes it Set-time, `*` makes it an Outcome.
  Task _fromCapture(
    DayPlannerModel model,
    String raw, {
    bool interruption = false,
  }) {
    final p = CaptureParser.parse(raw);
    return Task(
      title: p.title.isEmpty ? raw.trim() : p.title,
      durationMinutes: p.durationMinutes ?? 30,
      type: p.startTime != null ? TaskType.pinned : TaskType.floating,
      startTime: p.startTime,
      isOutcome: p.isOutcome,
      isInterruption: interruption,
      date: model.viewedDate,
    );
  }

  /// Adds straight away and confirms with an Edit shortcut; if the model
  /// rejects it (overlap, cap, out of range), opens the sheet to fix it.
  void _capture(DayPlannerModel model, String raw) {
    final task = _fromCapture(model, raw);
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

  Future<void> _somethingCameUp(DayPlannerModel model) async {
    final result = await InterruptionSheet.show(context);
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
    ];
    return parts.join(' · ');
  }

  void _edit(DayPlannerModel model, Task task) {
    ItemSheet.show(
      context,
      model: model,
      existing: task,
      onAction: _act,
      onDeleted: (deleted) => _snack(
        'Deleted "${deleted.title}"',
        undo: () => model.addTask(deleted),
      ),
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
      case ItemAction.done:
        model.markComplete(task.id, DateTime.now());
        _snack(
          'Done: "${task.title}"',
          undo: () => model.updateTask(task.id, task),
        );
      case ItemAction.cancel:
        model.cancelTask(task.id);
        _snack(
          'Cancelled "${task.title}"',
          undo: () => model.updateTask(task.id, task),
        );
      case ItemAction.tomorrow:
        final from = model.viewedDate;
        final next = from.add(const Duration(days: 1));
        final moved = await model.moveToDate(task.id, next);
        final lostOutcome = task.isOutcome && moved != null && !moved.isOutcome;
        _snack(
          lostOutcome
              ? 'Moved "${task.title}" to tomorrow — not as an Outcome, '
                    'tomorrow is full'
              : 'Moved "${task.title}" to tomorrow',
          undo: () {
            // Only meaningful while still on the day it came from.
            if (model.viewedDate == from) model.undoMoveToDate(task, next);
          },
        );
    }
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
