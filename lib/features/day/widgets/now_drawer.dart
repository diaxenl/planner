import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/scheduled_task.dart';
import '../../../models/task.dart';
import 'now_card.dart';

/// A slim Now bar pinned under the schedule that opens into a drawer.
///
/// Closed (the default each time the app starts): one line with the
/// current item, its timer, and its one main action — Start, Done, or
/// none for a meeting. On a day other than today, or with nothing left
/// on the plan, it shows the Outcomes count instead.
///
/// Open: [now] (the full Now card, today only) and [outcomes] (the day's
/// Outcomes). Stays open or closed as left until the app restarts.
class NowDrawer extends StatefulWidget {
  const NowDrawer({
    super.key,
    required this.isToday,
    required this.item,
    required this.outcomesDone,
    required this.outcomesTotal,
    required this.now,
    required this.outcomes,
    required this.onStart,
    required this.onDone,
    this.warning = false,
  });

  final bool isToday;

  /// The Now card's item (null: nothing left, or not today).
  final ScheduledTask? item;
  final int outcomesDone;
  final int outcomesTotal;

  /// Shown at the top of the open drawer; null hides it.
  final Widget? now;

  /// Shown below [now] in the open drawer.
  final Widget outcomes;
  final VoidCallback onStart;
  final VoidCallback onDone;

  /// Something needs a look (over the estimate, a meeting about to
  /// start, a task running through a meeting): the bar's words turn
  /// accent. The open drawer says what.
  final bool warning;

  /// Tallest the open drawer grows before it scrolls, as a share of the
  /// screen, so the schedule stays in view above it.
  static const double maxHeightFraction = 0.6;

  @override
  State<NowDrawer> createState() => _NowDrawerState();
}

class _NowDrawerState extends State<NowDrawer> {
  var _open = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(NowDrawer old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  /// The bar's timer ticks each second while it shows one.
  void _syncTicker() {
    final ticking = widget.isToday && widget.item != null;
    if (ticking && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!ticking) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: colors.accent.withValues(alpha: 0.45)),
        ),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: _open ? _drawer(context) : _bar(context),
      ),
    );
  }

  Widget _drawer(BuildContext context) {
    final colors = HyperColors.of(context);
    final maxHeight =
        MediaQuery.of(context).size.height * NowDrawer.maxHeightFraction;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Close',
          child: InkWell(
            key: const ValueKey('now-drawer-close'),
            onTap: _toggle,
            child: SizedBox(
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.now != null) ...[
                  widget.now!,
                  const SizedBox(height: 20),
                ],
                widget.outcomes,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bar(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final item = widget.isToday ? widget.item : null;
    final readout = item == null ? null : NowReadout.of(item, DateTime.now());
    final isMeeting = item?.task.type == TaskType.hard;
    final inProgress = item?.task.status == TaskStatus.inProgress;
    final attention = widget.warning || (readout?.overMinutes ?? 0) > 0;

    final String label;
    final String title;
    if (item != null) {
      label = readout!.label;
      title = item.task.title;
    } else {
      label = 'OUTCOMES';
      title = widget.outcomesTotal == 0
          ? 'None yet'
          : '${widget.outcomesDone} of ${widget.outcomesTotal} done';
    }

    return InkWell(
      key: const ValueKey('now-drawer-open'),
      onTap: _toggle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: inProgress ? colors.accent : colors.textMuted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item != null && item.task.isOutcome
                            ? '$label · OUTCOME'
                            : label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(
                          color: item != null && !isMeeting
                              ? colors.accent
                              : null,
                        ),
                      ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                    ],
                  ),
                ),
                if (readout != null) ...[
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        readout.timer,
                        // Fixed-width digits: the timer keeps its width as
                        // it ticks, so the label beside it doesn't jump.
                        style: text.titleLarge?.copyWith(
                          color: readout.overMinutes > 0 ? colors.accent : null,
                          fontFeatures: AppTheme.tabularFigures,
                        ),
                      ),
                      Text(
                        readout.short,
                        style: text.bodySmall?.copyWith(
                          color: attention ? colors.accent : null,
                        ),
                      ),
                    ],
                  ),
                ],
                if (item != null && !isMeeting) ...[
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: inProgress ? 'Done' : 'Start',
                    onPressed: inProgress ? widget.onDone : widget.onStart,
                    icon: Icon(inProgress ? Icons.check : Icons.play_arrow),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.keyboard_arrow_up,
                    color: colors.textSecondary,
                    semanticLabel: 'Open',
                  ),
                ),
              ],
            ),
          ),
          if (readout?.progress != null)
            NowProgress(value: readout!.progress!, height: 3),
        ],
      ),
    );
  }
}
