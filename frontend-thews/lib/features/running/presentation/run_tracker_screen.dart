import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:latlong2/latlong.dart';

import '../../../core/animations/app_animations.dart';
import '../../../core/models/smartwatch_models.dart';
import '../../../core/services/audio_coach_service.dart';
import '../../../core/services/cadence_metronome_service.dart';
import '../../../core/services/gps_tracking_service.dart';
import '../../../core/services/smartwatch_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../challenges/presentation/challenges_provider.dart';
import '../domain/gap_calculator.dart';
import '../domain/live_segment_engine.dart';
import 'widgets/audio_coach_settings_sheet.dart';
import 'widgets/cadence_metronome_sheet.dart';
import 'widgets/heatmap_polyline_painter.dart';
import 'widgets/leaflet_route_map.dart';
import 'widgets/live_segment_hud.dart';
import 'widgets/live_segment_picker_sheet.dart';
import 'widgets/smartwatch_pairing_sheet.dart';

class RunTrackerScreen extends ConsumerStatefulWidget {
  const RunTrackerScreen({super.key});

  @override
  ConsumerState<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends ConsumerState<RunTrackerScreen> {
  bool _isHeatmapVisible = false;

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

    final audioCoach = ref.watch(audioCoachServiceProvider);
    final metronomeState = ref.watch(cadenceMetronomeProvider);
    final smartwatchState = ref.watch(smartwatchServiceProvider);
    final heatmapRoutes = ref.watch(heatmapRoutesProvider).valueOrNull ?? [];
    final segmentEngineState = ref.watch(liveSegmentEngineProvider);
    final challengesState = ref.watch(challengesProvider);
    final userCurrentLocation = runState.waypoints.isNotEmpty
        ? LatLng(runState.waypoints.last.latitude, runState.waypoints.last.longitude)
        : challengesState.userLocation;

    // Listen to GPS stream to feed Live Segment Detection & Ghost Racing + Voice Splits
    ref.listen<RunTrackingState>(runTrackingProvider, (previous, next) {
      if (next.isTracking && next.waypoints.isNotEmpty) {
        final last = next.waypoints.last;
        ref.read(liveSegmentEngineProvider.notifier).onLocationUpdate(
              latitude: last.latitude,
              longitude: last.longitude,
              timestamp: last.timestamp,
            );
      } else if (!next.isTracking && (previous?.isTracking ?? false)) {
        ref.read(liveSegmentEngineProvider.notifier).resetSegmentTracking();
      }

      // 1. Voice Coach Split Announcements
      if (next.isTracking &&
          next.splits.length > (previous?.splits.length ?? 0)) {
        final newSplit = next.splits.last;
        final currentHr = ref.read(smartwatchServiceProvider).currentBpm;
        ref.read(audioCoachServiceProvider.notifier).announceSplit(
              splitIndex: newSplit.splitIndex,
              totalDistanceMeters: next.distanceMeters,
              totalDurationSeconds: next.durationSeconds,
              splitPaceSecondsPerKm: newSplit.paceSecondsPerKm,
              currentPaceSecondsPerKm: next.currentPaceSecondsPerKm,
              currentHeartRateBpm: currentHr > 0 ? currentHr : null,
            );
      }

      // 2. Voice Workout State Milestones
      if (next.isTracking && !(previous?.isTracking ?? false)) {
        ref.read(audioCoachServiceProvider.notifier).announceActivityEvent('Activity started.');
      } else if (next.isPaused && !(previous?.isPaused ?? false)) {
        ref.read(audioCoachServiceProvider.notifier).announceActivityEvent('Activity paused.');
      } else if (!next.isPaused && (previous?.isPaused ?? false)) {
        ref.read(audioCoachServiceProvider.notifier).announceActivityEvent('Activity resumed.');
      }
    });

    // Listen to Smartwatch Heart Rate for HR Zone boundary voice alerts
    ref.listen<SmartwatchState>(smartwatchServiceProvider, (previous, next) {
      if (runState.isTracking && !runState.isPaused && next.currentBpm > 0) {
        ref.read(audioCoachServiceProvider.notifier).evaluateHeartRateZone(
              currentBpm: next.currentBpm,
              currentZone: next.currentZone,
            );
      }
    });

    final gradient = (runState.distanceMeters > 30 && runState.waypoints.length >= 2)
        ? GapCalculator.calculateGradient(
            elevationDeltaMeters: runState.elevationGainMeters,
            distanceDeltaMeters: runState.distanceMeters,
          )
        : 0.0;
    final gapPaceSeconds = GapCalculator.calculateGapPace(
      actualPaceSecondsPerKm: runState.currentPaceSecondsPerKm,
      gradient: gradient,
    );
    final formattedGapPace = GapCalculator.formatPace(gapPaceSeconds);

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'OUTDOOR TRACKER',
            style: AppTypography.sectionTitle(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              audioCoach.config.isVoiceEnabled
                  ? Icons.record_voice_over
                  : Icons.voice_over_off,
              color: audioCoach.config.isVoiceEnabled
                  ? (isDark ? AppColors.primaryVolt : AppColors.lightPrimary)
                  : null,
            ),
            tooltip: 'Audio Coach & Voice Splits',
            onPressed: () => AudioCoachSettingsSheet.show(context),
          ),
          IconButton(
            icon: Icon(
              Icons.timelapse,
              color: metronomeState.isPlaying
                  ? (isDark ? AppColors.primaryVolt : AppColors.lightPrimary)
                  : null,
            ),
            tooltip: 'Cadence Metronome',
            onPressed: () => CadenceMetronomeSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Loop Challenges & Trophies',
            onPressed: () => context.push('/challenges'),
          ),
          IconButton(
            icon: Icon(
              Icons.local_fire_department,
              color: _isHeatmapVisible
                  ? (isDark ? AppColors.chestAccent : const Color(0xFFE65100))
                  : null,
            ),
            tooltip: _isHeatmapVisible
                ? 'Hide Territory Heatmap'
                : 'Show Territory Heatmap',
            onPressed: () {
              setState(() {
                _isHeatmapVisible = !_isHeatmapVisible;
              });
            },
          ),
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
                        value: 'jog',
                        label: Text('JOG', maxLines: 1, softWrap: false),
                        icon: Icon(Icons.directions_run),
                      ),
                      ButtonSegment<String>(
                        value: 'cycle',
                        label: Text('CYCLE', maxLines: 1, softWrap: false),
                        icon: Icon(Icons.directions_bike),
                      ),
                    ],
                    selected: {
                      ['jog', 'cycle'].contains(runState.activityType)
                          ? runState.activityType
                          : 'jog'
                    },
                    onSelectionChanged: (selection) {
                      runNotifier.setActivityType(selection.first);
                    },
                  ),
                ),

              const SizedBox(height: AppSpacing.sm),

              // Quick Coach & Cadence Status Chips Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Ghost Racer / Live Segment Selector Chip
                    ActionChip(
                      avatar: const Text('👻', style: TextStyle(fontSize: 14)),
                      label: Text(
                        segmentEngineState.selectedGhostSegment != null
                            ? 'GHOST: ${segmentEngineState.selectedGhostSegment!.name}'
                            : 'GHOST RACER',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              segmentEngineState.selectedGhostSegment != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                          color: segmentEngineState.selectedGhostSegment != null
                              ? AppColors.neonCyan
                              : null,
                        ),
                      ),
                      backgroundColor:
                          segmentEngineState.selectedGhostSegment != null
                              ? AppColors.neonCyan.withValues(alpha: 0.15)
                              : null,
                      onPressed: () => LiveSegmentPickerSheet.show(context),
                    ),
                    const SizedBox(width: 8),

                    // Cadence Metronome Chip
                    ActionChip(
                      avatar: Icon(
                        Icons.timelapse,
                        size: 16,
                        color: metronomeState.isPlaying
                            ? (isDark
                                ? AppColors.primaryVolt
                                : AppColors.lightPrimary)
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                      ),
                      label: Text(
                        metronomeState.isPlaying
                            ? '${metronomeState.targetBpm} SPM'
                            : 'CADENCE',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: metronomeState.isPlaying
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: metronomeState.isPlaying
                              ? (isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary)
                              : null,
                        ),
                      ),
                      backgroundColor: metronomeState.isPlaying
                          ? (isDark
                              ? AppColors.primaryVolt.withValues(alpha: 0.15)
                              : AppColors.lightPrimary.withValues(alpha: 0.15))
                          : null,
                      onPressed: () => CadenceMetronomeSheet.show(context),
                    ),
                    const SizedBox(width: 8),

                    // Audio Voice Coach Chip
                    ActionChip(
                      avatar: Icon(
                        audioCoach.config.isVoiceEnabled
                            ? Icons.record_voice_over
                            : Icons.voice_over_off,
                        size: 16,
                        color: audioCoach.config.isVoiceEnabled
                            ? (isDark
                                ? AppColors.primaryVolt
                                : AppColors.lightPrimary)
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                      ),
                      label: Text(
                        audioCoach.config.isVoiceEnabled
                            ? (audioCoach.config.targetHrZone != null
                                ? 'VOICE (Z${audioCoach.config.targetHrZone!.index + 1})'
                                : 'VOICE ON')
                            : 'VOICE OFF',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: audioCoach.config.isVoiceEnabled
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: audioCoach.config.isVoiceEnabled
                              ? (isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary)
                              : null,
                        ),
                      ),
                      backgroundColor: audioCoach.config.isVoiceEnabled
                          ? (isDark
                              ? AppColors.primaryVolt.withValues(alpha: 0.15)
                              : AppColors.lightPrimary.withValues(alpha: 0.15))
                          : null,
                      onPressed: () => AudioCoachSettingsSheet.show(context),
                    ),
                    const SizedBox(width: 8),

                    // Live Heart Rate / Companion Wearable Status Chip
                    ActionChip(
                      avatar: Icon(
                        Icons.favorite,
                        size: 16,
                        color: smartwatchState.currentBpm > 0
                            ? AppColors.error
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                      ),
                      label: Text(
                        smartwatchState.currentBpm > 0
                            ? '${smartwatchState.currentBpm} BPM'
                            : (smartwatchState.status ==
                                    SmartwatchConnectionStatus.connected
                                ? 'WATCH READY'
                                : 'PAIR WATCH'),
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: smartwatchState.currentBpm > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      onPressed: () => SmartwatchPairingSheet.show(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Live Map Canvas & Live Segment HUD Overlay
              Expanded(
                child: Stack(
                  children: [
                    Container(
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
                          showHeatmapButton: true,
                          isHeatmapVisible: _isHeatmapVisible,
                          heatmapRoutes: heatmapRoutes,
                          ghostPosition:
                              segmentEngineState.ghostTelemetry?.ghostPosition,
                          activeGhostSegment:
                              segmentEngineState.selectedGhostSegment ??
                                  segmentEngineState.activeEffort?.segment,
                          currentLocation: userCurrentLocation,
                          onHeatmapTap: () {
                            setState(() {
                              _isHeatmapVisible = !_isHeatmapVisible;
                            });
                          },
                        ),
                      ),
                    ),
                    // Floating active Heatmap indicator badge
                    if (_isHeatmapVisible)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark
                                    ? AppColors.darkSurfaceContainerHighest
                                    : Colors.white)
                                .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (isDark
                                      ? AppColors.chestAccent
                                      : const Color(0xFFE65100))
                                  .withValues(alpha: 0.8),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                size: 14,
                                color: isDark
                                    ? AppColors.chestAccent
                                    : const Color(0xFFE65100),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                heatmapRoutes.isNotEmpty
                                    ? 'HEATMAP (${heatmapRoutes.length} ROUTES)'
                                    : 'HEATMAP ON',
                                style: AppTypography.tinyLabel(
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ).copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Live Segment / Ghost Racer HUD Banner (Positioned cleanly below the map)
              if (runState.isTracking ||
                  segmentEngineState.selectedGhostSegment != null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LiveSegmentHud(),
                ),

              const SizedBox(height: AppSpacing.sm),

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

                    // Lower Telemetry: Pace, Speed, Elevation, GAP & Steps Metrics
                    if (runState.activityType == 'cycle') ...[
                      // Cycle Mode: Hide Total Steps & rearrange in balanced single row with bicycle icon
                      Row(
                        children: [
                          Expanded(
                            child: _HudSubTile(
                              icon: Icons.directions_bike,
                              label: 'SPEED',
                              value: '${runState.formattedCurrentSpeed} km/h',
                              isDark: isDark,
                            ),
                          ),
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
                    ] else ...[
                      // Run / Walk Mode: Show Pace, Speed, Elevation, Steps & GAP
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
                              icon: Icons.bolt,
                              label: 'SPEED',
                              value: '${runState.formattedCurrentSpeed} km/h',
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _HudSubTile(
                              icon: Icons.filter_hdr_outlined,
                              label: 'ELEVATION',
                              value:
                                  '${runState.elevationGainMeters.toStringAsFixed(0)} m',
                              isDark: isDark,
                            ),
                          ),
                          Expanded(
                            child: _HudSubTile(
                              icon: Icons.trending_up,
                              label: 'GAP (GRADE ADJ)',
                              value: formattedGapPace,
                              isDark: isDark,
                            ),
                          ),
                          Expanded(
                            child: _HudSubTile(
                              icon: Icons.directions_walk,
                              label: 'TOTAL STEPS',
                              value: '${runState.totalSteps}',
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Tracking Control Buttons
              Row(
                children: [
                  if (!runState.isTracking)
                    Expanded(
                      child: BouncingButton(
                        onTap: () {
                          runNotifier.startTracking(
                            activityType: runState.activityType,
                          );
                        },
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
                      ),
                    )
                  else ...[
                    Expanded(
                      child: BouncingButton(
                        onTap: () {
                          if (runState.isPaused) {
                            runNotifier.resumeTracking();
                          } else {
                            runNotifier.pauseTracking();
                          }
                        },
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BouncingButton(
                        onTap: () async {
                          final activityId =
                              await runNotifier.finishAndSaveActivity();
                          if (activityId != null && context.mounted) {
                            context
                                .pushReplacement('/running/summary/$activityId');
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Activity discarded (under 10 meters recorded)',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
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
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Activity discarded (under 10 meters recorded)',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
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
