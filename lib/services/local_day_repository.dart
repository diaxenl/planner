import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/task.dart';
import 'day_repository.dart';

/// Stores each day's tasks as a JSON file under
/// `<documents>/hyperday/YYYY-MM-DD.json`.
///
/// **Atomic writes** — data is first written to a `.tmp` file, then
/// renamed over the real file so a crash mid-write cannot corrupt saved data.
///
/// **Corrupt file handling** — if the file cannot be parsed, it is renamed
/// to `YYYY-MM-DD.corrupt` and an empty list is returned.
class LocalDayRepository implements DayRepository {
  static const _subdirectory = 'hyperday';

  // ── DayRepository ────────────────────────────────────────────────────

  @override
  Future<List<Task>> load(DateTime date) async {
    final file = await _fileForDate(date);
    if (!file.existsSync()) return [];

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return _handleCorrupt(file, date);

      final tasks = <Task>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final task = Task.fromJson(item);
        if (task != null) tasks.add(task);
      }
      return tasks;
    } catch (_) {
      return _handleCorrupt(file, date);
    }
  }

  @override
  Future<void> save(DateTime date, List<Task> tasks) async {
    final file = await _fileForDate(date);
    final tmp = File('${file.path}.tmp');

    // Write to .tmp first, then atomically rename.
    await tmp.writeAsString(
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
    await tmp.rename(file.path);
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  Future<File> _fileForDate(DateTime date) async {
    final dir = await _storageDir();
    final name = _dateKey(date);
    return File('${dir.path}${Platform.pathSeparator}$name.json');
  }

  Future<Directory> _storageDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}$_subdirectory',
    );
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Renames [file] to `<stem>.corrupt` and returns an empty list.
  List<Task> _handleCorrupt(File file, DateTime date) {
    try {
      final corruptPath = file.path.replaceAll(
        '${_dateKey(date)}.json',
        '${_dateKey(date)}.corrupt',
      );
      file.renameSync(corruptPath);
    } catch (_) {
      // Best-effort rename; ignore errors.
    }
    return [];
  }

  /// Formats a [DateTime] as `YYYY-MM-DD` for use as a file name key.
  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
