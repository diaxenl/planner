import 'dart:math';

import 'package:flutter/material.dart';

import 'task.dart';

/// How often a [RecurringTask] repeats.
enum Repeat {
  /// Every day, weekends included.
  daily,

  /// Monday to Friday.
  weekdays,

  /// Once a week, on [RecurringTask.weekday].
  weekly,
}

/// A repeating series. Each day it occurs on (from [startDate], today
/// or later), a copy of it is added to that day as an ordinary [Task]
/// whose [Task.recurringId] is this [id]. Days in [skipDates] are left
/// alone — the copy was deleted or moved away.
class RecurringTask {
  RecurringTask({
    String? id,
    required this.title,
    required this.durationMinutes,
    required this.type,
    this.startTime,
    this.isOutcome = false,
    required this.repeat,
    required this.weekday,
    required this.startDate,
    Set<DateTime>? skipDates,
  }) : id = id ?? _generateId(),
       skipDates = skipDates ?? const {};

  /// Copies [task]'s fields into a series.
  factory RecurringTask.fromTask(
    Task task, {
    String? id,
    required Repeat repeat,
    required int weekday,
    required DateTime startDate,
    Set<DateTime>? skipDates,
  }) => RecurringTask(
    id: id,
    title: task.title,
    durationMinutes: task.durationMinutes,
    type: task.type,
    startTime: task.startTime,
    isOutcome: task.isOutcome,
    repeat: repeat,
    weekday: weekday,
    startDate: startDate,
    skipDates: skipDates,
  );

  final String id;
  final String title;
  final int durationMinutes;
  final TaskType type;
  final TimeOfDay? startTime;
  final bool isOutcome;
  final Repeat repeat;

  /// [DateTime.weekday] for [Repeat.weekly].
  final int weekday;

  /// The first day of the series (date only).
  final DateTime startDate;

  /// Days (date only) that get no copy.
  final Set<DateTime> skipDates;

  /// Whether the series has a copy on [date].
  bool occursOn(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    if (d.isBefore(startDate) || skipDates.contains(d)) return false;
    return switch (repeat) {
      Repeat.daily => true,
      Repeat.weekdays => d.weekday <= DateTime.friday,
      Repeat.weekly => d.weekday == weekday,
    };
  }

  /// A new, not-started copy for [date].
  Task instanceFor(DateTime date, {required bool asOutcome}) => Task(
    title: title,
    durationMinutes: durationMinutes,
    type: type,
    startTime: startTime,
    isOutcome: asOutcome,
    date: DateTime(date.year, date.month, date.day),
    recurringId: id,
  );

  RecurringTask withSkip(DateTime date) => RecurringTask(
    id: id,
    title: title,
    durationMinutes: durationMinutes,
    type: type,
    startTime: startTime,
    isOutcome: isOutcome,
    repeat: repeat,
    weekday: weekday,
    startDate: startDate,
    skipDates: {...skipDates, DateTime(date.year, date.month, date.day)},
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'durationMinutes': durationMinutes,
    'type': type.name,
    'startTime': startTime == null
        ? null
        : {'hour': startTime!.hour, 'minute': startTime!.minute},
    'isOutcome': isOutcome,
    'repeat': repeat.name,
    'weekday': weekday,
    'startDate': startDate.toIso8601String(),
    'skipDates': [for (final d in skipDates) d.toIso8601String()],
  };

  /// Returns `null` if [json] is missing a required field or is invalid.
  static RecurringTask? fromJson(Map<String, dynamic> json) {
    try {
      final time = json['startTime'] as Map<String, dynamic>?;
      return RecurringTask(
        id: json['id'] as String,
        title: json['title'] as String,
        durationMinutes: json['durationMinutes'] as int,
        type: TaskType.values.firstWhere((e) => e.name == json['type']),
        startTime: time == null
            ? null
            : TimeOfDay(
                hour: time['hour'] as int,
                minute: time['minute'] as int,
              ),
        isOutcome: json['isOutcome'] as bool? ?? false,
        repeat: Repeat.values.firstWhere((e) => e.name == json['repeat']),
        weekday: json['weekday'] as int,
        startDate: DateTime.parse(json['startDate'] as String),
        skipDates: {
          for (final d in (json['skipDates'] as List? ?? const []))
            DateTime.parse(d as String),
        },
      );
    } catch (_) {
      return null;
    }
  }

  static final Random _rng = Random.secure();

  static String _generateId() => List.generate(
    8,
    (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
