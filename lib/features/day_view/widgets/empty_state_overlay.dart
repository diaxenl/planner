import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Centered message shown when no tasks exist for the day.
///
/// The timeline remains visible behind this overlay. In later phases this
/// widget is conditionally shown based on the task list length.
class EmptyStateOverlay extends StatelessWidget {
  const EmptyStateOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note, size: 48, color: AppTheme.emptyStateColor),
            SizedBox(height: 8),
            Text(
              'No tasks yet — tap + to get started',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.emptyStateColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
