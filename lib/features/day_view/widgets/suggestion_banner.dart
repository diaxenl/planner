import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../models/schedule_suggestion.dart';
import '../../../models/task.dart';

/// A non-intrusive banner shown below the day header when the scheduler
/// proposes rescheduling tasks after a completion event.
///
/// Displays a summary of how many tasks can shift, with expandable
/// details showing each move. Accept commits the new schedule;
/// Dismiss discards it.
class SuggestionBanner extends StatefulWidget {
  const SuggestionBanner({
    super.key,
    required this.suggestion,
    required this.onAccept,
    required this.onDismiss,
  });

  /// The pending suggestion to display.
  final ScheduleSuggestion suggestion;

  /// Called when the user accepts the proposed reschedule.
  final VoidCallback onAccept;

  /// Called when the user dismisses the proposal.
  final VoidCallback onDismiss;

  @override
  State<SuggestionBanner> createState() => _SuggestionBannerState();
}

class _SuggestionBannerState extends State<SuggestionBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Summary row ──
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMedium,
                vertical: AppConstants.paddingMedium,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_fix_high,
                    size: 20,
                    color: Colors.amber.shade800,
                  ),
                  const SizedBox(width: AppConstants.paddingSmall),
                  Expanded(
                    child: Text(
                      widget.suggestion.summary,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                  // Expand / collapse chevron
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: Colors.amber.shade700,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded move details ──
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMedium,
                vertical: AppConstants.paddingSmall,
              ),
              child: Column(
                children: [
                  for (final move in widget.suggestion.moves)
                    _buildMoveRow(context, move),
                ],
              ),
            ),
          ],

          // ── Action buttons ──
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onDismiss,
                  child: Text(
                    'Dismiss',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 24,
                color: Colors.amber.shade200,
              ),
              Expanded(
                child: TextButton(
                  onPressed: widget.onAccept,
                  child: Text(
                    'Accept',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoveRow(BuildContext context, TaskMove move) {
    final isPinned = move.task.type == TaskType.pinned;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.paddingSmall / 2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              move.task.title + (isPinned ? ' (timed)' : ''),
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${_fmt12(move.oldStart)} → ${_fmt12(move.newStart)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt12(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }
}
