import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/task.dart';
import '../../services/day_stats.dart';
import '../../state/day_planner_provider.dart';
import '../day/widgets/day_picker.dart';

/// End-of-day review for the viewed day: Outcomes hit, where the time
/// went (planned vs actual), estimate accuracy, and an explicit decision
/// — Tomorrow or Drop — for everything still open.
///
/// The score and time split are taken once when the screen opens, so
/// resolving left-over items here doesn't rewrite the day's result.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const ReviewScreen()));

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final (int, int) _hit;
  late final TimeSplit _split;
  late final int? _accuracy;
  late final Future<List<(DateTime, List<Task>)>> _week;
  bool _snapshotTaken = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_snapshotTaken) return;
    final model = DayPlannerProvider.of(context);
    _hit = DayStats.outcomesHit(model.tasks);
    _split = DayStats.timeSplit(model.tasks, model.schedule);
    _accuracy = DayStats.estimateAccuracy(model.tasks);
    _week = model.lastSevenDays();
    _snapshotTaken = true;
  }

  @override
  Widget build(BuildContext context) {
    final model = DayPlannerProvider.of(context);
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final (hit, total) = _hit;
    final actual = _split.actual;
    final planned = _split.planned;
    final date = model.viewedDate;
    final isToday = model.isViewingToday;
    final nextDay = AppUtils.nextWorkday(date);
    final nextDayLabel = AppUtils.friendlyDate(nextDay, DateTime.now());

    final unfinished = model.tasks
        .where(
          (t) =>
              t.type != TaskType.hard &&
              (t.status == TaskStatus.notStarted ||
                  t.status == TaskStatus.inProgress),
        )
        .toList();

    // One scale for every bar, so lengths compare across buckets.
    final scale = [
      for (final b in TimeBucket.values) ...[actual[b]!, planned[b]!],
    ].fold<int>(0, (m, v) => v > m ? v : m);
    final worked =
        actual[TimeBucket.outcomes]! +
        actual[TimeBucket.other]! +
        actual[TimeBucket.interruptions]!;
    final outcomeShare = worked == 0
        ? null
        : (actual[TimeBucket.outcomes]! * 100 / worked).round();

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
          if (outcomeShare != null) ...[
            const SizedBox(height: 8),
            Text(
              '$outcomeShare% of your working time went to outcomes'
              '${actual[TimeBucket.interruptions]! > 0 ? ', '
                        '${AppUtils.formatDuration(actual[TimeBucket.interruptions]!)} '
                        'to interruptions' : ''}.',
              style: text.bodyMedium,
            ),
          ],
          const SizedBox(height: 32),

          // ── Time split ──
          Text('WHERE THE TIME WENT', style: text.labelSmall),
          const SizedBox(height: 12),
          _bucket(
            context,
            'Outcomes',
            colors.accent,
            actual[TimeBucket.outcomes]!,
            planned[TimeBucket.outcomes]!,
            scale,
          ),
          _bucket(
            context,
            'Interruptions',
            colors.accent.withValues(alpha: 0.4),
            actual[TimeBucket.interruptions]!,
            0,
            scale,
          ),
          _bucket(
            context,
            'Other',
            colors.other,
            actual[TimeBucket.other]!,
            planned[TimeBucket.other]!,
            scale,
          ),
          _bucket(
            context,
            'Meetings',
            colors.meeting,
            actual[TimeBucket.meetings]!,
            planned[TimeBucket.meetings]!,
            scale,
          ),
          const SizedBox(height: 8),
          Text(switch (_accuracy) {
            null => 'Use Start and Done to see how your estimates hold up.',
            0 => 'Your estimates were spot on.',
            final a when a > 0 => 'Work ran $a% over your estimates.',
            final a => 'Work came in ${-a}% under your estimates.',
          }, style: text.bodyMedium),
          const SizedBox(height: 32),

          // ── Last 7 days ──
          Text('LAST 7 DAYS', style: text.labelSmall),
          const SizedBox(height: 12),
          FutureBuilder<List<(DateTime, List<Task>)>>(
            future: _week,
            builder: (context, snapshot) {
              final days = snapshot.data;
              if (days == null) return const SizedBox(height: 120);
              return _WeekSummary(days: days);
            },
          ),
          const SizedBox(height: 32),

          // ── Still open ──
          Text(isToday ? 'STILL OPEN' : 'LEFT OVER', style: text.labelSmall),
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
                    onPressed: () => _drop(t),
                    child: const Text('Drop'),
                  ),
                  TextButton(
                    onPressed: () => _moveTo(t, nextDay),
                    style: TextButton.styleFrom(foregroundColor: colors.accent),
                    child: Text(nextDayLabel),
                  ),
                  IconButton(
                    tooltip: 'Pick a day',
                    onPressed: () async {
                      final day = await pickMoveDay(context, date);
                      if (day != null) await _moveTo(t, day);
                    },
                    icon: Icon(Icons.event, color: colors.accent, size: 20),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _drop(Task task) {
    final model = DayPlannerProvider.of(context);
    model.cancelTask(task.id);
    _snack('Dropped "${task.title}"', () => model.updateTask(task.id, task));
  }

  Future<void> _moveTo(Task task, DateTime day) async {
    final model = DayPlannerProvider.of(context);
    final from = model.viewedDate;
    final index = model.tasks.indexWhere((t) => t.id == task.id);
    final moved = await model.moveToDate(task.id, day);
    final phrase = AppUtils.dayPhrase(day, DateTime.now());
    final lostOutcome = task.isOutcome && moved != null && !moved.isOutcome;
    _snack(
      lostOutcome
          ? 'Moved "${task.title}" to $phrase — not as an Outcome, '
                'that day is full'
          : 'Moved "${task.title}" to $phrase',
      () {
        if (model.viewedDate == from) {
          model.undoMoveToDate(task, day, index: index);
        }
      },
    );
  }

  void _snack(String message, VoidCallback undo) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              try {
                undo();
              } on ArgumentError catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text("Couldn't undo: ${e.message}")),
                );
              }
            },
          ),
        ),
      );
  }

  /// One bucket row: label, actual vs planned, and a bar of actual time on
  /// the shared [scale].
  Widget _bucket(
    BuildContext context,
    String label,
    Color color,
    int actual,
    int planned,
    int scale,
  ) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
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
                    Expanded(
                      flex: actual,
                      child: Container(color: color),
                    ),
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

