import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/live_segment_engine.dart';

/// Real-time HUD banner displayed during an active outdoor run when crossing a live segment.
class LiveSegmentHud extends ConsumerWidget {
  const LiveSegmentHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segmentEngineState = ref.watch(liveSegmentEngineProvider);
    final effort = segmentEngineState.activeEffort;

    if (effort == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isAhead = effort.isAhead;
    final deltaColor = isAhead
        ? (isDark ? AppColors.primaryVolt : AppColors.lightPrimary)
        : AppColors.error;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLow.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: deltaColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: deltaColor.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Segment Name & Live Delta Badge
          Row(
            children: [
              Icon(Icons.flag_circle, size: 20, color: deltaColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE SEGMENT',
                      maxLines: 1,
                      softWrap: false,
                      style: AppTypography.labelCaps(color: deltaColor).copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      effort.segment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: AppTypography.cardTitle().copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Live Time Delta Badge (e.g. -2.4s Ahead)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: deltaColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: deltaColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${effort.formattedDelta} ${isAhead ? 'AHEAD' : 'BEHIND'}',
                  maxLines: 1,
                  softWrap: false,
                  style: AppTypography.labelCaps(color: deltaColor).copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Progress Bar toward segment finish line
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: effort.progressFraction,
              backgroundColor: isDark
                  ? AppColors.darkSurfaceContainerHighest
                  : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(deltaColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),

          // Row 3: Elapsed Time vs PR Target
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Elapsed: ${effort.formattedElapsed}',
                maxLines: 1,
                softWrap: false,
                style: AppTypography.bodySm(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ).copyWith(fontSize: 11),
              ),
              Text(
                'PR: ${effort.segment.formattedBestTime} • ${(effort.progressFraction * 100).toInt()}%',
                maxLines: 1,
                softWrap: false,
                style: AppTypography.bodySm(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
