import 'package:flutter/material.dart';

import '../../../core/utils.dart';

/// Asks which day to move something to, starting on the next weekday
/// after [from]. Returns the picked day, or `null` if dismissed or the
/// same as [from].
Future<DateTime?> pickMoveDay(BuildContext context, DateTime from) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final initial = AppUtils.nextWorkday(from);
  final picked = await showDatePicker(
    context: context,
    initialDate: initial.isBefore(today) ? today : initial,
    firstDate: today,
    lastDate: DateTime(today.year + 1, today.month, today.day),
    helpText: 'Move to',
  );
  if (picked == null) return null;
  final day = DateTime(picked.year, picked.month, picked.day);
  final fromDay = DateTime(from.year, from.month, from.day);
  return day == fromDay ? null : day;
}
