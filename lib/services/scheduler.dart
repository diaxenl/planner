import 'package:flutter/material.dart';
import '../models/day_schedule.dart';
import '../models/scheduled_task.dart';
import '../models/task.dart';

/// Pure, side-effect-free scheduling engine.
///
/// Given a list of tasks and a day window, produces a [DaySchedule]
/// that places all hard/pinned tasks at their fixed positions and
/// greedily fills remaining gaps with floating tasks sorted by
/// priority (high → low) then duration (short → long).
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

    // ── 1. Separate fixed and floating tasks ──────────────────────────
    final fixedTasks = <Task>[];
    final floatingTasks = <Task>[];

    for (final task in tasks) {
      if (task.type == TaskType.floating && task.startTime == null) {
        floatingTasks.add(task);
      } else if (task.startTime != null) {
        fixedTasks.add(task);
      }
    }

    // ── 2. Build fixed blocks sorted by start time ────────────────────
    final fixedBlocks = fixedTasks.map((t) {
      final startMin = t.startTime!.hour * 60 + t.startTime!.minute;
      return _Block(task: t, startMin: startMin, endMin: startMin + t.durationMinutes);
    }).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    // Start committed list with all fixed tasks.
    final committed = <ScheduledTask>[
      for (final b in fixedBlocks)
        ScheduledTask(task: b.task, computedStartTime: b.task.startTime!),
    ];

    // ── 3. Compute free gaps ──────────────────────────────────────────
    final gaps = <_Gap>[];
    var cursor = dayStartMin;

    for (final block in fixedBlocks) {
      if (block.startMin > cursor) {
        gaps.add(_Gap(startMin: cursor, endMin: block.startMin));
      }
      if (block.endMin > cursor) {
        cursor = block.endMin;
      }
    }
    // Gap after the last fixed block.
    if (cursor < dayEndMin) {
      gaps.add(_Gap(startMin: cursor, endMin: dayEndMin));
    }

    // ── 4. Sort floating tasks: priority desc, then duration asc ──────
    floatingTasks.sort((a, b) {
      final priCmp = b.priority.index.compareTo(a.priority.index);
      if (priCmp != 0) return priCmp;
      return a.durationMinutes.compareTo(b.durationMinutes);
    });

    // ── 5. Greedy slot-fill ───────────────────────────────────────────
    final overflow = <Task>[];

    for (final task in floatingTasks) {
      var placed = false;

      for (final gap in gaps) {
        // Skip gaps that end before now — floating tasks should not be
        // placed in the past.
        if (gap.endMin <= effectiveNow) continue;

        // If the gap straddles now, clamp its usable start to now.
        final usableStart =
            gap.startMin < effectiveNow ? effectiveNow : gap.startMin;
        final available = gap.endMin - usableStart;

        if (available >= task.durationMinutes) {
          final startTime = TimeOfDay(
            hour: usableStart ~/ 60,
            minute: usableStart % 60,
          );
          committed.add(
            ScheduledTask(task: task, computedStartTime: startTime),
          );

          // Shrink the gap from the usable start.
          gap.startMin = usableStart + task.durationMinutes;
          placed = true;
          break;
        }
      }

      if (!placed) {
        overflow.add(task);
      }
    }

    // Sort committed by start time for consistent rendering.
    committed.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    return DaySchedule(committed: committed, overflow: overflow);
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────

/// A fixed time block on the timeline.
class _Block {
  _Block({required this.task, required this.startMin, required this.endMin});

  final Task task;
  final int startMin;
  final int endMin;
}

/// A free gap between fixed blocks.
class _Gap {
  _Gap({required this.startMin, required this.endMin});

  int startMin;
  final int endMin;
}
