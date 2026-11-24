import 'dart:async';
import 'dart:math' as math;

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
/// - Meetings: shows time remaining / until start; no actions. If a task
///   is still running when the meeting starts ([running]), says so and
///   offers Pause.
/// - A running task with a meeting starting soon ([startingSoon]) warns.
/// - [item] null: an "all clear" message.
class NowCard extends StatefulWidget {
  const NowCard({
    super.key,
    required this.item,
    required this.hasAnyTasks,
    required this.onStart,
    required this.onDone,
    required this.onCancel,
    required this.onTap,
    required this.onReview,
    this.running,
    this.startingSoon,
    this.onPause,
    this.onPauseCurrent,
  });

  final ScheduledTask? item;

  /// A task still running while [item] (a meeting) is on.
  final ScheduledTask? running;

  /// A meeting or set-time item about to start while [item] is running.
  final ScheduledTask? startingSoon;

  /// Pauses [running].
  final VoidCallback? onPause;

  /// Pauses [item] while it runs past its estimate.
  final VoidCallback? onPauseCurrent;

  /// Whether the day has anything on it at all (picks the empty copy).
  final bool hasAnyTasks;
  final VoidCallback onStart;
  final VoidCallback onDone;
  final VoidCallback onCancel;
  final VoidCallback onTap;

