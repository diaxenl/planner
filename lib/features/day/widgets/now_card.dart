import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../models/scheduled_task.dart';
import '../../../models/task.dart';

/// The one thing to focus on right now, with a live timer.
///
/// - In progress: elapsed time; turns accent and shows "+Xm over" once
///   the estimate is exceeded. Actions: Done, Cancel.
/// - Not started: counts down to its start (or shows its window if it
///   should already be under way). Actions: Start, Done, Cancel.
/// - Meetings: shows time remaining / until start; no actions.
/// - [item] null: an "all clear" message.
class NowCard extends StatefulWidget {
  const NowCard({
    super.key,
    required this.item,
    required this.onStart,
    required this.onDone,
    required this.onCancel,
    required this.onTap,
  });

  final ScheduledTask? item;
  final VoidCallback onStart;
  final VoidCallback onDone;
  final VoidCallback onCancel;
  final VoidCallback onTap;

  @override
  State<NowCard> createState() => _NowCardState();
}

class _NowCardState extends State<NowCard> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final item = widget.item;

    if (item == null) {
      return _Shell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NOW', style: text.labelSmall),
            const SizedBox(height: 8),
            Text('Nothing left on the plan.', style: text.titleLarge),
            const SizedBox(height: 4),
            Text('Capture something below, or call it a day.',
                style: text.bodyMedium),
          ],
        ),
      );
    }

    final task = item.task;
    final now = DateTime.now();
    final nowSeconds = now.hour * 3600 + now.minute * 60 + now.second;
    final startSeconds = item.startMinutes * 60;
    final endSeconds = item.endMinutes * 60;
    final isMeeting = task.type == TaskType.hard;
    final inProgress = task.status == TaskStatus.inProgress;

    String label;
    String timer;
    String detail;
    var timerColor = colors.textPrimary;

    if (inProgress) {
      final elapsed = now.difference(task.startedAt!);
      final over = elapsed.inMinutes - task.durationMinutes;
      label = 'NOW';
      timer = AppUtils.formatTimer(elapsed);
      if (over > 0) {
        timerColor = colors.accent;
        detail = '+${AppUtils.formatDuration(over)} over your '
            '${AppUtils.formatDuration(task.durationMinutes)} estimate';
      } else {
        detail = 'of ${AppUtils.formatDuration(task.durationMinutes)}';
      }
    } else if (nowSeconds < startSeconds) {
      label = isMeeting ? 'NEXT MEETING' : 'UP NEXT';
      timer = AppUtils.formatTimer(Duration(seconds: startSeconds - nowSeconds));
      detail = 'until ${AppUtils.formatClock(item.startMinutes)}'
          ' · ${AppUtils.formatDuration(task.durationMinutes)}';
    } else {
      label = isMeeting ? 'IN A MEETING' : 'SCHEDULED NOW';
      timer = AppUtils.formatTimer(
        Duration(seconds: (endSeconds - nowSeconds).clamp(0, endSeconds)),
      );
      detail = 'left · until ${AppUtils.formatClock(item.endMinutes)}';
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: _Shell(
        accent: !isMeeting,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: text.labelSmall?.copyWith(
                    color: isMeeting ? colors.textMuted : colors.accent,
                  ),
                ),
                if (task.isOutcome) ...[
                  const SizedBox(width: 8),
                  Text('· OUTCOME', style: text.labelSmall),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task.title,
              style: text.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Text(timer, style: text.displayLarge?.copyWith(color: timerColor)),
            const SizedBox(height: 4),
            Text(detail, style: text.bodyMedium),
            if (!isMeeting) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  if (!inProgress) ...[
                    Expanded(
                      child: FilledButton(
                        onPressed: widget.onStart,
                        child: const Text('Start'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onDone,
                        child: const Text('Done'),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: FilledButton(
                        onPressed: widget.onDone,
                        child: const Text('Done'),
                      ),
                    ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child, this.accent = false});

  final Widget child;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent ? colors.accent.withValues(alpha: 0.35) : colors.hairline,
        ),
      ),
      child: child,
    );
  }
}
