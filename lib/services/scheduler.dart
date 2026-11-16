import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/day_schedule.dart';
import '../models/scheduled_task.dart';
import '../models/task.dart';

/// Pure, side-effect-free scheduling engine.
///
/// Given a list of tasks and a day window, produces a [DaySchedule]
/// that places all hard/pinned tasks at their fixed positions and
/// greedily fills remaining gaps with floating tasks — "Do next" work
/// first (latest choice first); then Outcomes, in the order they are
/// listed; then other work, shorter first.
///
/// An Outcome that doesn't fit any single gap is split into sessions of
/// at least [AppConstants.minSessionMinutes], earliest gaps first. Other
/// work is never split.
class Scheduler {
  Scheduler._();

  /// Computes a [DaySchedule] from [tasks] within [dayStartHour] to
  /// [dayEndHour].
  ///
  /// [nowMinutes] is the current time in minutes from midnight. Floating
  /// tasks will only be placed into gaps that start at or after this time.
  /// If `null`, the full day window is used (useful for testing).
  ///
  /// [bufferMinutes] of free time are kept after every fixed block and
  /// every placed item, and before every fixed block (not at the edges of
  /// the day window or at "now").
  ///
  /// This is a pure function — no side effects, no state mutation.
  static DaySchedule schedule(
    List<Task> tasks, {
    required int dayStartHour,
    required int dayEndHour,
    int? nowMinutes,
    int bufferMinutes = 0,
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
      // already occupy a fixed slot (hard/pinned), that slot stays
      // blocked; otherwise they are excluded rather than being (re-)
      // placed by the greedy floating fill.
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
      for (final other in fixedBlocks) {
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
      remainders.add(_Work(t, planned - end));
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
    // Breathing room is kept on each side of a fixed block.
    final gaps = <_Gap>[];
    var cursor = dayStartMin;
    var afterBlock = false;

    for (final block in fixedBlocks) {
      final gapStart = cursor + (afterBlock ? bufferMinutes : 0);
      final gapEnd = block.startMin < dayEndMin
          ? block.startMin - bufferMinutes
          : dayEndMin;
      if (gapEnd > gapStart) {
        gaps.add(_Gap(startMin: gapStart, endMin: gapEnd));
      }
      if (block.endMin > cursor) {
        cursor = block.endMin;
        afterBlock = true;
      }
    }
    // Gap after the last fixed block.
    final lastStart = cursor + (afterBlock ? bufferMinutes : 0);
    if (lastStart < dayEndMin) {
      gaps.add(_Gap(startMin: lastStart, endMin: dayEndMin));
    }

    // ── 4. Sort floating tasks ─────────────────────────────────────────
    // "Do next" first, latest choice first; then Outcomes in list order
    // (the first one is the most important); then other work, shorter
    // first. Ties keep input order (List.sort is not stable, so compare
    // positions).
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
      final byLength = a.durationMinutes.compareTo(b.durationMinutes);
      return byLength != 0
          ? byLength
          : position[a.id]!.compareTo(position[b.id]!);
    });

    // ── 5. Greedy slot-fill ───────────────────────────────────────────
    final overflow = <Task>[];
    final sessions = <String, List<ScheduledTask>>{};

    // Where [gap] can be used from: never before now.
    int usableStart(_Gap gap) =>
        gap.startMin < effectiveNow ? effectiveNow : gap.startMin;

    void place(_Work work, _Gap gap, int start, int minutes) {
      final st = ScheduledTask(
        task: work.task,
        computedStartTime: TimeOfDay(hour: start ~/ 60, minute: start % 60),
        durationMinutes: minutes == work.task.durationMinutes ? null : minutes,
      );
      committed.add(st);
      sessions.putIfAbsent(work.task.id, () => []).add(st);
      gap.startMin = start + minutes + bufferMinutes;
    }

    final queue = [
      ...remainders,
      for (final t in floatingTasks) _Work(t, t.remainingMinutes),
    ];

    for (final work in queue) {
      // Whole, in the first gap it fits.
      _Gap? whole;
      for (final gap in gaps) {
        if (gap.endMin <= effectiveNow) continue;
        if (gap.endMin - usableStart(gap) >= work.minutes) {
          whole = gap;
          break;
        }
      }
      if (whole != null) {
        place(work, whole, usableStart(whole), work.minutes);
        continue;
      }

      // An Outcome may be split across gaps, earliest first.
      final plan = work.task.isOutcome
          ? _split(gaps, work.minutes, usableStart, effectiveNow)
          : null;
      if (plan == null) {
        if (!remainders.contains(work)) overflow.add(work.task);
        continue;
      }
      for (final (gap, start, minutes) in plan) {
        place(work, gap, start, minutes);
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

    return DaySchedule(committed: committed, overflow: overflow);
  }

  /// Plans [minutes] of work across [gaps] in time order, in sessions of
  /// at least [AppConstants.minSessionMinutes] (or the whole thing, if
  /// less). Returns `(gap, start, minutes)` per session, or `null` if it
  /// doesn't fit. Gaps are not changed.
  static List<(_Gap, int, int)>? _split(
    List<_Gap> gaps,
    int minutes,
    int Function(_Gap) usableStart,
    int now,
  ) {
    final minPart = minutes < AppConstants.minSessionMinutes
        ? minutes
        : AppConstants.minSessionMinutes;
    final plan = <(_Gap, int, int)>[];
    var left = minutes;
    for (final gap in gaps) {
      if (gap.endMin <= now) continue;
      final start = usableStart(gap);
      final available = gap.endMin - start;
      if (available < minPart) continue;
      var take = available < left ? available : left;
      // Never leave a last piece shorter than a session.
      if (left - take > 0 && left - take < minPart) take = left - minPart;
      if (take < minPart) continue;
      plan.add((gap, start, take));
      left -= take;
      if (left == 0) return plan;
    }
    return null;
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────

/// A fixed time block on the timeline.
class _Block {
  _Block({required this.task, required this.startMin, required this.endMin});

  final Task task;
  final int startMin;
  int endMin;
}

/// A free gap between fixed blocks.
class _Gap {
  _Gap({required this.startMin, required this.endMin});

  int startMin;
  final int endMin;
}

/// Floating work waiting to be placed: a task and the minutes to plan.
class _Work {
  _Work(this.task, this.minutes);

  final Task task;
  final int minutes;
}
