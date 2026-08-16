import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/live_segment_engine.dart';

/// Modal bottom sheet allowing athletes to choose a Live Segment and race against a Ghost PR.
class LiveSegmentPickerSheet extends ConsumerWidget {
  const LiveSegmentPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const LiveSegmentPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final segmentState = ref.watch(liveSegmentEngineProvider);
    final segments = segmentState.availableSegments;
    final activeGhost = segmentState.selectedGhostSegment;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainer
            : AppColors.lightSurfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkOutline.withValues(alpha: 0.4)
                    : AppColors.lightOutline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.neonCyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('👻', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIVE SEGMENTS & GHOST RACER',
                          style: AppTypography.cardTitle(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ).copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Select a segment to race against your Ghost PR',
                          style: AppTypography.tinyLabel(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Active Ghost Status Card
            if (activeGhost != null)
              Container(
                margin: const EdgeInsets.all(AppSpacing.base),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.neonCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.neonCyan.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Text('👻', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TARGET GHOST RACER ACTIVE',
                            style: AppTypography.labelCaps(
                              color: AppColors.neonCyan,
                            ).copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            softWrap: false,
                          ),
                          Text(
                            activeGhost.name,
                            style: AppTypography.bodyLg(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ).copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${activeGhost.formattedDistance} • Target PR: ${activeGhost.formattedBestTime}',
                            style: AppTypography.bodySm(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ).copyWith(fontSize: 12),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      onPressed: () {
                        ref
                            .read(liveSegmentEngineProvider.notifier)
                            .clearGhostSegment();
                      },
                      child: const Text(
                        'CLEAR',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
              ),

            // Segments List
            Expanded(
              child: segments.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              size: 48,
                              color: isDark
                                  ? AppColors.darkOutline
                                  : AppColors.lightOutline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Segments Created Yet',
                              style: AppTypography.headlineSm(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                              maxLines: 1,
                              softWrap: false,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Open any completed workout in Run Summary to create custom route segments and ghost challenges.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySm(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.base,
                        vertical: 8,
                      ),
                      itemCount: segments.length,
                      separatorBuilder: (ctx, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final seg = segments[index];
                        final isSelected = activeGhost?.id == seg.id;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.neonCyan.withValues(alpha: 0.1)
                                : (isDark
                                    ? AppColors.darkSurfaceContainerHighest
                                    : Colors.white),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.neonCyan
                                  : (isDark
                                      ? AppColors.darkOutline
                                          .withValues(alpha: 0.2)
                                      : AppColors.lightOutline
                                          .withValues(alpha: 0.2)),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: (isDark
                                          ? AppColors.primaryVolt
                                          : AppColors.lightPrimary)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.navigation_rounded,
                                  size: 20,
                                  color: isDark
                                      ? AppColors.primaryVolt
                                      : AppColors.lightPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      seg.name,
                                      style: AppTypography.cardTitle(
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary,
                                      ).copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          seg.formattedDistance,
                                          style: AppTypography.bodySm(
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary,
                                          ).copyWith(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          softWrap: false,
                                        ),
                                        const SizedBox(width: 8),
                                        Text('•',
                                            style: TextStyle(
                                                color: isDark
                                                    ? AppColors.darkTextSecondary
                                                    : AppColors
                                                        .lightTextSecondary)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'PR: ${seg.formattedBestTime}',
                                          style: AppTypography.bodySm(
                                            color: isDark
                                                ? AppColors.primaryVolt
                                                : AppColors.lightPrimary,
                                          ).copyWith(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          softWrap: false,
                                        ),
                                        if (seg.elevationGainMeters > 0) ...[
                                          const SizedBox(width: 8),
                                          Text('•',
                                              style: TextStyle(
                                                  color: isDark
                                                      ? AppColors
                                                          .darkTextSecondary
                                                      : AppColors
                                                          .lightTextSecondary)),
                                          const SizedBox(width: 8),
                                          Text(
                                            '+${seg.elevationGainMeters.toInt()}m',
                                            style: AppTypography.bodySm(
                                              color: isDark
                                                  ? AppColors.darkTextSecondary
                                                  : AppColors
                                                      .lightTextSecondary,
                                            ).copyWith(fontSize: 12),
                                            maxLines: 1,
                                            softWrap: false,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected
                                      ? AppColors.neonCyan
                                      : (isDark
                                          ? AppColors.primaryVolt
                                          : AppColors.lightPrimary),
                                  foregroundColor: isSelected
                                      ? Colors.black
                                      : (isDark
                                          ? AppColors.primaryVoltOn
                                          : Colors.white),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  ref
                                      .read(liveSegmentEngineProvider.notifier)
                                      .selectGhostSegment(
                                          isSelected ? null : seg);
                                  Navigator.of(context).pop();
                                },
                                child: Text(
                                  isSelected ? 'UNSELECT' : 'RACE GHOST',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
