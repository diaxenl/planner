import 'scheduled_task.dart';
import 'task.dart';

/// The output of the scheduling engine.
///
/// Contains all tasks that were successfully placed on the timeline
/// (with computed start times) and any floating tasks that could not
/// fit within the day window.
class DaySchedule {
  const DaySchedule({
    required this.committed,
    required this.overflow,
  });

  /// All placed tasks with their computed start time.
  /// Includes hard, pinned, and successfully-scheduled floating tasks.
  final List<ScheduledTask> committed;

  /// Floating tasks that could not be placed in any available gap.
  final List<Task> overflow;

  /// Empty schedule with no tasks.
  static const empty = DaySchedule(committed: [], overflow: []);
}
