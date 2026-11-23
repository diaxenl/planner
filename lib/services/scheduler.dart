import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/day_schedule.dart';
import '../models/scheduled_task.dart';
import '../models/task.dart';

/// Pure, side-effect-free scheduling engine.
///
/// Given a list of tasks and a day window, produces a [DaySchedule]
/// that places all hard/pinned tasks at their fixed positions and
/// fills the free time between them with floating tasks. Order of
/// importance: "Do next" work (latest choice first); then Outcomes, in the
/// order they are listed; then other work by priority (High, Normal, Low),
/// the one added first winning within each.
///
/// "Do next" work takes the earliest free time. The rest fills the day so
/// no free time is left that some task could use: short tasks fill the
/// short gaps, long work gets the long gaps, short tasks are never split
/// and nothing is split into sessions under
/// [AppConstants.minSessionMinutes] (see step 5). An Outcome that doesn't
/// fully fit is planned in part. A set-time item that was finished early
/// frees the rest of its slot, and one marked "Won't do" frees all of it.
class Scheduler {
  Scheduler._();

  /// Computes a [DaySchedule] from [tasks] within [dayStartHour] to
  /// [dayEndHour].
  ///
  /// [nowMinutes] is the current time in minutes from midnight. Floating
  /// tasks will only be placed into gaps that start at or after this time.
  /// If `null`, the full day window is used (useful for testing).
  ///
  /// This is a pure function — no side effects, no state mutation.
  static DaySchedule schedule(
    List<Task> tasks, {
    required int dayStartHour,
    required int dayEndHour,
    int? nowMinutes,
  }) {
    final dayStartMin = dayStartHour * 60;
    final dayEndMin = dayEndHour * 60;
    final effectiveNow = nowMinutes ?? dayStartMin;

    // Resolves the anchor start time for a fixed-block task: its own
    // `startTime` (hard/pinned), or — for an in-progress floating task
    // that has no fixed `startTime` — the moment it was actually started.
    // Falls back to "now" if neither is available (shouldn't normally
    // happen, but keeps the scheduler total).
    TimeOfDay anchorFor(Task t) {
      if (t.startTime != null) return t.startTime!;
      if (t.startedAt != null) return TimeOfDay.fromDateTime(t.startedAt!);
      return TimeOfDay(hour: effectiveNow ~/ 60, minute: effectiveNow % 60);
    }

    // Effective duration used to block time for downstream gap
    // computation. Normally the task's own estimate, but for a task
    // that is `inProgress` and has run longer than its estimate (an
    // overrun), the elapsed real time since `startedAt` is used instead
    // so the rest of the day reflects reality rather than the stale
    // estimate. Minutes tracked on earlier, paused runs are already done,
    // so only what is left is blocked.
    int effectiveDurationFor(Task t) {
      if (t.status == TaskStatus.inProgress && t.startedAt != null) {
        final startedMin = t.startedAt!.hour * 60 + t.startedAt!.minute;
        final elapsed = effectiveNow - startedMin;
        final left = t.remainingMinutes;
        return elapsed > left ? elapsed : left;
      }
      return t.durationMinutes;
    }

    // ── 1. Separate fixed and floating tasks ──────────────────────────
    final fixedTasks = <Task>[];
    final floatingTasks = <Task>[];

    for (final task in tasks) {
      // Completed/cancelled tasks are a frozen historical record: if they
      // have a fixed slot (hard/pinned) they stay on the timeline there,
      // but only block time until they were finished (see step 2);
      // otherwise they are excluded rather than being (re-)placed by the
      // greedy floating fill.
      if (task.status == TaskStatus.complete ||
          task.status == TaskStatus.cancelled) {
        if (task.startTime != null) fixedTasks.add(task);
        continue;
      }

      // An in-progress task is never displaced — it occupies a fixed
      // block anchored at the time it was actually started.
      if (task.status == TaskStatus.inProgress) {
        fixedTasks.add(task);
        continue;
      }

      if (task.type == TaskType.floating && task.startTime == null) {
        floatingTasks.add(task);
      } else if (task.startTime != null) {
        fixedTasks.add(task);
      }
    }

    // ── 2. Build fixed blocks sorted by start time ────────────────────
    final fixedBlocks = fixedTasks.map((t) {
      final startMin = anchorFor(t).hour * 60 + anchorFor(t).minute;
      return _Block(
        task: t,
        startMin: startMin,
        endMin: startMin + effectiveDurationFor(t),
      );
    }).toList()..sort((a, b) => a.startMin.compareTo(b.startMin));

    // Time a block keeps from floating work: all of it, except a finished
    // item (only until it was finished) and a "Won't do" one (none).
    // Fixed blocks that keep no time are still drawn, but open up their
    // slot to the floating fill.
    for (final b in fixedBlocks) {
      final t = b.task;
      if (t.status == TaskStatus.cancelled) {
        b.freedFrom = b.startMin;
      } else if (t.status == TaskStatus.complete && t.completedAt != null) {
        final done = t.completedAt!;
        final sameDay =
            done.year == t.date.year &&
            done.month == t.date.month &&
            done.day == t.date.day;
        if (sameDay || done.isBefore(t.date)) {
          final doneMin = sameDay ? done.hour * 60 + done.minute : 0;
          if (doneMin < b.endMin) b.freedFrom = doneMin;
        }
      }
    }
    final blocking = [
      for (final b in fixedBlocks)
        if (b.blockEndMin > b.startMin) b,
    ];

    // A running floating Outcome stops at the next fixed block (or now,
    // if it has run into it); what's left is planned as later sessions.
    final remainders = <_Work>[];
    for (final b in fixedBlocks) {
      final t = b.task;
      if (t.status != TaskStatus.inProgress ||
          !t.isOutcome ||
          t.startTime != null) {
        continue;
      }
      final planned = b.startMin + t.remainingMinutes;
      int? nextStart;
      for (final other in blocking) {
        if (identical(other, b)) continue;
        if (other.startMin > b.startMin &&
            other.startMin < planned &&
            (nextStart == null || other.startMin < nextStart)) {
          nextStart = other.startMin;
        }
      }
      if (nextStart == null) continue;
      final end = nextStart > effectiveNow ? nextStart : effectiveNow;
      if (end >= planned) continue;
      b.endMin = end;
      remainders.add(_Work(t, planned - end, isRemainder: true));
    }

    // Start committed list with all fixed tasks.
    final committed = <ScheduledTask>[
      for (final b in fixedBlocks)
        ScheduledTask(
          task: b.task,
          computedStartTime: anchorFor(b.task),
          durationMinutes: b.task.status == TaskStatus.inProgress
              ? b.endMin - b.startMin
              : null,
        ),
    ];

    // ── 3. Compute free gaps ──────────────────────────────────────────
    // Gaps lie inside the day window only; fixed blocks outside it (an
    // early call, an evening event) are kept but never open up space.
    // Only blocks that keep their time split the day into gaps.
    final gaps = <_Gap>[];
    var cursor = dayStartMin;

    for (final block in blocking) {
      final gapEnd = block.startMin < dayEndMin ? block.startMin : dayEndMin;
      if (gapEnd > cursor) {
        gaps.add(_Gap(startMin: cursor, endMin: gapEnd));
      }
      if (block.blockEndMin > cursor) cursor = block.blockEndMin;
    }
    // Gap after the last fixed block.
    if (cursor < dayEndMin) {
      gaps.add(_Gap(startMin: cursor, endMin: dayEndMin));
    }

    // ── 4. Sort floating tasks ─────────────────────────────────────────
    // "Do next" first, latest choice first; then Outcomes in list order
    // (the first one is the most important); then other work by priority
    // (High, Normal, Low). Ties keep input order — the item added first
    // wins (List.sort is not stable, so compare positions).
    final position = {
      for (var i = 0; i < floatingTasks.length; i++) floatingTasks[i].id: i,
    };
    floatingTasks.sort((a, b) {
      final an = a.doNextAt, bn = b.doNextAt;
      if ((an != null) != (bn != null)) return an != null ? -1 : 1;
      if (an != null && bn != null && an != bn) return bn.compareTo(an);
      if (a.isOutcome != b.isOutcome) return a.isOutcome ? -1 : 1;
      if (a.isOutcome || an != null) {
        return position[a.id]!.compareTo(position[b.id]!);
      }
      final byPriority = a.priority.index.compareTo(b.priority.index);
      if (byPriority != 0) return byPriority;
      return position[a.id]!.compareTo(position[b.id]!);
    });

    // ── 5. Fill the free time ─────────────────────────────────────────
    // Short tasks fill the short gaps, long work gets the long gaps, and
    // nothing is cut into pieces under [AppConstants.minSessionMinutes]:
    //  a. "Do next" work (and what's left of a running Outcome) first, at
    //     the earliest free time.
    //  b. Admission: the rest, in order, while it fits the free time left;
    //     what doesn't fit is skipped so smaller work further down still
    //     gets a chance. An Outcome that doesn't fully fit gets what's
    //     left (planned in part; the rest is reported as not fitting).
    //  c. Gaps shorter than [AppConstants.smallGapMinutes] get the
    //     combination of short tasks that fills them most (except the
    //     first free time when the most important work is long).
    //  d. Outcomes and long work, in order: whole in the earliest gap that
    //     holds it; else split, first session as early as possible, the
    //     rest in the longest gaps.
    //  e. Short tasks left over: the tightest gap they fit.
    // Short tasks (up to [AppConstants.noSplitMaxMinutes]) are never split.
    final overflow = <Task>[];
    final unplanned = <String, int>{};
    final sessions = <String, List<ScheduledTask>>{};

    // Free time from now on only.
    gaps.removeWhere((g) => g.endMin <= effectiveNow);
    for (final g in gaps) {
      if (g.startMin < effectiveNow) g.startMin = effectiveNow;
    }

    void place(_Work work, _Gap gap, int minutes) {
      final start = gap.startMin;
      final st = ScheduledTask(
        task: work.task,
        computedStartTime: TimeOfDay(hour: start ~/ 60, minute: start % 60),
        durationMinutes: minutes == work.task.durationMinutes ? null : minutes,
      );
      committed.add(st);
      sessions.putIfAbsent(work.task.id, () => []).add(st);
      gap.startMin = start + minutes;
    }

    // Reports [work] as not fitting: all of it, or the [left] minutes of
    // it that didn't. What's left of a running Outcome is never reported.
    void notFitting(_Work work, int left) {
      if (work.isRemainder) return;
      if (!sessions.containsKey(work.task.id)) {
        unplanned.remove(work.task.id);
        overflow.add(work.task);
      } else {
        unplanned[work.task.id] = (unplanned[work.task.id] ?? 0) + left;
      }
    }

    // a. "Do next" and what's left of a running Outcome: earliest time.
    final rest = <_Work>[];
    for (final work in [
      ...remainders,
      for (final t in floatingTasks) _Work(t, t.remainingMinutes),
    ]) {
      if (!work.isRemainder && work.task.doNextAt == null) {
        rest.add(work);
        continue;
      }
      final left = _placeEarliest(gaps, work, place);
      if (left > 0) notFitting(work, left);
    }

    // b. Admission.
    var free = gaps.fold<int>(0, (sum, g) => sum + g.length);
    final admitted = <_Work>[];
    for (final work in rest) {
      if (work.minutes <= free) {
        admitted.add(work);
        free -= work.minutes;
      } else if (work.task.isOutcome &&
          work.minutes > AppConstants.noSplitMaxMinutes &&
          free >= AppConstants.minSessionMinutes) {
        // In part: what's left of the day.
        admitted.add(_Work(work.task, free));
        unplanned[work.task.id] = work.minutes - free;
        free = 0;
      } else {
        overflow.add(work.task);
      }
    }
    final rank = {for (var i = 0; i < admitted.length; i++) admitted[i]: i};
    bool isShort(_Work w) => w.minutes <= AppConstants.noSplitMaxMinutes;

    // c. Small gaps: the best-filling combination of short tasks. The
    // first free time is kept for the most important work when that is
    // long (it starts there, see d).
    final shortLeft = [
      for (final w in admitted)
        if (isShort(w)) w,
    ];
    final kept = admitted.isNotEmpty && !isShort(admitted.first)
        ? gaps
              .where((g) => g.length >= AppConstants.minSessionMinutes)
              .firstOrNull
        : null;
    for (final gap in gaps) {
      if (gap.length >= AppConstants.smallGapMinutes) continue;
      if (identical(gap, kept)) continue;
      for (final w in _bestFill(gap.length, shortLeft, rank)) {
        place(w, gap, w.minutes);
        shortLeft.remove(w);
      }
    }

    // d. Outcomes not placed yet, and long work, in order.
    for (var work in admitted) {
      final waiting = shortLeft.contains(work);
      if (isShort(work) && !(work.task.isOutcome && waiting)) continue;
      shortLeft.remove(work);
      // The most important work starts in the first free time.
      if (kept != null && identical(work, admitted.first)) {
        final take = _take(kept.length, work.minutes);
        if (take > 0) place(work, kept, take);
        if (take == work.minutes) continue;
        work = _Work(work.task, work.minutes - take);
      }
      final whole = gaps.where((g) => g.length >= work.minutes).firstOrNull;
      if (whole != null) {
        place(work, whole, work.minutes);
        continue;
      }
      if (isShort(work)) {
        notFitting(work, work.minutes);
        continue;
      }
      final plan = _splitPlan(gaps, work.minutes);
      final planned = plan.fold<int>(0, (sum, p) => sum + p.$2);
      // Only an Outcome is planned in part.
      if (planned < work.minutes && !work.task.isOutcome) {
        overflow.add(work.task);
        continue;
      }
      for (final (gap, minutes) in plan) {
        place(work, gap, minutes);
      }
      if (planned < work.minutes) notFitting(work, work.minutes - planned);
    }

    // e. Short tasks left over: the tightest gap they fit.
    for (final work in shortLeft) {
      _Gap? pick;
      for (final g in gaps) {
        if (g.length >= work.minutes &&
            (pick == null || g.length < pick.length)) {
          pick = g;
        }
      }
      if (pick == null) {
        overflow.add(work.task);
      } else {
        place(work, pick, work.minutes);
      }
    }

    // Number the sessions of every task that ended up in more than one
    // piece (a running Outcome's own block counts as its first session).
    final pieces = <String, List<ScheduledTask>>{};
    for (final st in committed) {
      if (st.task.status == TaskStatus.inProgress ||
          sessions.containsKey(st.task.id)) {
        pieces.putIfAbsent(st.task.id, () => []).add(st);
      }
    }
    for (final list in pieces.values) {
      if (list.length < 2) continue;
      list.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      for (var i = 0; i < list.length; i++) {
        final old = list[i];
        committed[committed.indexOf(old)] = ScheduledTask(
          task: old.task,
          computedStartTime: old.computedStartTime,
          durationMinutes: old.durationMinutes,
          part: i + 1,
          parts: list.length,
        );
      }
    }

    // Sort committed by start time for consistent rendering.
    committed.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    return DaySchedule(
      committed: committed,
      overflow: overflow,
      unplanned: unplanned,
    );
  }

