import 'package:flutter/material.dart';
import 'timeline_view.dart';
import 'widgets/day_header.dart';

/// Primary screen — displays a single day's timeline.
///
/// This is a thin composition of [DayHeader], [TimelineView], and a FAB.
/// All layout and rendering logic lives in the child widgets.
class DayScreen extends StatelessWidget {
  const DayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DayHeader(date: now),
            const Expanded(child: TimelineView()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Non-functional until Phase 3.
        },
        tooltip: 'Add task',
        child: const Icon(Icons.add),
      ),
    );
  }
}
