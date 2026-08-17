import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/live_segment_engine.dart';

/// Real-time HUD banner displayed during an active outdoor run when crossing or targeting a live segment / Ghost Racer.
class LiveSegmentHud extends ConsumerWidget {
  const LiveSegmentHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segmentEngineState = ref.watch(liveSegmentEngineProvider);
    final effort = segmentEngineState.activeEffort;
    final ghost = segmentEngineState.ghostTelemetry;
    final selectedGhost = segmentEngineState.selectedGhostSegment;

    if (effort == null && selectedGhost == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Mode A: Approaching start of manually targeted Ghost Segment
    if (effort == null && selectedGhost != null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainerLow.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.neonCyan.withValues(alpha: 0.8),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonCyan.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('👻', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TARGET GHOST RACER READY',
                    maxLines: 1,
                    softWrap: false,
                    style: AppTypography.labelCaps(color: AppColors.neonCyan)
                        .copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    selectedGhost.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: AppTypography.cardTitle().copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${selectedGhost.formattedDistance} • PR: ${selectedGhost.formattedBestTime}',
                    maxLines: 1,
                    softWrap: false,
                    style: AppTypography.tinyLabel(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.neonCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'HEAD TO START 🚩',
                maxLines: 1,
                softWrap: false,
                style: AppTypography.labelCaps(color: AppColors.neonCyan)
                    .copyWith(fontSize: 9.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    // Mode B: Actively traversing segment with live Ghost comparison
    final isAhead = effort!.isAhead;
    final deltaColor = isAhead
        ? (isDark ? AppColors.primaryVolt : AppColors.lightPrimary)
        : AppColors.error;

    final formattedDistanceDelta = ghost != null
        ? ghost.formattedDistanceDelta
        : (isAhead ? '+0m' : '-0m');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
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
              const Text('👻', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GHOST RACER • LIVE SEGMENT',
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

              // Live Time & Distance Delta Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: deltaColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: deltaColor.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${effort.formattedDelta} ${isAhead ? 'AHEAD' : 'BEHIND'}',
                      maxLines: 1,
                      softWrap: false,
                      style:
                          AppTypography.labelCaps(color: deltaColor).copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      formattedDistanceDelta,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: deltaColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Dual Progress Bar (User Progress vs Ghost Progress)
          Stack(
            children: [
              // Ghost baseline progress track
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ghost?.ghostProgressFraction ?? effort.progressFraction,
                  backgroundColor: isDark
                      ? AppColors.darkSurfaceContainerHighest
                      : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.neonCyan.withValues(alpha: 0.4),
                  ),
                  minHeight: 8,
                ),
              ),
              // User real-time progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: effort.progressFraction,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(deltaColor),
                  minHeight: 8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 3: Elapsed Time vs PR Target
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'You: ${effort.formattedElapsed}',
                maxLines: 1,
                softWrap: false,
                style: AppTypography.bodySm(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Text(
                'Ghost PR: ${effort.segment.formattedBestTime} • ${(effort.progressFraction * 100).toInt()}%',
                maxLines: 1,
                softWrap: false,
                style: AppTypography.bodySm(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