  /// Places [work] at the earliest free time: whole in the first gap
  /// that holds it if that's the first usable gap; else (if it's long) in
  /// sessions of at least [AppConstants.minSessionMinutes] running on into
  /// the next gaps; a short task takes the first gap that holds it.
  /// Returns the minutes that didn't fit.
  static int _placeEarliest(
    List<_Gap> gaps,
    _Work work,
    void Function(_Work, _Gap, int) place,
  ) {
    final whole = gaps.where((g) => g.length >= work.minutes).firstOrNull;
    final first = gaps
        .where((g) => g.length >= AppConstants.minSessionMinutes)
        .firstOrNull;
    if (whole != null &&
        (work.minutes <= AppConstants.noSplitMaxMinutes ||
            identical(whole, first))) {
      place(work, whole, work.minutes);
      return 0;
    }
    if (work.minutes <= AppConstants.noSplitMaxMinutes) return work.minutes;
    var left = work.minutes;
    for (final gap in gaps) {
      final take = _take(gap.length, left);
      if (take == 0) continue;
      place(work, gap, take);
      left -= take;
      if (left == 0) break;
    }
    return left;
  }

  /// How much of [left] minutes to put in a gap of [available] minutes:
  /// as much as fits, but no session (and no rest) shorter than
  /// [AppConstants.minSessionMinutes]. 0 if no session fits.
  static int _take(int available, int left) {
    const minPart = AppConstants.minSessionMinutes;
    if (available < minPart) return 0;
    var take = available < left ? available : left;
    if (left - take > 0 && left - take < minPart) take = left - minPart;
    return take < minPart ? 0 : take;
  }

