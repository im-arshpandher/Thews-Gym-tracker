import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/gps_tracking_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'widgets/leaflet_route_map.dart';

class RunTrackerScreen extends ConsumerStatefulWidget {
  const RunTrackerScreen({super.key});

  @override
  ConsumerState<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends ConsumerState<RunTrackerScreen> {
  @override
  void initState() {
    super.initState();
    // Check location permission & status on screen open without auto-starting activity
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final runNotifier = ref.read(runTrackingProvider.notifier);
      runNotifier.checkGpsStatusAndFetchLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final runState = ref.watch(runTrackingProvider);
    final runNotifier = ref.read(runTrackingProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'OUTDOOR TRACKER',
          style: AppTypography.sectionTitle(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Run History',
            onPressed: () => context.push('/running/history'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            children: [
              // GPS Permission Banner (Automatically removed when granted)
              if (!runState.hasLocationPermission &&
                  runState.permissionStatusMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainerHighest
                        : AppColors.lightSurfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.primaryVolt.withValues(alpha: 0.3)
                          : AppColors.lightPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.gps_fixed,
                        color: isDark
                            ? AppColors.primaryVolt
                            : AppColors.lightPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          runState.permissionStatusMessage!,
                          style: AppTypography.tinyLabel(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          maxLines: 2,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            runNotifier.requestLocationPermission(),
                        child: const Text('GRANT GPS',
                            maxLines: 1, softWrap: false),
                      ),
                    ],
                  ),
                ),

              // Activity Type Selector Segmented Button
              if (!runState.isTracking)
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<String>(
                        value: 'run',
                        label: Text('RUN', maxLines: 1, softWrap: false),
                        icon: Icon(Icons.directions_run),
                      ),
                      ButtonSegment<String>(
                        value: 'walk',
                        label: Text('WALK', maxLines: 1, softWrap: false),
                        icon: Icon(Icons.directions_walk),
                      ),
                      ButtonSegment<String>(
                        value: 'cycle',
                        label: Text('CYCLE', maxLines: 1, softWrap: false),
                        icon: Icon(Icons.directions_bike),
                      ),
                    ],
                    selected: {runState.activityType},
                    onSelectionChanged: (selection) {
                      runNotifier.setActivityType(selection.first);
                    },
                  ),
                ),

              const SizedBox(height: AppSpacing.md),

              // Live Map Canvas
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkOutline.withValues(alpha: 0.3)
                          : AppColors.lightOutline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: LeafletRouteMap(
                      waypoints: runState.waypoints,
                      isDark: isDark,
                      isTracking: runState.isTracking,
                      headingDegrees: runState.headingDegrees,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Real-time Telemetry HUD Panel
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainerHigh
                      : AppColors.lightSurfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: runState.isPaused
                        ? AppColors.error
                        : (isDark
                            ? AppColors.darkOutline.withValues(alpha: 0.3)
                            : AppColors.lightOutline.withValues(alpha: 0.3)),
                  ),
                ),
                child: Column(
                  children: [
                    if (runState.isPaused)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause_circle_filled,
                                color: AppColors.error, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'ACTIVITY PAUSED',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Top Telemetry Metrics
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                runState.formattedDistanceKm,
                                style: AppTypography.displayHero(
                                  color: isDark
                                      ? AppColors.primaryVolt
                                      : AppColors.lightPrimary,
                                ),
                              ),
                              Text(
                                'DISTANCE (KM)',
                                style: AppTypography.tinyLabel(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 48,
                          color: isDark
                              ? AppColors.darkOutline.withValues(alpha: 0.2)
                              : AppColors.lightOutline.withValues(alpha: 0.2),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                runState.formattedDuration,
                                style: AppTypography.displayHero(
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                'TIME',
                                style: AppTypography.tinyLabel(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // Lower Pace & Elevation Metrics
                    Row(
                      children: [
                        Expanded(
                          child: _HudSubTile(
                            icon: Icons.speed,
                            label: 'CURRENT PACE',
                            value: '${runState.formattedCurrentPace} /km',
                            isDark: isDark,
                          ),
                        ),
                        Expanded(
                          child: _HudSubTile(
                            icon: Icons.av_timer,
                            label: 'AVG PACE',
                            value: '${runState.formattedAvgPace} /km',
                            isDark: isDark,
                          ),
                        ),
                        Expanded(
                          child: _HudSubTile(
                            icon: Icons.filter_hdr_outlined,
                            label: 'ELEVATION',
                            value:
                                '${runState.elevationGainMeters.toStringAsFixed(0)} m',
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Tracking Control Buttons
              Row(
                children: [
                  if (!runState.isTracking)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: isDark
                              ? AppColors.primaryVolt
                              : AppColors.lightPrimary,
                          foregroundColor: isDark
                              ? AppColors.darkBackground
                              : Colors.white,
                        ),
                        onPressed: () {
                          runNotifier.startTracking(
                            activityType: runState.activityType,
                          );
                        },
                        icon: const Icon(Icons.play_arrow, size: 24),
                        label: const Text(
                          'START ACTIVITY',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          if (runState.isPaused) {
                            runNotifier.resumeTracking();
                          } else {
                            runNotifier.pauseTracking();
                          }
                        },
                        icon: Icon(
                          runState.isPaused ? Icons.play_arrow : Icons.pause,
                          size: 24,
                        ),
                        label: Text(
                          runState.isPaused ? 'RESUME' : 'PAUSE',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          final activityId =
                              await runNotifier.finishAndSaveActivity();
                          if (activityId != null && context.mounted) {
                            context
                                .pushReplacement('/running/summary/$activityId');
                          }
                        },
                        icon: const Icon(Icons.stop, size: 24),
                        label: const Text(
                          'FINISH RUN',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudSubTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _HudSubTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.bodyLg(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ).copyWith(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: AppTypography.tinyLabel(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          maxLines: 1,
          softWrap: false,
        ),
      ],
    );
  }
}
