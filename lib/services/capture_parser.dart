import 'package:flutter/material.dart';

import '../models/task.dart';

/// What [CaptureParser.parse] could read from a line of free text.
/// Unparsed fields are `null` / `false`; callers apply defaults.
class ParsedCapture {
  const ParsedCapture({
    required this.title,
    this.durationMinutes,
    this.startTime,
    this.date,
    this.isOutcome = false,
    this.priority,
  });

  final String title;
  final int? durationMinutes;
  final TimeOfDay? startTime;

  /// The day named in the text ("today", "tomorrow", "Friday"), or `null`.
  final DateTime? date;
  final bool isOutcome;

  /// `!` → High, `!low` → Low; `null` when not given.
  final TaskPriority? priority;
}

/// Pure, stateless parser for capture-bar shorthand, e.g.
/// `Call Bob 20m 3pm Friday *` → title "Call Bob", 20 min, 3:00 PM on
/// the coming Friday, Outcome.
///
/// Recognized whole-word tokens (first of each kind wins, case-insensitive):
/// - Duration, anywhere: `30m`, `30min`, `1h`, `1h30m`, `1.5h`
/// - Time: `3pm`, `3:30pm`, `15:00`, `3:30`; and a bare hour (`3`) only
///   right after `at`. A time counts only right after `at`/`@`, or in the
///   run of shorthand that ends the text — so "Email team re 2pm meeting"
///   keeps "2pm" in its title. Without am/pm, `1`–`12` is read as the one
///   that falls in the workday (else 1–6 → PM, 7–11 → AM).
/// - Day: `today`, `tomorrow`, or a weekday name (`Friday`, the next one,
///   today included), only right after `on` or in the closing run.
/// - Outcome: `*` as its own word, or at the very start or end of the text.
/// - Priority: `!` (High) or `!low` (Low), as their own words.
///
/// Plain words are read too: `2 hours`, `10 minutes`, `an hour`,
/// `half an hour` (a filler right before them, such as "about",
/// "probably" or "for", is dropped); `noon`; `after work` (the end of the
/// workday). A time right after `by` / `before` / `until` / `due` is a
/// deadline, which HyperDay doesn't plan around, so it stays in the title.
/// The `at` / `on` before a time or day is dropped. Everything else, in
/// order, is the title. Never validates ranges — that is the model's job.
class CaptureParser {
  CaptureParser._();

  static final _hm = RegExp(r'^(\d{1,2})h(\d{1,2})m(in)?$');
  static final _h = RegExp(r'^(\d{1,2}(?:\.\d+)?)h(rs?)?$');
  static final _m = RegExp(r'^(\d{1,3})m(in)?$');
  static final _ampm = RegExp(r'^(\d{1,2})(?::(\d{2}))?(am|pm)$');
  static final _clock = RegExp(r'^(\d{1,2}):(\d{2})$');
  static final _bareHour = RegExp(r'^(\d{1,2})$');

