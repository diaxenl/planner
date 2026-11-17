import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../models/scheduled_task.dart';
import '../../../models/task.dart';

/// A placed entry on the timeline: which side-by-side [lane] it sits in,
/// out of [lanes] for its group of overlapping entries.
class TimelineBlock {
  const TimelineBlock(
    this.entry, {
    required this.lane,
    required this.lanes,
    this.overlaps = const [],
    this.overlapSpans = const [],
  });

  final ScheduledTask entry;
  final int lane;
  final int lanes;

  /// Titles of other open entries this one runs into. Finished, missed,
  /// and already-worked entries don't count.
  final List<String> overlaps;

  /// The stretches (start, end in minutes from midnight) where it runs
  /// into them, drawn striped.
  final List<(int, int)> overlapSpans;
}

/// An open stretch inside the workday, in minutes from midnight.
class TimelineGap {
  const TimelineGap(this.startMinutes, this.endMinutes);

  final int startMinutes;
  final int endMinutes;

  int get minutes => endMinutes - startMinutes;
}

/// Pure geometry for [ScheduleTimeline], kept apart so it can be tested
/// without a widget tree.
class TimelineLayout {
  const TimelineLayout({
    required this.startMinutes,
    required this.endMinutes,
    required this.blocks,
    required this.gaps,
  });

  /// The shown range, on whole hours: the workday, widened to take in
  /// anything placed outside it.
  final int startMinutes;
  final int endMinutes;

  final List<TimelineBlock> blocks;

  /// Free stretches of [minGapMinutes] or more inside the workday (from
  /// [nowMinutes] on, when given).
  final List<TimelineGap> gaps;

  static const minGapMinutes = 15;

  /// A set-time item whose time passed without a Start, as of
  /// [nowMinutes] (`null` = not today, never missed).
  static bool isMissed(ScheduledTask e, int? nowMinutes) =>
      nowMinutes != null &&
      !e.isPausedRun &&
      e.task.type == TaskType.pinned &&
      e.task.status == TaskStatus.notStarted &&
      e.task.pausedRuns.isEmpty &&
      e.endMinutes <= nowMinutes;

  static TimelineLayout of(
    List<ScheduledTask> entries, {
    required int dayStartHour,
    required int dayEndHour,
    int? nowMinutes,
  }) {
    final sorted = [...entries]
      ..sort((a, b) {
        final byStart = a.startMinutes.compareTo(b.startMinutes);
        return byStart != 0 ? byStart : b.endMinutes.compareTo(a.endMinutes);
      });

    var start = dayStartHour * 60;
    var end = dayEndHour * 60;
    for (final e in sorted) {
      start = math.min(start, e.startMinutes);
      end = math.max(end, e.endMinutes);
    }
    start = start ~/ 60 * 60;
    end = math.min(24 * 60, (end + 59) ~/ 60 * 60);

    return TimelineLayout(
      startMinutes: start,
      endMinutes: end,
      blocks: _lanes(sorted, nowMinutes),
      gaps: _gaps(
        sorted,
        from: math.max(dayStartHour * 60, nowMinutes ?? 0),
        to: dayEndHour * 60,
      ),
    );
  }

  /// Entries that overlap share the width: each takes the first lane
  /// that is free by its start; a group ends where nothing overlaps.
  static List<TimelineBlock> _lanes(
    List<ScheduledTask> sorted,
    int? nowMinutes,
  ) {
    final result = <TimelineBlock>[];
    var group = <(ScheduledTask, int)>[];
    var laneEnds = <int>[];
    var groupEnd = -1;

    bool open(ScheduledTask e) =>
        !e.isPausedRun &&
        e.task.status != TaskStatus.complete &&
        e.task.status != TaskStatus.cancelled &&
        !isMissed(e, nowMinutes);

    void closeGroup() {
      for (final (e, lane) in group) {
        final others = !open(e)
            ? const <ScheduledTask>[]
            : [
                for (final (o, _) in group)
                  if (o.task.id != e.task.id &&
                      open(o) &&
                      o.startMinutes < e.endMinutes &&
                      e.startMinutes < o.endMinutes)
                    o,
              ];
        result.add(
          TimelineBlock(
            e,
            lane: lane,
            lanes: laneEnds.length,
            overlaps: [for (final o in others) o.task.title],
            overlapSpans: [
              for (final o in others)
                (
                  math.max(e.startMinutes, o.startMinutes),
                  math.min(e.endMinutes, o.endMinutes),
                ),
            ],
          ),
        );
      }
      group = [];
      laneEnds = [];
    }

    for (final e in sorted) {
      if (e.startMinutes >= groupEnd) closeGroup();
      var lane = laneEnds.indexWhere((end) => end <= e.startMinutes);
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(e.endMinutes);
      } else {
        laneEnds[lane] = e.endMinutes;
      }
      group.add((e, lane));
      groupEnd = math.max(groupEnd, e.endMinutes);
    }
    closeGroup();
    return result;
  }

  static List<TimelineGap> _gaps(
    List<ScheduledTask> sorted, {
    required int from,
    required int to,
  }) {
    final gaps = <TimelineGap>[];
    var cursor = from;
    for (final e in sorted) {
      if (e.startMinutes > cursor) {
        gaps.add(TimelineGap(cursor, math.min(e.startMinutes, to)));
      }
      cursor = math.max(cursor, e.endMinutes);
      if (cursor >= to) break;
    }
    if (cursor < to) gaps.add(TimelineGap(cursor, to));
    return gaps.where((g) => g.minutes >= minGapMinutes).toList();
  }
}

