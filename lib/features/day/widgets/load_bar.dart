import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../services/day_stats.dart';

/// One segmented bar for the rest of the day: Meetings / Outcomes /
/// Other / Free, with a one-line summary. Readable in half a second.
class LoadBar extends StatelessWidget {
  const LoadBar({super.key, required this.load, required this.isToday});

  final LoadBreakdown load;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;

    final segments = [
      (load.meetings, colors.meeting),
      (load.outcomes, colors.accent),
      (load.other, colors.other),
      (load.free, colors.hairline),
    ].where((s) => s.$1 > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${AppUtils.formatDuration(load.free)} free',
              style: text.titleMedium?.copyWith(
                fontFeatures: AppTheme.tabularFigures,
              ),
            ),
            Text(
              isToday ? '  for the rest of today' : '  in this day',
              style: text.bodyMedium,
            ),
            const Spacer(),
            if (load.overflow > 0)
              Text(
                '${AppUtils.formatDuration(load.overflow)} won\'t fit',
                style: text.bodySmall?.copyWith(color: colors.accent),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: segments.isEmpty
                ? Container(color: colors.hairline)
                : Row(
                    children: [
                      for (var i = 0; i < segments.length; i++) ...[
                        if (i > 0) const SizedBox(width: 2),
                        Expanded(
                          flex: segments[i].$1,
                          child: Container(color: segments[i].$2),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            if (load.meetings > 0)
              _legend(context, colors.meeting, 'Meetings', load.meetings),
            if (load.outcomes > 0)
              _legend(context, colors.accent, 'Outcomes', load.outcomes),
            if (load.other > 0)
              _legend(context, colors.other, 'Other', load.other),
          ],
        ),
      ],
    );
  }

  Widget _legend(BuildContext context, Color color, String label, int minutes) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ${AppUtils.formatDuration(minutes)}',
          style: text.bodySmall,
        ),
      ],
    );
  }
}