  static const _weekdays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  /// Parses [input]. [today] resolves day words (defaults to now);
  /// [workdayStartHour]–[workdayEndHour] resolve times without am/pm.
  static ParsedCapture parse(
    String input, {
    DateTime? today,
    int workdayStartHour = 8,
    int workdayEndHour = 18,
  }) {
    final trimmed = input.trim();
    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // ── Outcome star ────────────────────────────────────────────────
    var isOutcome = false;
    words.removeWhere((w) {
      final star = RegExp(r'^\*+$').hasMatch(w);
      if (star) isOutcome = true;
      return star;
    });
    if (words.isNotEmpty && words.first.startsWith('*')) {
      isOutcome = true;
      words[0] = words.first.replaceFirst(RegExp(r'^\*+'), '');
    }
    if (words.isNotEmpty && words.last.endsWith('*')) {
      isOutcome = true;
      words[words.length - 1] = words.last.replaceFirst(RegExp(r'\*+$'), '');
    }
    words.removeWhere((w) => w.isEmpty);

    // ── Priority ────────────────────────────────────────────────────
    TaskPriority? priority;
    words.removeWhere((w) {
      final l = w.toLowerCase();
      if (l == '!' || l == '!high') {
        priority = TaskPriority.high;
        return true;
      }
      if (l == '!low') {
        priority = TaskPriority.low;
        return true;
      }
      return false;
    });

    _normalizePhrases(words, workdayEndHour);

    final lower = [for (final w in words) _bare(w.toLowerCase())];
    final day = today ?? DateTime.now();

    // A bare hour ("at 3") only counts in the closing run (see below), so
    // "Look at 3 options" stays a title.
    TimeOfDay? timeAt(int i, {bool bare = true}) {
      if (i > 0 && _deadlineWords.contains(lower[i - 1])) return null;
      return _time(
        lower[i],
        allowBare: bare && i > 0 && _isAt(lower[i - 1]),
        startHour: workdayStartHour,
        endHour: workdayEndHour,
      );
    }

    // ── The closing run of shorthand ────────────────────────────────
    var tailStart = words.length;
    for (var i = words.length - 1; i >= 0; i--) {
      final w = lower[i];
      final meta =
          _duration(w) != null ||
          timeAt(i) != null ||
          _day(w, day) != null ||
          _isAt(w) ||
          w == 'on';
      if (!meta) break;
      tailStart = i;
    }

    int? duration;
    TimeOfDay? time;
    DateTime? date;
    final title = <String>[];

    for (var i = 0; i < words.length; i++) {
      final w = lower[i];
      final inTail = i >= tailStart;
      final afterAt = i > 0 && _isAt(lower[i - 1]);
      final afterOn = i > 0 && lower[i - 1] == 'on';

      if (duration == null) {
        final d = _duration(w);
        if (d != null) {
          duration = d;
          if (title.isNotEmpty &&
              _fillers.contains(_bare(title.last.toLowerCase()))) {
            title.removeLast();
          }
          continue;
        }
      }
      if (time == null && (inTail || afterAt)) {
        final t = timeAt(i, bare: inTail);
        if (t != null) {
          time = t;
          if (afterAt && title.isNotEmpty) title.removeLast();
          continue;
        }
      }
      if (date == null && (inTail || afterOn)) {
        final d = _day(w, day);
        if (d != null) {
          date = d;
          if (afterOn && title.isNotEmpty) title.removeLast();
          continue;
        }
      }
      title.add(words[i]);
    }

    return ParsedCapture(
      // "Prep slides, 2h" → "Prep slides", not "Prep slides,".
      title: title.join(' ').replaceFirst(RegExp(r'[\s,;:–-]+$'), ''),
      durationMinutes: duration,
      startTime: time,
      date: date,
      isOutcome: isOutcome,
      priority: priority,
    );
  }

  static const _hourWords = {'hour', 'hours', 'hr', 'hrs'};
  static const _minuteWords = {'minute', 'minutes', 'min', 'mins'};
  static const _fillers = {
    'about',
    'around',
    'roughly',
    'approx',
    'approximately',
    'probably',
    'maybe',
    'for',
    '~',
  };
  static const _deadlineWords = {'by', 'before', 'until', 'till', 'due'};

