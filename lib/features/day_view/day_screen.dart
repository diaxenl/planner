import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../state/day_planner_provider.dart';
import 'timeline_view.dart';
import 'widgets/day_header.dart';
import 'widgets/task_bottom_sheet.dart';
import 'widgets/unscheduled_section.dart';

/// Primary screen — displays a single day's timeline.
///
/// Reads from [DayPlannerModel] via [DayPlannerProvider] and renders
/// hard/pinned tasks on the timeline and floating tasks in an
/// unscheduled section below.
class DayScreen extends StatelessWidget {
  const DayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = DayPlannerProvider.of(context);
    final tasks = model.tasks;

    // Split tasks into placed (hard/pinned) and floating.
    final floatingTasks =
        tasks.where((t) => t.type == TaskType.floating).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DayHeader(date: model.viewedDate),
            Expanded(
              child: TimelineView(
                tasks: tasks,
                onTaskTap: (task) => _editTask(context, model, task),
                onTaskDismissed: (task) =>
                    _deleteTask(context, model, task),
              ),
            ),
            UnscheduledSection(
              tasks: floatingTasks,
              onTap: (task) => _editTask(context, model, task),
              onDismissed: (task) => _deleteTask(context, model, task),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTask(context, model),
        tooltip: 'Add task',
        child: const Icon(Icons.add),
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────

  Future<void> _addTask(BuildContext context, dynamic model) async {
    final task = await TaskBottomSheet.show(
      context,
      date: model.viewedDate,
    );
    if (task == null || !context.mounted) return;

    try {
      model.addTask(task);
    } on ArgumentError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message.toString())),
      );
    }
  }

  Future<void> _editTask(
    BuildContext context,
    dynamic model,
    Task task,
  ) async {
    final updated = await TaskBottomSheet.show(
      context,
      date: model.viewedDate,
      existingTask: task,
    );
    if (updated == null || !context.mounted) return;

    try {
      model.updateTask(task.id, updated);
    } on ArgumentError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message.toString())),
      );
    }
  }

  void _deleteTask(BuildContext context, dynamic model, Task task) {
    model.removeTask(task.id);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${task.title}" deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => model.addTask(task),
        ),
      ),
    );
  }
}
