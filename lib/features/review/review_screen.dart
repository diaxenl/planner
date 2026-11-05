import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/task.dart';
import '../../services/day_stats.dart';
import '../../state/day_planner_provider.dart';

/// End-of-day review for the viewed day: Outcomes hit, where the time
/// went (planned vs actual), estimate accuracy, and an explicit decision
/// — Tomorrow or Drop — for everything left unfinished.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const ReviewScreen()));

  @override
  Widget build(BuildContext context) {
    final model = DayPlannerProvider.of(context);
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final tasks = model.tasks;
    final (hit, total) = DayStats.outcomesHit(tasks);
    final split = DayStats.timeSplit(tasks, model.schedule);
    final accuracy = DayStats.estimateAccuracy(tasks);
    final unfinished = tasks
        .where((t) =>
            t.type != TaskType.hard &&
            (t.status == TaskStatus.notStarted ||
                t.status == TaskStatus.inProgress))
        .toList();
    final date = model.viewedDate;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Review · ${AppUtils.relativeDayLabel(date, DateTime.now())}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── Outcomes hit ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                total == 0 ? '—' : '$hit / $total',
                style: text.displaySmall?.copyWith(color: colors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  total == 0
                      ? 'No outcomes were set.'
                      : hit == total
                          ? 'Every outcome done.'
                          : 'outcomes done',
                  style: text.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Time split ──
          Text('WHERE THE TIME WENT', style: text.labelSmall),
          const SizedBox(height: 12),
          _bucket(context, 'Outcomes', colors.accent,
              split.actual[TimeBucket.outcomes]!,
              split.planned[TimeBucket.outcomes]!),
          _bucket(context, 'Meetings', colors.meeting,
              split.actual[TimeBucket.meetings]!,
              split.planned[TimeBucket.meetings]!),
          _bucket(context, 'Other', colors.other,
              split.actual[TimeBucket.other]!,
              split.planned[TimeBucket.other]!),
          _bucket(context, 'Interruptions', colors.textSecondary,
              split.actual[TimeBucket.interruptions]!, 0),
          const SizedBox(height: 8),
          Text(
            switch (accuracy) {
              null => 'Use Start and Done to see how your estimates hold up.',
              0 => 'Your estimates were spot on.',
              > 0 => 'Work ran $accuracy% over your estimates.',
              _ => 'Work came in ${-accuracy}% under your estimates.',
            },
            style: text.bodyMedium,
          ),
          const SizedBox(height: 32),

          // ── Unfinished ──
          Text('LEFT OVER', style: text.labelSmall),
          const SizedBox(height: 8),
          if (unfinished.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('Nothing left over.', style: text.bodyLarge),
            ),
          for (final t in unfinished)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.hairline)),
              ),
              child: Row(
                children: [
                  if (t.isOutcome)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => model.cancelTask(t.id),
                    child: const Text('Drop'),
                  ),
                  TextButton(
                    onPressed: () => model.moveToDate(
                      t.id,
                      date.add(const Duration(days: 1)),
                    ),
                    style: TextButton.styleFrom(foregroundColor: colors.accent),
                    child: const Text('Tomorrow'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// One bucket row: label, actual vs planned, and a bar of actual
  /// against the larger of the two.
  Widget _bucket(
    BuildContext context,
    String label,
    Color color,
    int actual,
    int planned,
  ) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final scale = actual > planned ? actual : planned;
    final detail = planned == 0
        ? (actual == 0 ? 'none' : 'unplanned')
        : 'of ${AppUtils.formatDuration(planned)} planned';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: text.bodyLarge),
              const Spacer(),
              Text(
                AppUtils.formatDuration(actual),
                style: text.bodySmall?.copyWith(color: colors.textPrimary),
              ),
              Text('  $detail', style: text.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (actual > 0)
                    Expanded(flex: actual, child: Container(color: color)),
                  if (scale - actual > 0)
                    Expanded(
                      flex: scale - actual,
                      child: Container(color: colors.hairline),
                    ),
                  if (scale == 0)
                    Expanded(child: Container(color: colors.hairline)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
