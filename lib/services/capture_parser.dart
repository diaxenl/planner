import 'package:flutter/material.dart';

/// What [CaptureParser.parse] could read from a line of free text.
/// Unparsed fields are `null` / `false`; callers apply defaults.
class ParsedCapture {
  const ParsedCapture({
    required this.title,
    this.durationMinutes,
    this.startTime,
    this.isOutcome = false,
  });

  final String title;
  final int? durationMinutes;
  final TimeOfDay? startTime;
  final bool isOutcome;
}

/// Pure, stateless parser for capture-bar shorthand, e.g.
/// `Call Bob 20m 3pm *` → title "Call Bob", 20 min, 3:00 PM, Outcome.
///
/// Recognized whole-word tokens (first of each kind wins, case-insensitive):
/// - Duration: `30m`, `30min`, `1h`, `1h30m`, `1.5h`
/// - Time: `3pm`, `3:30pm`, `15:00`; a preceding `at` is dropped
/// - Outcome: `*` anywhere (alone or attached to a word)
/// Everything else, in order, is the title. Never validates ranges —
/// that is the confirmation sheet's job.
class CaptureParser {
  CaptureParser._();

  static final _hm = RegExp(r'^(\d{1,2})h(\d{1,2})m(in)?$');
  static final _h = RegExp(r'^(\d{1,2}(?:\.\d+)?)h(rs?)?$');
  static final _m = RegExp(r'^(\d{1,3})m(in)?$');
  static final _ampm = RegExp(r'^(\d{1,2})(?::(\d{2}))?(am|pm)$');
  static final _clock = RegExp(r'^(\d{1,2}):(\d{2})$');

  static ParsedCapture parse(String input) {
    final isOutcome = input.contains('*');
    final words = input
        .replaceAll('*', ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    int? duration;
    TimeOfDay? time;
    final title = <String>[];

    for (var i = 0; i < words.length; i++) {
      final w = words[i].toLowerCase();

      if (duration == null) {
        final d = _duration(w);
        if (d != null) {
          duration = d;
          continue;
        }
      }
      if (time == null) {
        final t = _time(w);
        if (t != null) {
          time = t;
          if (title.isNotEmpty && title.last.toLowerCase() == 'at') {
            title.removeLast();
          }
          continue;
        }
      }
      title.add(words[i]);
    }

    return ParsedCapture(
      title: title.join(' '),
      durationMinutes: duration,
      startTime: time,
      isOutcome: isOutcome,
    );
  }

  static int? _duration(String w) {
    final hm = _hm.firstMatch(w);
    if (hm != null) {
      return int.parse(hm.group(1)!) * 60 + int.parse(hm.group(2)!);
    }
    final h = _h.firstMatch(w);
    if (h != null) return (double.parse(h.group(1)!) * 60).round();
    final m = _m.firstMatch(w);
    if (m != null) return int.parse(m.group(1)!);
    return null;
  }

  static TimeOfDay? _time(String w) {
    final a = _ampm.firstMatch(w);
    if (a != null) {
      final h = int.parse(a.group(1)!);
      final m = int.parse(a.group(2) ?? '0');
      if (h < 1 || h > 12 || m > 59) return null;
      final pm = a.group(3) == 'pm';
      return TimeOfDay(hour: (h % 12) + (pm ? 12 : 0), minute: m);
    }
    final c = _clock.firstMatch(w);
    if (c != null) {
      final h = int.parse(c.group(1)!);
      final m = int.parse(c.group(2)!);
      if (h > 23 || m > 59) return null;
      return TimeOfDay(hour: h, minute: m);
    }
    return null;
  }
}
