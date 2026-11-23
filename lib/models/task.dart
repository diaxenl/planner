import 'dart:math';

import 'package:flutter/material.dart';

/// The type of a task, determining how it behaves in the scheduler.
enum TaskType {
  /// Immovable — fixed start time, never rescheduled.
  hard,

  /// User-set start time, but may be moved if conflicting.
  pinned,

  /// No fixed time — the scheduler assigns a slot.
  floating,
}

/// Lifecycle status of a task.
///
/// Valid transitions: `notStarted` → `inProgress` → `complete`, or
/// `notStarted`/`inProgress` → `cancelled`. See the "Input Validation
/// Rules" section of the HyperDay PRD for which UI actions are allowed
/// from each status.
enum TaskStatus {
  /// Default status — the task has not been started or acted on yet.
  notStarted,

  /// The user has tapped Start; the task is actively being worked on
  /// and is treated as a fixed block by the scheduler.
  inProgress,

  /// The task has been finished.
  complete,

  /// The task was abandoned before completion. Frees its slot like a
  /// completed task, but is excluded from estimate-accuracy stats.
  cancelled,
}

/// How soon Anytime work should be fitted into free time. Outcomes and
/// "Do next" work come before all of these.
enum TaskPriority { high, normal, low }

/// An immutable task entity.
///
/// All fields are `final`. To change a field, use [copyWith] which returns
/// a new [Task] with the specified fields replaced. Mutations should only
/// happen through [DayPlannerModel] methods.
class Task {
  Task({
    String? id,
    required this.title,
    required this.durationMinutes,
    required this.type,
    this.startTime,
    this.isOutcome = false,
    this.isInterruption = false,
    this.status = TaskStatus.notStarted,
    this.completedAt,
    this.startedAt,
    this.actualDurationMinutes,
    this.pausedRuns = const [],
    required this.date,
    this.carriedFromDate,
    this.doNextAt,
    this.recurringId,
    this.priority = TaskPriority.normal,
    this.resumeAt,
  }) : id = id ?? _generateId();

  /// Unique identifier — 16-character hex string.
  final String id;

  /// Short description of the task.
  final String title;

  /// How long the task takes, in minutes.
  final int durationMinutes;

  /// Determines scheduling behaviour (hard / pinned / floating).
  final TaskType type;

  /// Fixed start time. Required for [TaskType.hard] and [TaskType.pinned];
  /// `null` for [TaskType.floating].
  final TimeOfDay? startTime;

  /// Whether this task is one of the day's Outcomes — the few things that
  /// make the day a win. Outcome floating tasks are scheduled first.
  final bool isOutcome;

  /// Whether this task was captured as an interruption ("Something came
  /// up"). Set by the capture flow only, never by hand.
  final bool isInterruption;

  /// Lifecycle status of the task. See [TaskStatus] for valid transitions.
  final TaskStatus status;

  /// The moment the user marked this task complete.
  final DateTime? completedAt;

  /// The moment the user tapped Start. Non-null once the task has been
  /// [TaskStatus.inProgress] at least once. Used to anchor the task as a
  /// fixed block while in progress and to compute [actualDurationMinutes]
  /// on completion.
  final DateTime? startedAt;

  /// Time spent, in minutes. On a completed task: the total tracked time
  /// (or the estimate if nothing was tracked). Before completion: minutes
  /// tracked on earlier runs that were paused, or `null`.
  final int? actualDurationMinutes;

  /// When it was worked on before being paused, in order: each run from
  /// its Start to its Pause. Kept so paused work stays on the timeline
  /// where it happened. The current run (if any) starts at [startedAt].
  final List<DateTimeRange> pausedRuns;

  /// The calendar day this task belongs to (date only, time ignored).
  final DateTime date;

  /// If this task was carried forward from a previous day, the original date.
  /// `null` for tasks created on their native day.
  final DateTime? carriedFromDate;

  /// When the user chose "Do next" for this task. Floating work marked
  /// this way is planned before everything else, latest choice first.
  final DateTime? doNextAt;

  /// The repeating series this task was created from, or `null` for a
  /// one-off task. See `RecurringTask`.
  final String? recurringId;

  /// Fill order among other Anytime work: High, then Normal, then Low.
  final TaskPriority priority;

  /// Set when a meeting paused this task: when to start it again (the
  /// meeting's end). Cleared once it resumes or the user acts on it.
  final DateTime? resumeAt;

  /// Minutes still to plan: the estimate minus minutes already tracked on
  /// earlier, paused runs (never less than 5).
  int get remainingMinutes {
    final left = durationMinutes - (actualDurationMinutes ?? 0);
    return left < 5 ? 5 : left;
  }

