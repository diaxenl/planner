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
      if (t.status == TaskStatus.complete ||
          t.status == TaskStatus.cancelled) {
        continue;
      }
      final start = st.startMinutes < windowStart ? windowStart : st.startMinutes;
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
        .where((t) =>
            t.status != TaskStatus.complete &&
            t.status != TaskStatus.cancelled)
        .fold<int>(0, (sum, t) => sum + t.durationMinutes);

    return LoadBreakdown(
      meetings: meetings,
      outcomes: outcomes,
      other: other,
      free: busy >= window ? 0 : window - busy,
      overflow: overflow,
    );
  }

  /// The item to focus on at [nowMinutes]: the in-progress item if any,
  /// else the not-started item whose window contains now, else the next
  /// upcoming not-started item. `null` if nothing is left today.
  static ScheduledTask? currentItem(DaySchedule schedule, int nowMinutes) {
    final active = schedule.committed.where(
      (st) =>
          st.task.status == TaskStatus.notStarted ||
          st.task.status == TaskStatus.inProgress,
    );

    for (final st in active) {
      if (st.task.status == TaskStatus.inProgress) return st;
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
}
