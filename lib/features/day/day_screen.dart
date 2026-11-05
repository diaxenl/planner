import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../models/task.dart';
import '../../services/day_stats.dart';
import '../../state/day_planner_model.dart';
import '../../state/day_planner_provider.dart';
import '../settings/settings_screen.dart';
import 'widgets/agenda_list.dart';
import 'widgets/capture_bar.dart';
import 'widgets/day_header.dart';
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
  /// Rebuilds once a minute so the load bar and Now card follow the clock.
  late final Timer _minuteTicker;

  @override
  void initState() {
    super.initState();
    _minuteTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isToday = model.isViewingToday;
    final current = model.currentItem;
    final now = DateTime.now();

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
                onSettings: () => SettingsScreen.open(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    LoadBar(load: load, isToday: isToday),
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
                        onStart: () => model.startTask(current!.task.id),
                        onDone: () =>
                            model.markComplete(current!.task.id, DateTime.now()),
                        onCancel: () => model.cancelTask(current!.task.id),
                        onTap: () => _edit(context, model, current!.task),
                      ),
                    ],
                    const SizedBox(height: 28),
                    OutcomesList(
                      tasks: model.tasks.where((t) => t.isOutcome).toList(),
                      schedule: model.schedule,
                      cap: model.outcomeCap,
                      onDone: (t) => model.markComplete(t.id, DateTime.now()),
                      onTap: (t) => _edit(context, model, t),
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
                      onTap: (t) => _edit(context, model, t),
                    ),
                  ],
                ),
              ),
              CaptureBar(
                onSubmit: (raw) {
                  final title = raw.trim();
                  ItemSheet.show(
                    context,
                    model: model,
                    draft: Task(
                      title: title,
                      durationMinutes: 30,
                      type: TaskType.floating,
                      date: model.viewedDate,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _edit(BuildContext context, DayPlannerModel model, Task task) {
    ItemSheet.show(
      context,
      model: model,
      existing: task,
      onDeleted: (deleted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Deleted "${deleted.title}"'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => model.addTask(deleted),
              ),
            ),
          );
      },
    );
  }
}