  /// Rewrites plain-word phrases in [words] as shorthand, in place:
  /// "2 hours" → `120m`, "an hour" → `60m`, "half an hour" → `30m`,
  /// "10 minutes" → `10m`, "after work" → `at` + the workday's end.
  static void _normalizePhrases(List<String> words, int workdayEndHour) {
    String at(int i) => i < words.length ? _bare(words[i].toLowerCase()) : '';
    for (var i = 0; i < words.length; i++) {
      final w = at(i), next = at(i + 1);
      if (w == 'half' &&
          (next == 'an' || next == 'a') &&
          _hourWords.contains(at(i + 2))) {
        words.replaceRange(i, i + 3, ['30m']);
        continue;
      }
      final n = (w == 'a' || w == 'an' || w == 'one')
          ? 1.0
          : double.tryParse(w);
      if (n != null && n > 0) {
        if (_hourWords.contains(next)) {
          words.replaceRange(i, i + 2, ['${(n * 60).round()}m']);
          continue;
        }
        if (_minuteWords.contains(next) && n == n.roundToDouble()) {
          words.replaceRange(i, i + 2, ['${n.round()}m']);
          continue;
        }
      }
      if (w == 'after' && next == 'work' && workdayEndHour < 24) {
        words.replaceRange(i, i + 2, ['at', '$workdayEndHour:00']);
      }
    }
    // Hours then minutes, as two words ("1h 30m", "1 hour 30 minutes"):
    // one length.
    for (var i = 0; i + 1 < words.length; i++) {
      final h = _hourTokenMinutes(at(i));
      final m = _m.firstMatch(at(i + 1));
      if (h != null && m != null && int.parse(m.group(1)!) < 60) {
        words.replaceRange(i, i + 2, ['${h + int.parse(m.group(1)!)}m']);
      }
    }
  }

  /// Minutes in a whole-hour token: `1h`, `2hrs`, or the `60m`/`120m`
  /// that "an hour" / "2 hours" became. Otherwise `null`.
  static int? _hourTokenMinutes(String w) {
    final h = _h.firstMatch(w);
    if (h != null) {
      final n = double.parse(h.group(1)!);
      return n == n.roundToDouble() ? (n * 60).round() : null;
    }
    final m = _m.firstMatch(w);
    if (m == null) return null;
    final n = int.parse(m.group(1)!);
    return n >= 60 && n % 60 == 0 ? n : null;
  }

  static bool _isAt(String w) => w == 'at' || w == '@';

  /// [w] without trailing punctuation ("friday," → "friday").
  static String _bare(String w) => w.replaceFirst(RegExp(r'[,.;!?]+$'), '');

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

  static TimeOfDay? _time(
    String w, {
    required bool allowBare,
    required int startHour,
    required int endHour,
  }) {
    if (w == 'noon' || w == 'midday') {
      return const TimeOfDay(hour: 12, minute: 0);
    }
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
      // "3:30" means the afternoon; "03:30" and "15:30" are 24-hour.
      if (h >= 1 && h <= 12 && !c.group(1)!.startsWith('0')) {
        return _inWorkday(h, m, startHour, endHour);
      }
      return TimeOfDay(hour: h, minute: m);
    }
    if (allowBare) {
      final b = _bareHour.firstMatch(w);
      if (b != null) {
        final h = int.parse(b.group(1)!);
        if (h < 1 || h > 12) return null;
        return _inWorkday(h, 0, startHour, endHour);
      }
    }
    return null;
  }

  /// [h]:[m] (1–12, no am/pm) as AM or PM — whichever falls in the
  /// workday; if both or neither do, 1–6 is PM and 7–12 as usual (12 is
  /// noon).
  static TimeOfDay _inWorkday(int h, int m, int startHour, int endHour) {
    final am = h % 12;
    final pm = am + 12;
    bool inDay(int hour) {
      final minutes = hour * 60 + m;
      return minutes >= startHour * 60 && minutes < endHour * 60;
    }

    final amFits = inDay(am), pmFits = inDay(pm);
    final int hour;
    if (amFits != pmFits) {
      hour = amFits ? am : pm;
    } else if (h == 12) {
      hour = 12;
    } else {
      hour = h <= 6 ? pm : am;
    }
    return TimeOfDay(hour: hour, minute: m);
  }

  /// The date [w] names, relative to [today], or `null`.
  static DateTime? _day(String w, DateTime today) {
    final base = DateTime(today.year, today.month, today.day);
    if (w == 'today') return base;
    if (w == 'tomorrow') return DateTime(base.year, base.month, base.day + 1);
    final index = _weekdays.indexOf(w);
    if (index == -1) return null;
    final ahead = (index + 1 - base.weekday) % 7;
    return DateTime(base.year, base.month, base.day + ahead);
  }
}
