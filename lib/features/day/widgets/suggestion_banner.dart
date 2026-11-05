import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../models/schedule_suggestion.dart';

/// Tells the user their day shifted in a way that matters — an Outcome
/// moved later or something no longer fits — with OK / Undo.
class SuggestionBanner extends StatelessWidget {
  const SuggestionBanner({
    super.key,
    required this.suggestion,
    required this.onAccept,
    required this.onDismiss,
  });

  final ScheduleSuggestion suggestion;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR DAY SHIFTED',
            style: text.labelSmall?.copyWith(color: colors.accent),
          ),
          const SizedBox(height: 6),
          Text(suggestion.summary, style: text.bodyLarge),
          for (final t in suggestion.pushedOut)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ),
                  Text(
                    "Doesn't fit",
                    style: text.bodySmall?.copyWith(color: colors.accent),
                  ),
                ],
              ),
            ),
          for (final move in suggestion.moves)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      move.task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ),
                  Text(
                    '${AppUtils.formatClock(_m(move.oldStart))} → '
                    '${AppUtils.formatClock(_m(move.newStart))}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (suggestion.canUndo)
                TextButton(onPressed: onDismiss, child: const Text('Undo')),
              TextButton(
                onPressed: onAccept,
                style: TextButton.styleFrom(foregroundColor: colors.accent),
                child: const Text('OK'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static int _m(TimeOfDay t) => t.hour * 60 + t.minute;
}