  /// Splits [minutes] over [gaps]: the first session in the earliest gap
  /// that takes one, the rest in the longest gaps (earliest first among
  /// equals). Returns `(gap, minutes)` per session, possibly short of
  /// [minutes]. Gaps are not changed.
  static List<(_Gap, int)> _splitPlan(List<_Gap> gaps, int minutes) {
    final usable = [
      for (final g in gaps)
        if (g.length >= AppConstants.minSessionMinutes) g,
    ];
    if (usable.isEmpty) return const [];
    final later = usable.skip(1).toList()
      ..sort((a, b) {
        final byLength = b.length.compareTo(a.length);
        return byLength != 0 ? byLength : a.startMin.compareTo(b.startMin);
      });
    final plan = <(_Gap, int)>[];
    var left = minutes;
    for (final gap in [usable.first, ...later]) {
      final take = _take(gap.length, left);
      if (take == 0) continue;
      plan.add((gap, take));
      left -= take;
      if (left == 0) break;
    }
    return plan;
  }

  /// The short tasks from [candidates] that together fill [length] minutes
  /// the most; among equal fills, the more important ones (lower [rank]).
  /// Returned most important first.
  static List<_Work> _bestFill(
    int length,
    List<_Work> candidates,
    Map<_Work, int> rank,
  ) {
    var best = <_Work>[];
    var bestFill = 0;
    var bestRank = 0;
    final pick = <_Work>[];
    void search(int from, int fill, int rankSum) {
      if (fill > bestFill || (fill == bestFill && rankSum < bestRank)) {
        best = List.of(pick);
        bestFill = fill;
        bestRank = rankSum;
      }
      for (var i = from; i < candidates.length; i++) {
        final w = candidates[i];
        if (fill + w.minutes > length) continue;
        pick.add(w);
        search(i + 1, fill + w.minutes, rankSum + rank[w]!);
        pick.removeLast();
      }
    }

    search(0, 0, 0);
    best.sort((a, b) => rank[a]!.compareTo(rank[b]!));
    return best;
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────

/// A fixed time block on the timeline.
class _Block {
  _Block({required this.task, required this.startMin, required this.endMin});

  final Task task;
  final int startMin;
  int endMin;

  /// Set for an item finished early or marked "Won't do": where it stops
  /// keeping time from floating work.
  int? freedFrom;

  /// Where the block stops keeping time from floating work.
  int get blockEndMin => freedFrom ?? endMin;
}

/// A free gap between fixed blocks.
class _Gap {
  _Gap({required this.startMin, required this.endMin});

  int startMin;
  final int endMin;

  int get length => endMin - startMin;
}

/// Floating work waiting to be placed: a task and the minutes to plan.
class _Work {
  _Work(this.task, this.minutes, {this.isRemainder = false});

  final Task task;
  final int minutes;

  /// What's left of a running Outcome, cut at the next fixed block.
  final bool isRemainder;
}
