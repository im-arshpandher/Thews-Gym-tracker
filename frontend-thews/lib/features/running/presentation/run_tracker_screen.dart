import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/audio_coach_service.dart';
import '../../../core/services/gps_tracking_service.dart';
import '../../../core/services/smartwatch_sync_service.dart';
import '../../../core/services/turn_navigation_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../challenges/domain/challenge_models.dart';
import '../../challenges/presentation/challenges_provider.dart';
import '../domain/gap_calculator.dart';
import '../domain/live_segment_engine.dart';
import 'widgets/audio_coach_settings_sheet.dart';
import 'widgets/cadence_metronome_sheet.dart';
import 'widgets/course_director_sheet.dart';
import 'widgets/heatmap_polyline_painter.dart';
import 'widgets/leaflet_route_map.dart';
import 'widgets/live_segment_hud.dart';
import 'widgets/live_segment_picker_sheet.dart';
import 'widgets/smartwatch_pairing_sheet.dart';
import 'widgets/turn_direction_hud.dart';

class RunTrackerScreen extends ConsumerStatefulWidget {
  const RunTrackerScreen({super.key});

  @override
  ConsumerState<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends ConsumerState<RunTrackerScreen>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  AnimationController? _rotationAnimController;
  bool _isHeatmapVisible = false;
  bool _isHudExpanded = false;
  bool _isSheetExpanded = true;
  bool _isTargetCardDismissed = false;
  bool _isLiveLocationShared = false;
  int _currentLapNumber = 1;
  int _lastLapSeconds = 0;
  double _lastLapDistanceMeters = 0;
  LocalChallenge? _selectedChallenge;
  String _selectedWorkoutGoal = 'Conversational Recovery (1 km • 6:00/km)';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveSegmentEngineProvider.notifier).clearGhostSegment();
      final runNotifier = ref.read(runTrackingProvider.notifier);
      runNotifier.checkGpsStatusAndFetchLocation();
    });
  }

  @override
  void dispose() {
    _rotationAnimController?.stop();
    _rotationAnimController?.dispose();
    _rotationAnimController = null;
    _mapController.dispose();
    super.dispose();
  }

  String _getCardinalDirection(double heading) {
    final normalized = (heading % 360 + 360) % 360;
    if (normalized >= 337.5 || normalized < 22.5) return 'N';
    if (normalized >= 22.5 && normalized < 67.5) return 'NE';
    if (normalized >= 67.5 && normalized < 112.5) return 'E';
    if (normalized >= 112.5 && normalized < 157.5) return 'SE';
    if (normalized >= 157.5 && normalized < 202.5) return 'S';
    if (normalized >= 202.5 && normalized < 247.5) return 'SW';
    if (normalized >= 247.5 && normalized < 292.5) return 'W';
    return 'NW';
  }

  void _orientMapToNorth() {
    try {
      final currentRotation = _mapController.camera.rotation;
      // If already facing north within small epsilon, provide tactile feedback
      if ((currentRotation % 360).abs() < 0.3) {
        HapticFeedback.selectionClick();
        return;
      }

      // Calculate shortest angular path to 0.0°
      double diff = (0.0 - currentRotation) % 360;
      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360;
      final targetRotation = currentRotation + diff;

      _rotationAnimController?.stop();
      _rotationAnimController?.dispose();

      final controller = AnimationController(
        duration: const Duration(milliseconds: 550),
        vsync: this,
      );
      _rotationAnimController = controller;

      final animation = CurvedAnimation(
        parent: controller,
        curve: Curves.fastOutSlowIn,
      );

      final tween = Tween<double>(begin: currentRotation, end: targetRotation);

      controller.addListener(() {
        try {
          _mapController.rotate(tween.evaluate(animation));
        } catch (e) {
          debugPrint('Animated map rotation notice: $e');
        }
      });

      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
          if (_rotationAnimController == controller) {
            controller.dispose();
            _rotationAnimController = null;
          }
        }
      });

      HapticFeedback.mediumImpact();
      controller.forward();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.explore_rounded, color: AppColors.chestAccent, size: 18),
              SizedBox(width: 8),
              Text('Re-orienting map to True North (0.0°)...', maxLines: 1, softWrap: false),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error animating map to North: $e');
    }
  }

  void _recordLapSplit(RunTrackingState runState) {
    setState(() {
      _currentLapNumber++;
      _lastLapSeconds = runState.durationSeconds;
      _lastLapDistanceMeters = runState.distanceMeters;
    });
    ref.read(audioCoachServiceProvider.notifier).announceActivityEvent(
          'Lap $_currentLapNumber. Distance: ${runState.formattedDistanceKm} kilometers.',
        );
  }

  Future<void> _handleRouteSelection() async {
    if (_selectedChallenge != null) {
      // Show modal to either clear the route or switch to another route
      final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(ctx).brightness == Brightness.dark
                ? AppColors.darkSurfaceContainerHigh
                : AppColors.lightSurfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.darkOutlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.close_rounded, color: AppColors.error),
                title: const Text('Clear Route (Run Without Route)', maxLines: 1, softWrap: false),
                subtitle: const Text('Remove route circuit and run freely', maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(ctx, 'clear'),
              ),
              ListTile(
                leading: const Icon(Icons.alt_route_rounded, color: AppColors.chestAccent),
                title: const Text('Change Selected Route', maxLines: 1, softWrap: false),
                subtitle: Text('Currently: ${_selectedChallenge!.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(ctx, 'change'),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;
      if (action == 'clear') {
        setState(() {
          _selectedChallenge = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route cleared. Free Run mode active.'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (action == 'change') {
        final challenge = await context.push<LocalChallenge>('/challenges');
        if (challenge != null && mounted) {
          setState(() {
            _selectedChallenge = challenge;
            _isTargetCardDismissed = false;
          });
        }
      }
    } else {
      final challenge = await context.push<LocalChallenge>('/challenges');
      if (challenge != null && mounted) {
        setState(() {
          _selectedChallenge = challenge;
          _isTargetCardDismissed = false;
        });
      }
    }
  }

  void _showSportSelectorSheet(BuildContext context, RunTrackingState runState, RunTrackingNotifier runNotifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(ctx).brightness == Brightness.dark
              ? AppColors.darkSurfaceContainerHigh
              : AppColors.lightSurfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.darkOutlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'SELECT ACTIVITY SPORT',
              style: AppTypography.sectionTitle(
                color: Theme.of(ctx).brightness == Brightness.dark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              maxLines: 1,
              softWrap: false,
            ),
            const SizedBox(height: 12),
            _buildSportOptionTile(
              ctx: ctx,
              title: 'Outdoor Run',
              subtitle: 'GPS pace, cadence, HR zones, and live splits',
              icon: Icons.directions_run_rounded,
              isSelected: runState.activityType == 'jog',
              onTap: () {
                runNotifier.setActivityType('jog');
                Navigator.pop(ctx);
                ref.read(audioCoachServiceProvider.notifier).announceActivityEvent('Outdoor Running mode selected.');
              },
            ),
            _buildSportOptionTile(
              ctx: ctx,
              title: 'Outdoor Cycling',
              subtitle: 'Speed (km/h), elevation climb, and power metrics',
              icon: Icons.directions_bike_rounded,
              isSelected: runState.activityType == 'cycle',
              onTap: () {
                runNotifier.setActivityType('cycle');
                Navigator.pop(ctx);
                ref.read(audioCoachServiceProvider.notifier).announceActivityEvent('Cycling mode selected.');
              },
            ),
            _buildSportOptionTile(
              ctx: ctx,
              title: 'Power Walk / Hike',
              subtitle: 'Step count, active calorie burn, and trail altitude',
              icon: Icons.directions_walk_rounded,
              isSelected: runState.activityType == 'walk',
              onTap: () {
                runNotifier.setActivityType('walk');
                Navigator.pop(ctx);
                ref.read(audioCoachServiceProvider.notifier).announceActivityEvent('Power Walk mode selected.');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSportOptionTile({
    required BuildContext ctx,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.chestAccent : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.chestAccent : AppColors.darkOutlineVariant,
          ),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : AppColors.chestAccent,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
        maxLines: 1,
        softWrap: false,
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.chestAccent)
          : null,
      onTap: onTap,
    );
  }

  void _showAiCoachTargetSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(ctx).brightness == Brightness.dark
              ? AppColors.darkSurfaceContainerHigh
              : AppColors.lightSurfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.darkOutlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.chestAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'THEWS AI RUN TARGETS',
                  style: AppTypography.sectionTitle(
                    color: Theme.of(ctx).brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  softWrap: false,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTargetGoalTile(
              ctx: ctx,
              title: 'Conversational Recovery',
              cue: '1 km at a conversational pace (Zone 2 HR)',
              distance: '1.0 km',
              icon: Icons.favorite_border_rounded,
              onTap: () {
                setState(() {
                  _selectedWorkoutGoal = 'Conversational Recovery (1 km • 6:00/km)';
                  _isTargetCardDismissed = false;
                });
                Navigator.pop(ctx);
                ref.read(audioCoachServiceProvider.notifier).announceActivityEvent('Goal set: 1 km recovery pace.');
              },
            ),
            _buildTargetGoalTile(
              ctx: ctx,
              title: '5K Tempo Interval',
              cue: '5 km steady tempo workout at 5:15 /km target',
              distance: '5.0 km',
              icon: Icons.bolt_rounded,
              onTap: () {
                setState(() {
                  _selectedWorkoutGoal = '5K Tempo Interval (5 km • 5:15/km)';
                  _isTargetCardDismissed = false;
                });
                Navigator.pop(ctx);
                ref.read(audioCoachServiceProvider.notifier).announceActivityEvent('Goal set: 5 km tempo interval.');
              },
            ),
            _buildTargetGoalTile(
              ctx: ctx,
              title: 'High-Cadence Speed Split',
              cue: '3 km progressive interval at 180 SPM cadence',
              distance: '3.0 km',
              icon: Icons.timer_rounded,
              onTap: () {
                setState(() {
                  _selectedWorkoutGoal = 'High-Cadence Speed Split (3 km • 180 SPM)';
                  _isTargetCardDismissed = false;
                });
                Navigator.pop(ctx);
                ref.read(audioCoachServiceProvider.notifier).announceActivityEvent('Goal set: High cadence speed split.');
              },
            ),
            _buildTargetGoalTile(
              ctx: ctx,
              title: 'Locality Challenge Route',
              cue: 'Select a verified local running circuit from map',
              distance: 'Circuit',
              icon: Icons.alt_route_rounded,
              onTap: () {
                Navigator.pop(ctx);
                _handleRouteSelection();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetGoalTile({
    required BuildContext ctx,
    required String title,
    required String cue,
    required String distance,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.chestAccent.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.chestAccent, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, softWrap: false),
      subtitle: Text(cue, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.chestAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          distance,
          style: const TextStyle(
            color: AppColors.chestAccent,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          maxLines: 1,
          softWrap: false,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showGpsDiagnosticsSheet(BuildContext context, RunTrackingState runState, RunTrackingNotifier runNotifier, LatLng? location) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(ctx).brightness == Brightness.dark
              ? AppColors.darkSurfaceContainerHigh
              : AppColors.lightSurfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.darkOutlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.signal_cellular_alt_rounded,
                  color: runState.hasLocationPermission ? AppColors.cardioAccent : AppColors.error,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'GPS DIAGNOSTICS & TELEMETRY',
                  style: AppTypography.sectionTitle(
                    color: Theme.of(ctx).brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  softWrap: false,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildDiagnosticRow(
              label: 'GPS Satellite Fix',
              value: runState.hasLocationPermission ? '3D High Precision (Locked)' : 'Offline / No Signal',
              isGood: runState.hasLocationPermission,
            ),
            _buildDiagnosticRow(
              label: 'Coordinates',
              value: location != null
                  ? '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}'
                  : 'Acquiring latitude & longitude...',
              isGood: location != null,
            ),
            _buildDiagnosticRow(
              label: 'Elevation Altitude',
              value: '${runState.elevationGainMeters.toStringAsFixed(1)} m above sea level',
              isGood: true,
            ),
            _buildDiagnosticRow(
              label: 'Compass Bearing',
              value: '${runState.headingDegrees.toStringAsFixed(0)}° (${_getCardinalDirection(runState.headingDegrees)})',
              isGood: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.chestAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text(
                  'RE-CALIBRATE GPS SENSORS',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  softWrap: false,
                ),
                onPressed: () {
                  runNotifier.checkGpsStatusAndFetchLocation();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('GPS hardware status queried and re-calibrated.'),
                      duration: Duration(seconds: 2),
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

  Widget _buildDiagnosticRow({required String label, required String value, required bool isGood}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, softWrap: false),
          Text(
            value,
            style: TextStyle(
              color: isGood ? AppColors.cardioAccent : AppColors.error,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
    );
  }

  void _showLiveBeaconSheet(BuildContext context) {
    final beaconUrl = 'https://thews.fit/live/run-beacon-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(ctx).brightness == Brightness.dark
                ? AppColors.darkSurfaceContainerHigh
                : AppColors.lightSurfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.darkOutlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.wifi_tethering_rounded, color: AppColors.chestAccent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE BEACON LOCATION SHARING',
                    style: AppTypography.sectionTitle(
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.chestAccent,
                activeTrackColor: AppColors.chestAccent.withValues(alpha: 0.5),
                title: const Text('Broadcast Live GPS Beacon', style: TextStyle(fontWeight: FontWeight.bold), maxLines: 1, softWrap: false),
                subtitle: const Text('Allows friends/coach to view live run map', maxLines: 1, overflow: TextOverflow.ellipsis),
                value: _isLiveLocationShared,
                onChanged: (val) {
                  setSheetState(() => _isLiveLocationShared = val);
                  setState(() => _isLiveLocationShared = val);
                },
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.darkOutlineVariant.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 18, color: AppColors.neonCyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        beaconUrl,
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.chestAccent),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: beaconUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Live Beacon link copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final runState = ref.watch(runTrackingProvider);
    final runNotifier = ref.read(runTrackingProvider.notifier);

    final audioCoach = ref.watch(audioCoachServiceProvider);
    final smartwatchState = ref.watch(smartwatchServiceProvider);
    final heatmapRoutes = ref.watch(heatmapRoutesProvider).valueOrNull ?? [];
    final segmentEngineState = ref.watch(liveSegmentEngineProvider);
    final challengesState = ref.watch(challengesProvider);
    final turnNavState = ref.watch(turnNavigationProvider);

    final userCurrentLocation = runState.waypoints.isNotEmpty
        ? LatLng(runState.waypoints.last.latitude, runState.waypoints.last.longitude)
        : challengesState.userLocation;

    // Only draw circuit polyline if user explicitly chose a route (otherwise run without a route)
    final activeCircuit = _selectedChallenge?.loopWaypoints;

    // Calculate Lap Specific Telemetry
    final lapDurationSeconds = (runState.durationSeconds - _lastLapSeconds).clamp(0, 86400);
    final lapMinutes = (lapDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final lapSeconds = (lapDurationSeconds % 60).toString().padLeft(2, '0');
    final formattedLapTime = '$lapMinutes:$lapSeconds';

    final lapDistanceKm = ((runState.distanceMeters - _lastLapDistanceMeters).clamp(0.0, 999999.0) / 1000.0);
    final formattedLapDistance = lapDistanceKm < 10
        ? lapDistanceKm.toStringAsFixed(2)
        : lapDistanceKm.toStringAsFixed(1);

    // Listen to GPS stream to feed Live Segment Detection & Ghost Racing + Voice Splits + Turn Navigation
    ref.listen<RunTrackingState>(runTrackingProvider, (previous, next) {
      if (next.isTracking && next.waypoints.isNotEmpty) {
        final last = next.waypoints.last;
        ref.read(liveSegmentEngineProvider.notifier).onLocationUpdate(
              latitude: last.latitude,
              longitude: last.longitude,
              timestamp: last.timestamp,
            );
        ref.read(turnNavigationProvider.notifier).updateLocation(
              LatLng(last.latitude, last.longitude),
            );
      } else if (!next.isTracking && (previous?.isTracking ?? false)) {
        ref.read(liveSegmentEngineProvider.notifier).resetSegmentTracking();
      }

      // Voice Coach Split Announcements
      if (next.isTracking && next.splits.length > (previous?.splits.length ?? 0)) {
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

      // Voice Workout State Milestones
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

    // Workout Target Cue Text
    final targetDescription = _selectedChallenge != null
        ? '${_selectedChallenge!.title} (${_selectedChallenge!.targetDistanceKm.toStringAsFixed(1)} km)'
        : (runState.activityType == 'cycle'
            ? 'Free Cycling • Open GPS Mode'
            : _selectedWorkoutGoal);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // 1. Full-Bleed Interactive Vector Map
          Positioned.fill(
            child: LeafletRouteMap(
              mapController: _mapController,
              waypoints: runState.waypoints,
              circuitPolyline: !runState.isTracking ? activeCircuit : null,
              navigationCourse: turnNavState.activeCourse,
              nextNavigationCue: turnNavState.nextCue,
              isDark: isDark,
              isTracking: runState.isTracking,
              headingDegrees: runState.headingDegrees,
              showHeatmapButton: true,
              isHeatmapVisible: _isHeatmapVisible,
              heatmapRoutes: heatmapRoutes,
              ghostPosition: _selectedChallenge != null
                  ? segmentEngineState.ghostTelemetry?.ghostPosition
                  : null,
              activeGhostSegment: _selectedChallenge != null
                  ? (segmentEngineState.selectedGhostSegment ??
                      segmentEngineState.activeEffort?.segment)
                  : null,
              currentLocation: userCurrentLocation,
              controlsTopOffset: MediaQuery.of(context).padding.top + 58,
              onHeatmapTap: () {
                setState(() {
                  _isHeatmapVisible = !_isHeatmapVisible;
                });
              },
              onMapTap: () {
                if (_isSheetExpanded) {
                  setState(() {
                    _isSheetExpanded = false;
                  });
                }
              },
            ),
          ),

          // 2. Top Floating Header Bar (Back button, Coach Banner Pill, Compass Widget)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            right: 14,
            child: Row(
              children: [
                // Circular Back / Minimize Button (⌄)
                _buildCircleGlassButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  isDark: isDark,
                  tooltip: 'Close Tracker',
                  onTap: () {
                    if (runState.isTracking) {
                      _showExitConfirmationDialog(context, runNotifier);
                    } else {
                      context.pop();
                    }
                  },
                ),
                const SizedBox(width: 10),

                // Top AI Coach Pill Banner (Tap to configure AI workout target or route)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_isTargetCardDismissed) {
                        setState(() => _isTargetCardDismissed = false);
                      } else {
                        _showAiCoachTargetSheet(context);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceContainerHighest.withValues(alpha: 0.92)
                            : Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.chestAccent.withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Overlapping 3-Badge Avatar Stack (Interactive Sport / Mode selectors)
                          SizedBox(
                            width: 52,
                            height: 24,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  child: GestureDetector(
                                    onTap: () => runNotifier.setActivityType('jog'),
                                    child: _buildAvatarPill(
                                      color: runState.activityType == 'jog'
                                          ? AppColors.chestAccent
                                          : Colors.grey.shade700,
                                      icon: Icons.directions_run_rounded,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 14,
                                  child: GestureDetector(
                                    onTap: () => _showAiCoachTargetSheet(context),
                                    child: _buildAvatarPill(
                                      color: AppColors.shouldersAccent,
                                      icon: Icons.bolt_rounded,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 28,
                                  child: GestureDetector(
                                    onTap: () => runNotifier.setActivityType('cycle'),
                                    child: _buildAvatarPill(
                                      color: runState.activityType == 'cycle'
                                          ? AppColors.neonCyan
                                          : Colors.grey.shade700,
                                      icon: Icons.directions_bike_rounded,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Thews AI Run Coach',
                                  style: AppTypography.tinyLabel(
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ).copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _selectedChallenge != null
                                      ? 'Route: ${_selectedChallenge!.title}'
                                      : 'Free Run • Open GPS Mode',
                                  style: AppTypography.tinyLabel(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ).copyWith(fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Cardinal Compass Bearing Indicator Widget (Tapping re-orients map to True North)
                GestureDetector(
                  onTap: _orientMapToNorth,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceContainerHighest.withValues(alpha: 0.92)
                          : Colors.white.withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkOutline.withValues(alpha: 0.4)
                            : AppColors.lightOutline.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Transform.rotate(
                        angle: -runState.headingDegrees * (3.141592653589793 / 180.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.navigation_rounded,
                              size: 13,
                              color: AppColors.chestAccent,
                            ),
                            Text(
                              _getCardinalDirection(runState.headingDegrees),
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                              ),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Floating Bottom Control & Target Dashboard Column
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Turn-by-Turn Audio Navigation HUD (when course navigation is active)
                if (turnNavState.isNavigating)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: TurnDirectionHud(),
                  ),

                // Floating Target / Live Interval HUD Card (Clearable/Dismissable in pre-run)
                if (runState.isTracking || !_isTargetCardDismissed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: _buildWorkoutTargetCard(
                      runState: runState,
                      runNotifier: runNotifier,
                      targetText: targetDescription,
                      formattedLapTime: formattedLapTime,
                      formattedLapDistance: formattedLapDistance,
                      formattedGapPace: formattedGapPace,
                      smartwatchBpm: smartwatchState.currentBpm,
                      userLocation: userCurrentLocation,
                      isDark: isDark,
                    ),
                  ),

                // Ghost Racer & Live Segment Detection HUD (ONLY when challenge/route is selected)
                if (_selectedChallenge != null &&
                    (segmentEngineState.selectedGhostSegment != null ||
                        segmentEngineState.activeEffort != null))
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: LiveSegmentHud(),
                  ),

                // Retractable Bottom Control Sheet Container
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity != null) {
                      if (details.primaryVelocity! < -100) {
                        setState(() => _isSheetExpanded = true);
                      } else if (details.primaryVelocity! > 100) {
                        setState(() => _isSheetExpanded = false);
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 10,
                      bottom: MediaQuery.of(context).padding.bottom + 14,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceContainerLowest
                          : AppColors.lightSurfaceContainerLow,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Grab Handle Bar (— with tap to toggle retraction)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _isSheetExpanded = !_isSheetExpanded),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 38,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkOutlineVariant.withValues(alpha: 0.5)
                                        : AppColors.lightOutlineVariant,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (!runState.isTracking) ...[
                          // Pre-Run State: 100% Symmetrical 3-Button Action Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 1. Left Circle: Sport Selector (Run / Cycle / Walk)
                              SizedBox(
                                width: 88,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _buildCircleActionAvatar(
                                      icon: runState.activityType == 'cycle'
                                          ? Icons.directions_bike_rounded
                                          : (runState.activityType == 'walk'
                                              ? Icons.directions_walk_rounded
                                              : Icons.directions_run_rounded),
                                      hasBadge: true,
                                      isDark: isDark,
                                      onTap: () => _showSportSelectorSheet(context, runState, runNotifier),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      runState.activityType == 'cycle'
                                          ? 'Cycle'
                                          : (runState.activityType == 'walk' ? 'Walk' : 'Run'),
                                      style: TextStyle(
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      softWrap: false,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),

                              // 2. Center Circle: Large Vibrant Electric Play Button
                              SizedBox(
                                width: 88,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        runNotifier.startTracking(
                                          activityType: runState.activityType,
                                        );
                                      },
                                      child: Container(
                                        width: 66,
                                        height: 66,
                                        decoration: BoxDecoration(
                                          color: AppColors.chestAccent,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.chestAccent.withValues(alpha: 0.4),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.play_arrow_rounded,
                                            size: 40,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const SizedBox(height: 14), // Balances text baseline height symmetrically
                                  ],
                                ),
                              ),

                              // 3. Right Circle: Switch Route (Clearable / Challenges)
                              SizedBox(
                                width: 88,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _buildCircleActionAvatar(
                                      icon: _selectedChallenge != null
                                          ? Icons.alt_route_rounded
                                          : Icons.route_rounded,
                                      hasBadge: _selectedChallenge != null,
                                      isDark: isDark,
                                      onTap: _handleRouteSelection,
                                    ),
                                    const SizedBox(height: 6),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _selectedChallenge != null ? 'Route Active' : 'Switch Route',
                                        style: TextStyle(
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        softWrap: false,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Retractable Partitioned Settings & Sensors Card (4 Rows)
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 260),
                            crossFadeState: _isSheetExpanded
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            firstChild: Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: _buildSettingsCard(
                                isDark: isDark,
                                isShared: _isLiveLocationShared,
                                isVoiceOn: audioCoach.config.isVoiceEnabled,
                                smartwatchBpm: smartwatchState.currentBpm,
                                activeCourseName: turnNavState.activeCourse?.name,
                                onCourseDirectorTap: () => CourseDirectorSheet.show(context),
                                onShareToggle: () => _showLiveBeaconSheet(context),
                                onRouteAlertsTap: () => AudioCoachSettingsSheet.show(context),
                                onAddSensorTap: () => SmartwatchPairingSheet.show(context),
                                onSettingsTap: () => _showTrackerSettingsSheet(context),
                              ),
                            ),
                            secondChild: const SizedBox(width: double.infinity, height: 0),
                          ),
                        ] else ...[
                          // Active Tracking State: Dual-Pill Control Bar
                          Row(
                            children: [
                              // 1. Left Pill: Pause / Resume (Vibrant Orange Pill)
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (runState.isPaused) {
                                      runNotifier.resumeTracking();
                                    } else {
                                      runNotifier.pauseTracking();
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: AppColors.chestAccent,
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.chestAccent.withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          runState.isPaused
                                              ? Icons.play_arrow_rounded
                                              : Icons.pause_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          runState.isPaused ? 'Resume' : 'Pause',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          softWrap: false,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // 2. Right Pill: Lap / Finish Run (Charcoal Pill)
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _recordLapSplit(runState),
                                  onLongPress: () async {
                                    final activityId = await runNotifier.finishAndSaveActivity();
                                    if (activityId != null && context.mounted) {
                                      context.pushReplacement('/running/summary/$activityId');
                                    } else if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Activity discarded (under 10 meters)'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkSurfaceContainerHighest
                                          : AppColors.lightSurfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.darkOutline.withValues(alpha: 0.4)
                                            : AppColors.lightOutline.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.refresh_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Lap',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          softWrap: false,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap Lap for split • Hold Lap to finish activity',
                            style: AppTypography.tinyLabel(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ).copyWith(fontSize: 10),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Floating Workout Target / Live Interval Telemetry Card (Clearable/Dismissable)
  Widget _buildWorkoutTargetCard({
    required RunTrackingState runState,
    required RunTrackingNotifier runNotifier,
    required String targetText,
    required String formattedLapTime,
    required String formattedLapDistance,
    required String formattedGapPace,
    required int smartwatchBpm,
    required LatLng? userLocation,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerHigh.withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutline.withValues(alpha: 0.3)
              : AppColors.lightOutline.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: GPS Status / Target Title + Expand Button + Clear Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!runState.isTracking) ...[
                // GPS Status Indicator (Tapping opens GPS Diagnostics Inspector)
                GestureDetector(
                  onTap: () => _showGpsDiagnosticsSheet(context, runState, runNotifier, userLocation),
                  child: Row(
                    children: [
                      Icon(
                        Icons.signal_cellular_alt_rounded,
                        size: 16,
                        color: runState.hasLocationPermission
                            ? AppColors.cardioAccent
                            : AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        runState.hasLocationPermission
                            ? 'GPS Ready'
                            : 'No GPS signal',
                        style: TextStyle(
                          color: runState.hasLocationPermission
                              ? AppColors.cardioAccent
                              : AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Active Target Title
                Expanded(
                  child: Text(
                    targetText,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _isHudExpanded ? Icons.fullscreen_exit_rounded : Icons.open_in_full_rounded,
                      size: 18,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    onPressed: () => setState(() => _isHudExpanded = !_isHudExpanded),
                  ),
                  if (!runState.isTracking) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      tooltip: 'Clear Target Card',
                      onPressed: () => setState(() => _isTargetCardDismissed = true),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 3-Bar Segmented Interval Progress Indicator (Tapping opens Goal Selector)
          GestureDetector(
            onTap: () => _showAiCoachTargetSheet(context),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardioAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: runState.distanceMeters >= 1000
                          ? AppColors.cardioAccent
                          : (isDark ? AppColors.darkSurfaceContainerHighest : AppColors.lightSurfaceContainerHighest),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: runState.distanceMeters >= 2000
                          ? AppColors.cardioAccent
                          : (isDark ? AppColors.darkSurfaceContainerHighest : AppColors.lightSurfaceContainerHighest),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (!runState.isTracking) ...[
            // Pre-Run Target Description (Tapping opens Goal Selector)
            GestureDetector(
              onTap: () => _showAiCoachTargetSheet(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FIRST UP',
                    style: AppTypography.tinyLabel(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ).copyWith(fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    softWrap: false,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    targetText,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ] else ...[
            // Active Live Telemetry Metric Columns (Lap time, Lap pace, Lap distance)
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    value: formattedLapTime,
                    label: 'Lap time',
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    value: runState.formattedCurrentPace,
                    label: 'Lap pace (/km)',
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    value: formattedLapDistance,
                    label: 'Lap distance (km)',
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],

          // Expanded Telemetry View (GAP, Elevation, Heart Rate, Steps, Cadence)
          if (_isHudExpanded) ...[
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('GAP (Grade Adjusted Pace): Estimated equivalent flat-terrain running pace adjusting for uphill/downhill gradient.'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                    child: _buildMetricTile(
                      value: formattedGapPace,
                      label: 'GAP (Pace) ⓘ',
                      isDark: isDark,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    value: '${runState.elevationGainMeters.toStringAsFixed(0)} m',
                    label: 'Elevation',
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => SmartwatchPairingSheet.show(context),
                    child: _buildMetricTile(
                      value: smartwatchBpm > 0 ? '$smartwatchBpm bpm' : '-- bpm',
                      label: 'Heart Rate 💓',
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Pre-Run Partitioned Settings Card (5 Rows)
  Widget _buildSettingsCard({
    required bool isDark,
    required bool isShared,
    required bool isVoiceOn,
    required int smartwatchBpm,
    required String? activeCourseName,
    required VoidCallback onShareToggle,
    required VoidCallback onRouteAlertsTap,
    required VoidCallback onAddSensorTap,
    required VoidCallback onCourseDirectorTap,
    required VoidCallback onSettingsTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutline.withValues(alpha: 0.3)
              : AppColors.lightOutline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          _buildSettingsRow(
            icon: Icons.navigation_rounded,
            title: 'Course Director & GPX',
            subtitle: activeCourseName != null
                ? 'Navigating: $activeCourseName'
                : 'Turn-by-turn guidance, 5K/10K loops, GPX import',
            isDark: isDark,
            onTap: onCourseDirectorTap,
          ),
          _buildDivider(isDark),
          _buildSettingsRow(
            icon: Icons.wifi_tethering_rounded,
            title: 'Share live location',
            subtitle: isShared ? 'Active (Live Beacon Broadcast)' : 'Off • Share link with coach/friends',
            isDark: isDark,
            onTap: onShareToggle,
          ),
          _buildDivider(isDark),
          _buildSettingsRow(
            icon: Icons.notifications_none_rounded,
            title: 'Route alerts',
            subtitle: isVoiceOn ? 'Voice alerts ON (Splits & HR)' : 'Off',
            isDark: isDark,
            onTap: onRouteAlertsTap,
          ),
          _buildDivider(isDark),
          _buildSettingsRow(
            icon: Icons.favorite_border_rounded,
            title: 'Add a sensor',
            subtitle: smartwatchBpm > 0
                ? '$smartwatchBpm BPM Connected'
                : 'Bluetooth HR, Smartwatch, Cadence',
            isDark: isDark,
            onTap: onAddSensorTap,
          ),
          _buildDivider(isDark),
          _buildSettingsRow(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Audio cues, auto-pause, live segments',
            isDark: isDark,
            onTap: onSettingsTap,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 50,
      endIndent: 16,
      color: isDark
          ? AppColors.darkOutline.withValues(alpha: 0.15)
          : AppColors.lightOutline.withValues(alpha: 0.15),
    );
  }

  Widget _buildCircleActionAvatar({
    required IconData icon,
    required bool isDark,
    required bool hasBadge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF3E2723).withValues(alpha: 0.65),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.chestAccent.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                color: AppColors.chestAccent,
                size: 26,
              ),
            ),
          ),
          if (hasBadge)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.chestAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: AppTypography.tinyLabel(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ).copyWith(fontSize: 10),
          maxLines: 1,
          softWrap: false,
        ),
      ],
    );
  }

  Widget _buildAvatarPill({required Color color, required IconData icon}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black87, width: 1.5),
      ),
      child: Center(
        child: Icon(icon, size: 13, color: Colors.white),
      ),
    );
  }

  Widget _buildCircleGlassButton({
    required IconData icon,
    required bool isDark,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceContainerHighest.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? AppColors.darkOutline.withValues(alpha: 0.4)
                  : AppColors.lightOutline.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }

  void _showTrackerSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurfaceContainerHigh
              : AppColors.lightSurfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.darkOutlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'TRACKER PREFERENCES',
              style: AppTypography.sectionTitle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              maxLines: 1,
              softWrap: false,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.navigation_rounded, color: AppColors.chestAccent),
              title: const Text('Course Director & GPX Routes', maxLines: 1, softWrap: false),
              subtitle: const Text('Turn-by-turn audio routing, 5K loops & GPX imports', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                CourseDirectorSheet.show(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over),
              title: const Text('Audio Voice Coach', maxLines: 1, softWrap: false),
              subtitle: const Text('Split announcements & heart rate alerts', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                AudioCoachSettingsSheet.show(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timelapse),
              title: const Text('Cadence Metronome', maxLines: 1, softWrap: false),
              subtitle: const Text('SPM audio & haptic pacer', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                CadenceMetronomeSheet.show(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded),
              title: const Text('Live Segments & Ghost Pacing', maxLines: 1, softWrap: false),
              subtitle: const Text('Virtual target runner and leaderboard splits', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                LiveSegmentPickerSheet.show(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.watch_rounded),
              title: const Text('Smartwatch & Bluetooth Sensors', maxLines: 1, softWrap: false),
              subtitle: const Text('Heart rate monitor and step cadence', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                SmartwatchPairingSheet.show(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showExitConfirmationDialog(BuildContext context, RunTrackingNotifier runNotifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Activity Tracking?', maxLines: 1, softWrap: false),
        content: const Text(
          'An outdoor run is currently in progress. Would you like to finish and save your workout or discard it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', maxLines: 1, softWrap: false),
          ),
          TextButton(
            onPressed: () {
              runNotifier.pauseTracking();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('DISCARD', maxLines: 1, softWrap: false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.chestAccent),
            onPressed: () async {
              Navigator.pop(context);
              final activityId = await runNotifier.finishAndSaveActivity();
              if (activityId != null && context.mounted) {
                context.pushReplacement('/running/summary/$activityId');
              } else if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('FINISH & SAVE', maxLines: 1, softWrap: false),
          ),
        ],
      ),
    );
  }
}
