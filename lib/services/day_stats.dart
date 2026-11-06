import '../models/day_schedule.dart';
import '../models/scheduled_task.dart';
import '../models/task.dart';

/// Minutes of the remaining day window, split by what fills them.
class LoadBreakdown {
  const LoadBreakdown({
    required this.meetings,
    required this.outcomes,
    required this.other,
    required this.free,
    required this.overflow,
  });

  final int meetings;
  final int outcomes;
  final int other;
  final int free;

  /// Minutes of work that does not fit in the day at all.
  final int overflow;

  int get total => meetings + outcomes + other + free;
}

/// Where a day's time goes, for the end-of-day review.
enum TimeBucket { meetings, outcomes, other, interruptions }

/// Planned vs actual minutes per [TimeBucket].
class TimeSplit {
  const TimeSplit({required this.planned, required this.actual});

  final Map<TimeBucket, int> planned;
  final Map<TimeBucket, int> actual;
}

/// Pure, derived statistics over a day's schedule. No stored state.
class DayStats {
  DayStats._();

  /// Splits the window from [nowMinutes] (clamped to the day window) to
  /// the end of the day into Meetings / Outcomes / Other / Free, counting
  /// only the part of each active (not complete or cancelled) item that
  /// falls in that window.
  static LoadBreakdown loadBreakdown(
    DaySchedule schedule, {
    required int nowMinutes,
    required int dayStartHour,
    required int dayEndHour,
  }) {
    final dayEnd = dayEndHour * 60;
    final windowStart = nowMinutes.clamp(dayStartHour * 60, dayEnd);

    var meetings = 0, outcomes = 0, other = 0;
    for (final st in schedule.committed) {
      final t = st.task;
      if (t.status == TaskStatus.complete || t.status == TaskStatus.cancelled) {
        continue;
      }
      final start = st.startMinutes < windowStart
          ? windowStart
          : st.startMinutes;
      final end = st.endMinutes > dayEnd ? dayEnd : st.endMinutes;
      final minutes = end - start;
      if (minutes <= 0) continue;

      if (t.type == TaskType.hard) {
        meetings += minutes;
      } else if (t.isOutcome) {
        outcomes += minutes;
      } else {
        other += minutes;
      }
    }

    final busy = meetings + outcomes + other;
    final window = dayEnd - windowStart;
    final overflow = schedule.overflow
        .where(
          (t) =>
              t.status != TaskStatus.complete &&
              t.status != TaskStatus.cancelled,
        )
        .fold<int>(0, (sum, t) => sum + t.remainingMinutes);

    return LoadBreakdown(
      meetings: meetings,
      outcomes: outcomes,
      other: other,
      free: busy >= window ? 0 : window - busy,
      overflow: overflow,
    );
  }

  /// The item to focus on at [nowMinutes]: a meeting or set-time item
  /// that is on right now; else the most recently started in-progress
  /// item; else the not-started item whose window contains now; else the
  /// next upcoming not-started item. `null` if nothing is left today.
  ///
  /// A meeting takes the card even while a task is running, so the task
  /// can't hide it (see [runningItem]).
  static ScheduledTask? currentItem(DaySchedule schedule, int nowMinutes) {
    final active = schedule.committed.where(
      (st) =>
          st.task.status == TaskStatus.notStarted ||
          st.task.status == TaskStatus.inProgress,
    );

    final running = runningItem(schedule);
    if (running != null) {
      for (final st in active) {
        if (_isFixedNotStarted(st) &&
            st.startMinutes <= nowMinutes &&
            nowMinutes < st.endMinutes) {
          return st;
        }
      }
      return running;
    }
    for (final st in active) {
      if (st.startMinutes <= nowMinutes && nowMinutes < st.endMinutes) {
        return st;
      }
    }
    for (final st in active) {
      if (st.startMinutes >= nowMinutes) return st;
    }
    return null;
  }

  /// The most recently started in-progress item (its first session, if
  /// split), or `null` if nothing is running.
  static ScheduledTask? runningItem(DaySchedule schedule) {
    ScheduledTask? latest;
    for (final st in schedule.committed) {
      if (st.task.status != TaskStatus.inProgress) continue;
      final started = st.task.startedAt;
      if (latest == null ||
          (started != null && started.isAfter(latest.task.startedAt!))) {
        latest = st;
      }
    }
    return latest;
  }

