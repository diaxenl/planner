import '../models/task.dart';

/// Abstract interface for reading and writing tasks for a specific day.
///
/// Implementations handle the underlying storage medium (local file,
/// in-memory, etc.). The key for each day is the calendar date — time
/// components are ignored.
abstract class DayRepository {
  /// Loads the task list for the given [date].
  ///
  /// Returns an empty list if no data exists yet.
  /// Corrupt or unreadable data is handled gracefully by the
  /// implementation (returns empty list).
  Future<List<Task>> load(DateTime date);

  /// Persists [tasks] for the given [date], overwriting any existing data.
  Future<void> save(DateTime date, List<Task> tasks);
}