  /// Shown as "Review your day" once nothing is left on the plan.
  final VoidCallback onReview;

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
            Text(
              widget.hasAnyTasks ? 'Nothing left on the plan.' : 'A clear day.',
              style: text.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              widget.hasAnyTasks
                  ? 'Capture anything new below.'
                  : 'Pick your outcomes to get started.',
              style: text.bodyMedium,
            ),
            if (widget.hasAnyTasks) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: widget.onReview,
                child: const Text('Review your day'),
              ),
            ],
          ],
        ),
      );
    }

    final task = item.task;
    final now = DateTime.now();
    final nowSeconds = now.hour * 3600 + now.minute * 60 + now.second;
    final isMeeting = task.type == TaskType.hard;
    final inProgress = task.status == TaskStatus.inProgress;
    final readout = NowReadout.of(item, now);
    final elapsedOver = readout.overMinutes;
    final label = readout.label;
    final timer = readout.timer;
    final detail = readout.detail;
    final timerColor = readout.overMinutes > 0
        ? colors.accent
        : colors.textPrimary;

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
                if (item.isSplit && !inProgress) ...[
                  const SizedBox(width: 8),
                  Text(
                    '· SESSION ${item.part} OF ${item.parts}',
                    style: text.labelSmall,
                  ),
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
            Text(timer, style: text.displaySmall?.copyWith(color: timerColor)),
            const SizedBox(height: 4),
            Text(detail, style: text.bodyMedium),
            if (readout.progress != null) ...[
              const SizedBox(height: 12),
              NowProgress(value: readout.progress!),
            ],
            if (inProgress &&
                elapsedOver > 0 &&
                widget.startingSoon == null) ...[
              const SizedBox(height: 12),
              // Pause is in the buttons below.
              const _Warning(text: 'Past your estimate — still on it?'),
            ],
            if (widget.startingSoon != null && inProgress) ...[
              const SizedBox(height: 12),
              _Warning(
                text:
                    '"${widget.startingSoon!.task.title}" starts '
                    '${_inMinutes(widget.startingSoon!.startMinutes * 60 - nowSeconds)}',
              ),
            ],
            if (widget.running != null && isMeeting) ...[
              const SizedBox(height: 12),
              _Warning(
                text: '"${widget.running!.task.title}" is still running',
                actionLabel: 'Pause',
                onAction: widget.onPause,
              ),
            ],
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
                  ] else ...[
                    Expanded(
                      child: FilledButton(
                        onPressed: widget.onDone,
                        child: const Text('Done'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: widget.onPauseCurrent,
                      child: const Text('Pause'),
                    ),
                  ],
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text("Won't do"),
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

/// What the Now card and the Now bar show for one item at a moment:
/// shared so the two always agree.
class NowReadout {
  const NowReadout({
    required this.label,
    required this.timer,
    required this.detail,
    required this.short,
    this.overMinutes = 0,
    this.progress,
  });

  /// - In progress: elapsed time (including earlier, paused runs) against
  ///   the estimate, and when it's planned to end.
  /// - Not started, ahead: countdown to its start.
  /// - Meeting under way: time left.
  /// - Planned for now but not started: its length; nothing ticks yet.
  factory NowReadout.of(ScheduledTask item, DateTime now) {
    final task = item.task;
    final nowSeconds = now.hour * 3600 + now.minute * 60 + now.second;
    final startSeconds = item.startMinutes * 60;
    final endSeconds = item.endMinutes * 60;
    final isMeeting = task.type == TaskType.hard;
    final estimate = AppUtils.formatDuration(task.durationMinutes);

    if (task.status == TaskStatus.inProgress) {
      final elapsed =
          now.difference(task.startedAt!) +
          Duration(minutes: task.actualDurationMinutes ?? 0);
      final over = elapsed.inMinutes - task.durationMinutes;
      return NowReadout(
        label: 'NOW',
        timer: AppUtils.formatTimer(elapsed),
        detail: over > 0
            ? '+${AppUtils.formatDuration(over)} over your $estimate estimate'
            : 'of $estimate · until ${AppUtils.formatClock(item.endMinutes)}',
        short: over > 0
            ? '+${AppUtils.formatDuration(over)} over'
            : 'of $estimate',
        overMinutes: math.max(0, over),
        progress: task.durationMinutes <= 0
            ? 1
            : (elapsed.inSeconds / (task.durationMinutes * 60)).clamp(0.0, 1.0),
      );
    }
    if (nowSeconds < startSeconds) {
      return NowReadout(
        label: isMeeting ? 'NEXT MEETING' : 'UP NEXT',
        timer: AppUtils.formatTimer(
          Duration(seconds: startSeconds - nowSeconds),
        ),
        detail:
            'until ${AppUtils.formatClock(item.startMinutes)}'
            ' · ${AppUtils.formatDuration(item.durationMinutes)}',
        short: 'at ${AppUtils.formatClock(item.startMinutes)}',
      );
    }
    if (isMeeting) {
      final length = math.max(1, endSeconds - startSeconds);
      return NowReadout(
        label: 'IN A MEETING',
        timer: AppUtils.formatTimer(
          Duration(seconds: (endSeconds - nowSeconds).clamp(0, endSeconds)),
        ),
        detail: 'left · until ${AppUtils.formatClock(item.endMinutes)}',
        short: 'left',
        progress: ((nowSeconds - startSeconds) / length).clamp(0.0, 1.0),
      );
    }
    return NowReadout(
      label: 'READY',
      timer: AppUtils.formatDuration(item.durationMinutes),
      detail: 'planned now · tap Start when you begin',
      short: 'planned now',
    );
  }

  final String label;

  /// The big number: elapsed, countdown, time left, or the length.
  final String timer;

  /// The line under the timer on the card.
  final String detail;

  /// A few words for the Now bar, beside the timer.
  final String short;

  /// Minutes past the estimate, for a running task (0 if not over).
  final int overMinutes;

  /// How far through (0–1), for a running task or a meeting under way.
  final double? progress;
}

/// A thin accent line showing how far through the current item is.
class NowProgress extends StatelessWidget {
  const NowProgress({super.key, required this.value, this.height = 4});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        color: colors.accent,
        backgroundColor: colors.hairline,
      ),
    );
  }
}

/// "in 4m", or "now" within the last minute.
String _inMinutes(int seconds) {
  final minutes = (seconds / 60).ceil();
  return minutes <= 0 ? 'now' : 'in ${AppUtils.formatDuration(minutes)}';
}

/// One accent-colored line, with an optional action.
class _Warning extends StatelessWidget {
  const _Warning({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final style = Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 18, color: colors.accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: style?.copyWith(color: colors.accent)),
        ),
        if (actionLabel != null)
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
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
          color: accent
              ? colors.accent.withValues(alpha: 0.35)
              : colors.hairline,
        ),
      ),
      child: child,
    );
  }
}
