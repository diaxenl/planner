import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import 'widgets/empty_state_overlay.dart';

/// Scrollable timeline covering [AppConstants.dayStartHour] to
/// [AppConstants.dayEndHour].
///
/// Uses a [Stack] for slot-based absolute positioning. Hour labels and
/// dividers are placed at fixed pixel offsets so that future task cards
/// can be positioned using the same time → pixel mapping via
/// [AppUtils.timeToOffset].
class TimelineView extends StatelessWidget {
  const TimelineView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingXLarge),
      child: SizedBox(
        height: AppConstants.timelineHeight,
        child: Stack(
          children: [
            // Hour rows: labels + dividers
            for (int h = AppConstants.dayStartHour;
                h < AppConstants.dayEndHour;
                h++)
              _buildHourRow(context, h),

            // Empty state overlay (shown when there are no tasks).
            // In Phase 2+ this will be conditionally rendered.
            const EmptyStateOverlay(),

            // Task cards will be added here as Positioned children
            // in Phase 3 / Phase 4.
          ],
        ),
      ),
    );
  }

  Widget _buildHourRow(BuildContext context, int hour) {
    final top = AppUtils.timeToOffset(hour);
    final label = AppUtils.formatHourLabel(hour);
    final textTheme = Theme.of(context).textTheme;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: AppConstants.hourHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hour label in the left gutter
          SizedBox(
            width: AppConstants.timeGutterWidth,
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppConstants.paddingSmall,
                left: AppConstants.paddingMedium,
              ),
              child: Text(label, style: textTheme.bodySmall),
            ),
          ),
          // Divider line extending to the right edge
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppTheme.timelineDividerColor,
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