/// Outcomes done and the share of working time that went to Outcomes,
/// for each of the last seven days, with a one-line total.
class _WeekSummary extends StatelessWidget {
  const _WeekSummary({required this.days});

  /// Oldest first.
  final List<(DateTime, List<Task>)> days;

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;

    var hit = 0, total = 0, outcomeMinutes = 0, worked = 0;
    for (final (_, tasks) in days) {
      final (h, t) = DayStats.outcomesHit(tasks);
      final (o, w) = DayStats.workedMinutes(tasks);
      hit += h;
      total += t;
      outcomeMinutes += o;
      worked += w;
    }
    final share = worked == 0 ? null : (outcomeMinutes * 100 / worked).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          total == 0
              ? 'No outcomes set in the last 7 days.'
              : '$hit of $total outcomes done'
                    '${share == null ? '' : ' · $share% of working time to outcomes'}.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 12),
        for (final (day, tasks) in days)
          Builder(
            builder: (context) {
              final (h, t) = DayStats.outcomesHit(tasks);
              final (o, w) = DayStats.workedMinutes(tasks);
              final dayShare = w == 0 ? 0 : (o * 100 / w).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        AppUtils.weekdayName(day.weekday).substring(0, 3),
                        style: text.bodySmall,
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        t == 0 ? '—' : '$h/$t',
                        style: text.bodySmall?.copyWith(
                          color: t > 0 && h == t
                              ? colors.accent
                              : colors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 6,
                          child: Row(
                            children: [
                              if (dayShare > 0)
                                Expanded(
                                  flex: dayShare,
                                  child: Container(color: colors.accent),
                                ),
                              if (dayShare < 100)
                                Expanded(
                                  flex: 100 - dayShare,
                                  child: Container(color: colors.hairline),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        w == 0 ? '' : '$dayShare%',
                        textAlign: TextAlign.right,
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
