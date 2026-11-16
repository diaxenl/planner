import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/recurring_task.dart';

/// Abstract interface for persisting repeating series.
abstract class RecurringRepository {
  /// Returns every saved series; an empty list if none or unreadable.
  Future<List<RecurringTask>> load();

  /// Replaces all saved series with [series].
  Future<void> save(List<RecurringTask> series);
}

/// Stores series as `<documents>/hyperday/recurring.json`, written
/// atomically (`.tmp` then rename) like the day files.
class LocalRecurringRepository implements RecurringRepository {
  static const _subdirectory = 'hyperday';

  @override
  Future<List<RecurringTask>> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>) ?RecurringTask.fromJson(item),
      ];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> save(List<RecurringTask> series) async {
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode([for (final s in series) s.toJson()]));
    await tmp.rename(file.path);
  }

  Future<File> _file() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}$_subdirectory',
    );
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}recurring.json');
  }
}