  /// The next not-started meeting or set-time item starting at or after
  /// [nowMinutes], or `null`.
  static ScheduledTask? nextFixedItem(DaySchedule schedule, int nowMinutes) {
    for (final st in schedule.committed) {
      if (_isFixedNotStarted(st) && st.startMinutes >= nowMinutes) return st;
    }
    return null;
  }

  static bool _isFixedNotStarted(ScheduledTask st) =>
      st.task.type != TaskType.floating &&
      st.task.status == TaskStatus.notStarted;

  /// The bucket a task's time counts toward. Meetings first, then
  /// interruptions (unplanned by definition), then Outcomes, then other.
  static TimeBucket bucketOf(Task t) {
    if (t.type == TaskType.hard) return TimeBucket.meetings;
    if (t.isInterruption) return TimeBucket.interruptions;
    if (t.isOutcome) return TimeBucket.outcomes;
    return TimeBucket.other;
  }

  /// Planned vs actual minutes per bucket. Meetings come from the
  /// schedule (so imported calendar meetings count) and are assumed
  /// attended as planned. Everything else is planned at its estimate and
  /// counted as actual from tracked time on completed tasks. Interruptions
  /// are never planned. Cancelled items count for nothing.
  static TimeSplit timeSplit(List<Task> tasks, DaySchedule schedule) {
    final planned = {for (final b in TimeBucket.values) b: 0};
    final actual = {for (final b in TimeBucket.values) b: 0};

    for (final st in schedule.committed) {
      final t = st.task;
      if (t.type != TaskType.hard || t.status == TaskStatus.cancelled) continue;
      planned[TimeBucket.meetings] =
          planned[TimeBucket.meetings]! + t.durationMinutes;
      actual[TimeBucket.meetings] =
          actual[TimeBucket.meetings]! + t.durationMinutes;
    }

    for (final t in tasks) {
      if (t.type == TaskType.hard || t.status == TaskStatus.cancelled) continue;
      final b = bucketOf(t);
      if (b != TimeBucket.interruptions) {
        planned[b] = planned[b]! + t.durationMinutes;
      }
      if (t.status == TaskStatus.complete) {
        actual[b] = actual[b]! + (t.actualDurationMinutes ?? 0);
      }
    }
    return TimeSplit(planned: planned, actual: actual);
  }

  /// How far actual time ran over (+) or under (−) estimates, as a whole
  /// percentage, across completed non-meeting tasks with tracked time.
  /// Tasks completed without ever being started (`startedAt ==
  /// completedAt`) are left out. `null` when there is nothing to compare.
  static int? estimateAccuracy(List<Task> tasks) {
    var estimated = 0, actual = 0;
    for (final t in tasks) {
      if (t.type == TaskType.hard || t.status != TaskStatus.complete) continue;
      if (t.startedAt != null && t.startedAt == t.completedAt) continue;
      final tracked = t.actualDurationMinutes ?? 0;
      if (tracked <= 0) continue;
      estimated += t.durationMinutes;
      actual += tracked;
    }
    if (estimated == 0) return null;
    return ((actual - estimated) * 100 / estimated).round();
  }

  /// Minutes worked on Outcomes and on all non-meeting work, from tracked
  /// time on completed tasks: `(outcomes, worked)`.
  static (int, int) workedMinutes(List<Task> tasks) {
    var outcomes = 0, worked = 0;
    for (final t in tasks) {
      if (t.type == TaskType.hard || t.status != TaskStatus.complete) continue;
      final minutes = t.actualDurationMinutes ?? 0;
      worked += minutes;
      if (bucketOf(t) == TimeBucket.outcomes) outcomes += minutes;
    }
    return (outcomes, worked);
  }

  /// (completed, total) Outcomes, ignoring cancelled ones.
  static (int, int) outcomesHit(List<Task> tasks) {
    final outcomes = tasks.where(
      (t) => t.isOutcome && t.status != TaskStatus.cancelled,
    );
    return (
      outcomes.where((t) => t.status == TaskStatus.complete).length,
      outcomes.length,
    );
  }
}
