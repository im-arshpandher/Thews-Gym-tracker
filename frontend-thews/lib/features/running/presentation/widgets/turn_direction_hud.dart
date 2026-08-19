import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/turn_navigation_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Floating Turn-by-Turn Navigation HUD for runners with audio direction indicators.
class TurnDirectionHud extends ConsumerWidget {
  const TurnDirectionHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(turnNavigationProvider);
    final navNotifier = ref.read(turnNavigationProvider.notifier);

    if (!navState.isNavigating || navState.activeCourse == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nextCue = navState.nextCue;
    final upcomingCue = navState.upcomingCueAfterNext;
    final isOffCourse = navState.isOffCourse;

    final distanceStr = _formatDistance(navState.distanceToNextCueMeters);
    final remainingStr = _formatDistance(navState.remainingDistanceMeters);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isOffCourse
            ? (isDark ? const Color(0xFF2C0B0E) : const Color(0xFFFFECEE))
            : (isDark
                ? AppColors.darkSurfaceContainerHighest.withValues(alpha: 0.95)
                : AppColors.lightSurfaceContainerLowest.withValues(alpha: 0.95)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOffCourse
              ? AppColors.error
              : (isDark ? AppColors.darkOutlineVariant : AppColors.lightOutlineVariant),
          width: isOffCourse ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isOffCourse
                ? AppColors.error.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Off-Course Caution Banner (when strayed > 25m)
          if (isOffCourse)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: const BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'OFF COURSE • ${navState.crossTrackDistanceMeters.toInt()}m from route',
                      style: AppTypography.tinyLabel(color: Colors.white).copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text(
                    'Follow line on map',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              ),
            ),

          // 2. Primary Direction Row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                // Direction Icon Glyph Pill
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isOffCourse
                        ? AppColors.error.withValues(alpha: 0.15)
                        : (isDark
                            ? AppColors.chestAccent.withValues(alpha: 0.18)
                            : AppColors.chestAccent.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isOffCourse
                          ? AppColors.error
                          : AppColors.chestAccent,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    nextCue?.type.icon ?? Icons.navigation_rounded,
                    color: isOffCourse ? AppColors.error : AppColors.chestAccent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),

                // Distance + Turn Instruction
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            distanceStr,
                            style: AppTypography.cardTitle(
                              color: isOffCourse
                                  ? AppColors.error
                                  : (isDark ? Colors.white : Colors.black87),
                            ).copyWith(fontWeight: FontWeight.w800),
                            maxLines: 1,
                            softWrap: false,
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceContainerHigh
                                  : AppColors.lightSurfaceContainerHigh,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              nextCue?.type.shortName ?? 'Course',
                              style: AppTypography.tinyLabel(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ).copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nextCue?.instruction ?? 'Follow route ahead',
                        style: AppTypography.bodySm(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (upcomingCue != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              upcomingCue.type.icon,
                              size: 12,
                              color: isDark
                                  ? AppColors.darkOutline
                                  : AppColors.lightOutline,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Then: ${upcomingCue.instruction}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? AppColors.darkOutline
                                      : AppColors.lightOutline,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Voice Mute & Exit Navigation Buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        navState.isVoiceMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        size: 20,
                        color: navState.isVoiceMuted
                            ? AppColors.lightOutline
                            : AppColors.chestAccent,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: navState.isVoiceMuted ? 'Unmute voice' : 'Mute voice',
                      onPressed: navNotifier.toggleVoiceMute,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.lightOutline,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'Stop navigation',
                      onPressed: navNotifier.stopCourse,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Bottom Progress Bar & Course Remaining Tracker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: navState.courseProgressRatio,
                      minHeight: 4,
                      backgroundColor: isDark
                          ? AppColors.darkOutlineVariant.withValues(alpha: 0.4)
                          : AppColors.lightOutlineVariant.withValues(alpha: 0.5),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOffCourse ? AppColors.error : AppColors.chestAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$remainingStr remaining',
                  style: AppTypography.tinyLabel(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ).copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  softWrap: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDistance(double meters) {
    if (meters <= 0) return '0 m';
    if (meters >= 1000) {
      return '${(meters / 1000.0).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }
}
