import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../models/task.dart';

/// Set-time items whose time passed without a Start, each with a one-tap
/// choice: plan it later today (only offered when it still fits, see
/// [fitsToday]), move it to [nextDayLabel], or mark it Done.
class MissedList extends StatelessWidget {
  const MissedList({
    super.key,
    required this.tasks,
    required this.nextDayLabel,
    required this.onLaterToday,
    required this.onNextDay,
    required this.onDone,
    required this.fitsToday,
  });

  final List<Task> tasks;

  /// Whether the item still fits into today's free time.
  final bool Function(Task) fitsToday;

  /// "Tomorrow", or e.g. "Monday" on a Friday.
  final String nextDayLabel;
  final ValueChanged<Task> onLaterToday;
  final ValueChanged<Task> onNextDay;
  final ValueChanged<Task> onDone;

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final buttonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
    final primaryStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MISSED',
            style: text.labelSmall?.copyWith(color: colors.accent),
          ),
          for (final (t, fits) in [
            for (final t in tasks) (t, fitsToday(t)),
          ]) ...[
            const SizedBox(height: 10),
            Text(
              t.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyLarge,
            ),
            Text(
              'Was at ${AppUtils.formatClock(t.startTime!.hour * 60 + t.startTime!.minute)}'
              ' · ${AppUtils.formatDuration(t.durationMinutes)}',
              style: text.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (fits)
                  FilledButton(
                    style: primaryStyle,
                    onPressed: () => onLaterToday(t),
                    child: const Text('Later today'),
                  ),
                // No room left today: the next day is the main choice.
                if (fits)
                  OutlinedButton(
                    style: buttonStyle,
                    onPressed: () => onNextDay(t),
                    child: Text(nextDayLabel),
                  )
                else
                  FilledButton(
                    style: primaryStyle,
                    onPressed: () => onNextDay(t),
                    child: Text(nextDayLabel),
                  ),
                OutlinedButton(
                  style: buttonStyle,
                  onPressed: () => onDone(t),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
