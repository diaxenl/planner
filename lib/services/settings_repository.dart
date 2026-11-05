import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/settings.dart';

/// Abstract interface for persisting [Settings].
abstract class SettingsRepository {
  /// Returns saved settings, or defaults if none are saved or readable.
  Future<Settings> load();

  /// Persists [settings].
  Future<void> save(Settings settings);
}

/// Stores settings as `<documents>/hyperday/settings.json`, written
/// atomically (`.tmp` then rename) like [LocalDayRepository].
class LocalSettingsRepository implements SettingsRepository {
  static const _subdirectory = 'hyperday';

  @override
  Future<Settings> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return const Settings();
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return const Settings();
      return Settings.fromJson(decoded);
    } catch (_) {
      return const Settings();
    }
  }

  @override
  Future<void> save(Settings settings) async {
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(settings.toJson()));
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
    return File('${dir.path}${Platform.pathSeparator}settings.json');
  }
}
