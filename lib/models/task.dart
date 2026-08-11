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

/// Priority level for ordering floating tasks during scheduling.
enum Priority {
  low,
  medium,
  high,
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
    this.priority = Priority.medium,
    this.status = TaskStatus.notStarted,
    this.completedAt,
    this.startedAt,
    this.actualDurationMinutes,
    required this.date,
    this.carriedFromDate,
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

  /// Scheduling priority — higher priority floating tasks are placed first.
  final Priority priority;

  /// Lifecycle status of the task. See [TaskStatus] for valid transitions.
  final TaskStatus status;

  /// The moment the user marked this task complete.
  final DateTime? completedAt;

  /// The moment the user tapped Start. Non-null once the task has been
  /// [TaskStatus.inProgress] at least once. Used to anchor the task as a
  /// fixed block while in progress and to compute [actualDurationMinutes]
  /// on completion.
  final DateTime? startedAt;

  /// Elapsed real time in minutes, recorded when the task is completed.
  /// `null` until the task reaches [TaskStatus.complete].
  final int? actualDurationMinutes;

  /// The calendar day this task belongs to (date only, time ignored).
  final DateTime date;

  /// If this task was carried forward from a previous day, the original date.
  /// `null` for tasks created on their native day.
  final DateTime? carriedFromDate;

  /// Returns a new [Task] with the given fields replaced.
  Task copyWith({
    String? id,
    String? title,
    int? durationMinutes,
    TaskType? type,
    TimeOfDay? Function()? startTime,
    Priority? priority,
    TaskStatus? status,
    DateTime? Function()? completedAt,
    DateTime? Function()? startedAt,
    int? Function()? actualDurationMinutes,
    DateTime? date,
    DateTime? Function()? carriedFromDate,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      type: type ?? this.type,
      startTime: startTime != null ? startTime() : this.startTime,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
      startedAt: startedAt != null ? startedAt() : this.startedAt,
      actualDurationMinutes: actualDurationMinutes != null
          ? actualDurationMinutes()
          : this.actualDurationMinutes,
      date: date ?? this.date,
      carriedFromDate:
          carriedFromDate != null ? carriedFromDate() : this.carriedFromDate,
    );
  }

  /// Computed end time for tasks that have a [startTime].
  /// Returns `null` if [startTime] is `null`.
  TimeOfDay? get endTime {
    if (startTime == null) return null;
    final totalMinutes = startTime!.hour * 60 + startTime!.minute + durationMinutes;
    return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
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
      'priority': priority.name,
      'status': status.name,
      'completedAt': completedAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'actualDurationMinutes': actualDurationMinutes,
      'date': date.toIso8601String(),
      'carriedFromDate': carriedFromDate?.toIso8601String(),
    };
  }

  /// Deserialises a [Task] from [json], which must be a map produced by
  /// [toJson]. Returns `null` if any required field is missing or invalid.
  static Task? fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String;
      final title = json['title'] as String;
      final durationMinutes = json['durationMinutes'] as int;
      final type = TaskType.values.firstWhere(
        (e) => e.name == json['type'],
      );
      final startTimeMap = json['startTime'] as Map<String, dynamic>?;
      final startTime = startTimeMap == null
          ? null
          : TimeOfDay(
              hour: startTimeMap['hour'] as int,
              minute: startTimeMap['minute'] as int,
            );
      final priority = Priority.values.firstWhere(
        (e) => e.name == json['priority'],
      );
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
      final date = DateTime.parse(json['date'] as String);
      final carriedFromDate = json['carriedFromDate'] == null
          ? null
          : DateTime.parse(json['carriedFromDate'] as String);

      return Task(
        id: id,
        title: title,
        durationMinutes: durationMinutes,
        type: type,
        startTime: startTime,
        priority: priority,
        status: status,
        completedAt: completedAt,
        startedAt: startedAt,
        actualDurationMinutes: actualDurationMinutes,
        date: date,
        carriedFromDate: carriedFromDate,
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
