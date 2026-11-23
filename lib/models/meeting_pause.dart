import 'task.dart';

/// A running task paused by a meeting, or resumed after one: what the day
/// screen tells the user (with Undo).
class MeetingPause {
  const MeetingPause({
    required this.before,
    required this.after,
    required this.meetingTitle,
    required this.meetingIds,
  });

  /// The task as it was before the meeting paused or resumed it.
  final Task before;

  /// The task as it is now.
  final Task after;

  /// The last meeting that paused it, if it was paused in this check.
  final String? meetingTitle;

  /// Every meeting that paused it in this check (Undo keeps it running
  /// through them).
  final Set<String> meetingIds;

  /// Whether it is running again (the meeting is over).
  bool get resumed => after.status == TaskStatus.inProgress;
}