  /// Returns a new [Task] with the given fields replaced.
  Task copyWith({
    String? id,
    String? title,
    int? durationMinutes,
    TaskType? type,
    TimeOfDay? Function()? startTime,
    bool? isOutcome,
    bool? isInterruption,
    TaskStatus? status,
    DateTime? Function()? completedAt,
    DateTime? Function()? startedAt,
    int? Function()? actualDurationMinutes,
    List<DateTimeRange>? pausedRuns,
    DateTime? date,
    DateTime? Function()? carriedFromDate,
    DateTime? Function()? doNextAt,
    String? Function()? recurringId,
    TaskPriority? priority,
    DateTime? Function()? resumeAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      type: type ?? this.type,
      startTime: startTime != null ? startTime() : this.startTime,
      isOutcome: isOutcome ?? this.isOutcome,
      isInterruption: isInterruption ?? this.isInterruption,
      status: status ?? this.status,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
      startedAt: startedAt != null ? startedAt() : this.startedAt,
      actualDurationMinutes: actualDurationMinutes != null
          ? actualDurationMinutes()
          : this.actualDurationMinutes,
      pausedRuns: pausedRuns ?? this.pausedRuns,
      date: date ?? this.date,
      carriedFromDate: carriedFromDate != null
          ? carriedFromDate()
          : this.carriedFromDate,
      doNextAt: doNextAt != null ? doNextAt() : this.doNextAt,
      recurringId: recurringId != null ? recurringId() : this.recurringId,
      priority: priority ?? this.priority,
      resumeAt: resumeAt != null ? resumeAt() : this.resumeAt,
    );
  }

  /// Computed end time for tasks that have a [startTime].
  /// Returns `null` if [startTime] is `null`.
  TimeOfDay? get endTime {
    if (startTime == null) return null;
    final totalMinutes =
        startTime!.hour * 60 + startTime!.minute + durationMinutes;
    return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
  }

  /// Minutes tracked as of [at]: earlier, paused runs (kept in
  /// [actualDurationMinutes] while not complete) plus the current run. On
  /// a completed task, the total recorded at completion.
  int trackedMinutes(DateTime at) {
    final earlier = actualDurationMinutes ?? 0;
    if (status != TaskStatus.inProgress || startedAt == null) return earlier;
    final current = at.difference(startedAt!).inMinutes;
    return earlier + (current < 0 ? 0 : current);
  }

  /// Returns `true` if this task is [TaskStatus.inProgress] and the
  /// elapsed time since [startedAt] exceeds [durationMinutes] as of [now].
  bool isOverrunning(DateTime now) {
    if (status != TaskStatus.inProgress || startedAt == null) return false;
    return now.difference(startedAt!).inMinutes > durationMinutes;
  }

  // ── ID generation ──────────────────────────────────────────────────

  static final Random _rng = Random.secure();

  /// Generates a 16-character lowercase hex string using [Random.secure].
  static String _generateId() {
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ── Serialisation ──────────────────────────────────────────────────

  /// Serialises this task to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'durationMinutes': durationMinutes,
      'type': type.name,
      'startTime': startTime == null
          ? null
          : {'hour': startTime!.hour, 'minute': startTime!.minute},
      'isOutcome': isOutcome,
      'isInterruption': isInterruption,
      'status': status.name,
      'completedAt': completedAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'actualDurationMinutes': actualDurationMinutes,
      'pausedRuns': [
        for (final r in pausedRuns)
          {'start': r.start.toIso8601String(), 'end': r.end.toIso8601String()},
      ],
      'date': date.toIso8601String(),
      'carriedFromDate': carriedFromDate?.toIso8601String(),
      'doNextAt': doNextAt?.toIso8601String(),
      'recurringId': recurringId,
      'priority': priority.name,
      'resumeAt': resumeAt?.toIso8601String(),
    };
  }

  /// Deserialises a [Task] from [json], which must be a map produced by
  /// [toJson]. Returns `null` if any required field is missing or invalid.
  static Task? fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String;
      final title = json['title'] as String;
      final durationMinutes = json['durationMinutes'] as int;
      final type = TaskType.values.firstWhere((e) => e.name == json['type']);
      final startTimeMap = json['startTime'] as Map<String, dynamic>?;
      final startTime = startTimeMap == null
          ? null
          : TimeOfDay(
              hour: startTimeMap['hour'] as int,
              minute: startTimeMap['minute'] as int,
            );
      final isOutcome = json['isOutcome'] as bool? ?? false;
      final isInterruption = json['isInterruption'] as bool? ?? false;
      final status = TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
      );
      final completedAt = json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String);
      final startedAt = json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String);
      final actualDurationMinutes = json['actualDurationMinutes'] as int?;
      final pausedRuns = [
        for (final r in json['pausedRuns'] as List<dynamic>? ?? const [])
          DateTimeRange(
            start: DateTime.parse(
              (r as Map<String, dynamic>)['start'] as String,
            ),
            end: DateTime.parse(r['end'] as String),
          ),
      ];
      final date = DateTime.parse(json['date'] as String);
      final carriedFromDate = json['carriedFromDate'] == null
          ? null
          : DateTime.parse(json['carriedFromDate'] as String);
      final doNextAt = json['doNextAt'] == null
          ? null
          : DateTime.parse(json['doNextAt'] as String);
      final recurringId = json['recurringId'] as String?;
      final priority =
          TaskPriority.values
              .where((p) => p.name == json['priority'])
              .firstOrNull ??
          TaskPriority.normal;
      final resumeAt = json['resumeAt'] == null
          ? null
          : DateTime.parse(json['resumeAt'] as String);

      return Task(
        id: id,
        title: title,
        durationMinutes: durationMinutes,
        type: type,
        startTime: startTime,
        isOutcome: isOutcome,
        isInterruption: isInterruption,
        status: status,
        completedAt: completedAt,
        startedAt: startedAt,
        actualDurationMinutes: actualDurationMinutes,
        pausedRuns: pausedRuns,
        date: date,
        carriedFromDate: carriedFromDate,
        doNextAt: doNextAt,
        recurringId: recurringId,
        priority: priority,
        resumeAt: resumeAt,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Task && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Task($id, "$title", $type)';
}