/// The day's placed items as blocks on a vertical clock: height follows
/// duration, color follows kind (Meeting / Outcome / Other), free time in
/// the workday is labelled, and a line marks now on today. Tap a block to
/// open it.
class ScheduleTimeline extends StatefulWidget {
  const ScheduleTimeline({
    super.key,
    required this.entries,
    required this.current,
    required this.dayStartHour,
    required this.dayEndHour,
    required this.isToday,
    required this.onTap,
  });

  final List<ScheduledTask> entries;

  /// The Now card's item (that block is outlined).
  final ScheduledTask? current;
  final int dayStartHour;
  final int dayEndHour;

  /// Shows the now line and labels only the free time still ahead.
  final bool isToday;
  final ValueChanged<Task> onTap;

  /// Vertical pixels per minute (84 per hour): a 15-minute item still
  /// fits one line of text.
  static const pxPerMinute = 1.4;

  static const _gutter = 52.0;

  @override
  State<ScheduleTimeline> createState() => _ScheduleTimelineState();
}

class _ScheduleTimelineState extends State<ScheduleTimeline> {
  /// Moves the now line once a minute.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(ScheduleTimeline old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  void _syncTicker() {
    if (widget.isToday && _ticker == null) {
      _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!widget.isToday) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final nowMinutes = widget.isToday ? now.hour * 60 + now.minute : null;
    final layout = TimelineLayout.of(
      widget.entries,
      dayStartHour: widget.dayStartHour,
      dayEndHour: widget.dayEndHour,
      nowMinutes: nowMinutes,
    );
    const ppm = ScheduleTimeline.pxPerMinute;
    const gutter = ScheduleTimeline._gutter;
    double y(int minutes) => (minutes - layout.startMinutes) * ppm;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth - gutter;
        return SizedBox(
          // Room below the last line for its hour label.
          height: y(layout.endMinutes) + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (
                var m = layout.startMinutes;
                m <= layout.endMinutes;
                m += 60
              ) ...[
                Positioned(
                  left: gutter,
                  right: 0,
                  top: y(m),
                  child: Container(height: 1, color: colors.hairline),
                ),
                Positioned(
                  left: 0,
                  width: gutter - 8,
                  top: y(m) - 8,
                  child: Text(
                    _hourLabel(m),
                    style: text.bodySmall?.copyWith(
                      fontSize: 11,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ],
              for (final gap in layout.gaps)
                if (gap.minutes * ppm >= 18)
                  Positioned(
                    left: gutter + 12,
                    right: 0,
                    top: y(gap.startMinutes),
                    height: gap.minutes * ppm,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      // Background masks an hour line running through it.
                      child: ColoredBox(
                        color: colors.background,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '${AppUtils.formatDuration(gap.minutes)} free',
                            style: text.bodySmall?.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              for (final b in layout.blocks)
                Positioned(
                  left: gutter + 4 + trackWidth / b.lanes * b.lane,
                  width: trackWidth / b.lanes - 4,
                  top: y(b.entry.startMinutes) + 1,
                  height: math.max(4, b.entry.durationMinutes * ppm - 2),
                  child: _Block(
                    entry: b.entry,
                    overlaps: b.overlaps,
                    overlapSpans: b.overlapSpans,
                    missed: TimelineLayout.isMissed(b.entry, nowMinutes),
                    isCurrent:
                        !b.entry.isPausedRun &&
                        b.entry.task.id == widget.current?.task.id &&
                        b.entry.startMinutes == widget.current?.startMinutes,
                    onTap: () => widget.onTap(b.entry.task),
                  ),
                ),
              if (nowMinutes != null &&
                  nowMinutes >= layout.startMinutes &&
                  nowMinutes <= layout.endMinutes)
                Positioned(
                  key: const ValueKey('timeline-now'),
                  left: gutter - 4,
                  right: 0,
                  top: y(nowMinutes) - 4,
                  child: IgnorePointer(
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Container(height: 2, color: colors.accent),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// "9 AM", "12 PM", "12 AM" for midnight.
  static String _hourLabel(int minutes) {
    final h = minutes ~/ 60 % 24;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12 ${h < 12 ? 'AM' : 'PM'}';
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.entry,
    required this.overlaps,
    required this.overlapSpans,
    required this.missed,
    required this.isCurrent,
    required this.onTap,
  });

  final ScheduledTask entry;

  /// Open entries this one runs into, and where (see [TimelineBlock]).
  final List<String> overlaps;
  final List<(int, int)> overlapSpans;

  /// A set-time item whose time passed without a Start.
  final bool missed;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HyperColors.of(context);
    final text = Theme.of(context).textTheme;
    final task = entry.task;
    final isDone = task.status == TaskStatus.complete;
    final isCancelled = task.status == TaskStatus.cancelled;
    final pausedRun = entry.isPausedRun;
    final inProgress = !pausedRun && task.status == TaskStatus.inProgress;
    final isMeeting = task.type == TaskType.hard;
    final kind = isMeeting
        ? colors.meeting
        : task.isOutcome
        ? colors.accent
        : colors.other;
    final muted = isDone || isCancelled || missed || pausedRun;
    final height = entry.durationMinutes * ScheduleTimeline.pxPerMinute - 2;

    final when =
        '${AppUtils.formatClock(entry.startMinutes)} – '
        '${AppUtils.formatClock(entry.endMinutes)}';
    final detail = [
      if (missed)
        'Missed'
      else if (pausedRun && !isDone)
        'Worked ${AppUtils.formatDuration(entry.durationMinutes)}'
      else if (inProgress)
        'In progress'
      else
        AppUtils.formatDuration(entry.durationMinutes),
      if (entry.isSplit) '${entry.part}/${entry.parts}',
    ].join(' · ');
    // Spoken only: on screen the overlap is the striped stretch.
    final overlapNote = overlaps.isEmpty
        ? null
        : 'overlaps ${overlaps.join(', ')}';

    final titleStyle = text.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: muted ? colors.textMuted : colors.textPrimary,
      decoration: isCancelled ? TextDecoration.lineThrough : null,
    );
    final detailStyle = text.bodySmall?.copyWith(
      fontSize: 12,
      height: 1.2,
      color: inProgress || missed ? colors.accent : colors.textSecondary,
    );

    final title = Row(
      children: [
        if (isMeeting) ...[
          Icon(Icons.event, size: 13, color: kind),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        ),
      ],
    );
    // A short block has no second line, so the start time goes here.
    final trailing = isDone
        ? Icon(Icons.check, size: 14, color: colors.textMuted)
        : Text(
            '${AppUtils.formatClock(entry.startMinutes)} · $detail',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: detailStyle,
          );

    final Widget content;
    if (height >= 40) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: title),
              if (isDone) trailing,
            ],
          ),
          const SizedBox(height: 2),
          Text(
            isDone ? when : '$when · $detail',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: detailStyle,
          ),
        ],
      );
    } else if (height >= 16) {
      content = Row(
        children: [
          Expanded(child: title),
          const SizedBox(width: 8),
          // In a narrow (side-by-side) block both shrink, so the title
          // still shows.
          isDone ? trailing : Flexible(child: trailing),
        ],
      );
    } else {
      content = const SizedBox.shrink();
    }

