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
    this.isComplete = false,
    this.completedAt,
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

  /// Whether the task has been marked complete.
  final bool isComplete;

  /// The moment the user marked this task complete.
  final DateTime? completedAt;

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
    bool? isComplete,
    DateTime? Function()? completedAt,
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
      isComplete: isComplete ?? this.isComplete,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
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

  // ── ID generation ──────────────────────────────────────────────────

  static final Random _rng = Random.secure();

  /// Generates a 16-character lowercase hex string using [Random.secure].
  static String _generateId() {
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Task && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Task($id, "$title", $type)';
}