    return Semantics(
      button: true,
      label: [task.title, when, detail, ?overlapNote].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              kind.withValues(alpha: muted ? 0.08 : 0.2),
              colors.surface,
            ),
            borderRadius: BorderRadius.circular(6),
            border: isCurrent || inProgress
                ? Border.all(color: colors.accent, width: 1.5)
                : missed
                ? Border.all(color: colors.accent.withValues(alpha: 0.6))
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Where it runs into something else: striped, behind the text.
              for (final (from, to) in overlapSpans)
                Positioned(
                  left: 0,
                  right: 0,
                  top:
                      (from - entry.startMinutes) *
                      ScheduleTimeline.pxPerMinute,
                  height: (to - from) * ScheduleTimeline.pxPerMinute,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _Stripes(colors.accent.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: muted ? kind.withValues(alpha: 0.4) : kind,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(6),
                      ),
                    ),
                  ),
                  Expanded(
                    // Text never spills out of a short block, even with large
                    // system font sizes.
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: height >= 40
                            ? Alignment.topLeft
                            : Alignment.centerLeft,
                        maxHeight: double.infinity,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            8,
                            height >= 40 ? 6 : 0,
                            8,
                            0,
                          ),
                          child: content,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diagonal stripes marking an overlap.
class _Stripes extends CustomPainter {
  const _Stripes(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    canvas.clipRect(Offset.zero & size);
    const gap = 7.0;
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Stripes old) => old.color != color;
}
