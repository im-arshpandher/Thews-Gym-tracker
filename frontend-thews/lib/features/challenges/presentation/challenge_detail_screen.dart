import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/gps_tracking_service.dart';
import '../../../core/services/tile_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../running/domain/live_segment_engine.dart';
import '../../running/domain/live_segment_models.dart';
import '../domain/challenge_models.dart';
import 'challenges_provider.dart';

class ChallengeDetailScreen extends ConsumerStatefulWidget {
  final String challengeId;
  final LocalChallenge? initialChallenge;

  const ChallengeDetailScreen({
    super.key,
    required this.challengeId,
    this.initialChallenge,
  });

  @override
  ConsumerState<ChallengeDetailScreen> createState() =>
      _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends ConsumerState<ChallengeDetailScreen>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  AnimationController? _animController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _animController?.stop();
    _animController?.dispose();
    _animController = null;
    _mapController.dispose();
    super.dispose();
  }

  void _animatedMapMove(
    LatLng destLocation,
    double destZoom, {
    Duration duration = const Duration(milliseconds: 650),
    Curve curve = Curves.fastOutSlowIn,
  }) {
    _animController?.stop();
    _animController?.dispose();
    _animController = null;

    final camera = _mapController.camera;
    final latTween = Tween<double>(
      begin: camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: duration,
      vsync: this,
    );
    _animController = controller;

    final animation = CurvedAnimation(
      parent: controller,
      curve: curve,
    );

    controller.addListener(() {
      try {
        _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation),
        );
      } catch (e) {
        debugPrint('Challenge map move notice: $e');
      }
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (_animController == controller) {
          controller.dispose();
          _animController = null;
        }
      }
    });

    controller.forward();
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    final nextZoom = (currentZoom + 1.0).clamp(3.0, 19.0);
    _animatedMapMove(
      _mapController.camera.center,
      nextZoom,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    final nextZoom = (currentZoom - 1.0).clamp(3.0, 19.0);
    _animatedMapMove(
      _mapController.camera.center,
      nextZoom,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _fitRoute(List<LatLng> waypoints) {
    if (waypoints.isEmpty) return;
    if (waypoints.length == 1) {
      _animatedMapMove(waypoints.first, 15.0);
      return;
    }

    final bounds = LatLngBounds.fromPoints(waypoints);
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(
            top: 90.0,
            bottom: 330.0,
            left: 48.0,
            right: 48.0,
          ),
        ),
      );
    } catch (_) {
      _animatedMapMove(bounds.center, 14.5);
    }
  }

  LatLng _calculateCentroid(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(37.7749, -122.4194);
    double sumLat = 0;
    double sumLng = 0;
    for (final p in points) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  double _calculateZoomLevel(double distanceMeters) {
    if (distanceMeters <= 1200) return 15.2;
    if (distanceMeters <= 3500) return 14.1;
    if (distanceMeters <= 8000) return 12.8;
    return 11.5;
  }

  Color _getDifficultyColor(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return AppColors.success;
      case ChallengeDifficulty.medium:
        return AppColors.primaryVolt;
      case ChallengeDifficulty.hard:
        return AppColors.error;
    }
  }

  Color _getTrophyTierColor(TrophyTier tier) {
    switch (tier) {
      case TrophyTier.bronze:
        return const Color(0xFFCD7F32);
      case TrophyTier.silver:
        return const Color(0xFFC0C0C0);
      case TrophyTier.gold:
        return const Color(0xFFFFD700);
      case TrophyTier.diamond:
        return const Color(0xFF00E5FF);
    }
  }

  String _formatPace(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return '6:15 /km';
      case ChallengeDifficulty.medium:
        return '5:15 /km';
      case ChallengeDifficulty.hard:
        return '4:30 /km';
    }
  }

  int _calculateEstMinutes(double distanceMeters, ChallengeDifficulty difficulty) {
    final km = distanceMeters / 1000.0;
    final paceMinsPerKm = switch (difficulty) {
      ChallengeDifficulty.easy => 6.25,
      ChallengeDifficulty.medium => 5.25,
      ChallengeDifficulty.hard => 4.5,
    };
    return (km * paceMinsPerKm).round();
  }

  Future<void> _confirmDelete(BuildContext context, LocalChallenge challenge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Custom Challenge?'),
          content: Text(
            'Are you sure you want to remove "${challenge.title}" from your locality challenges?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL', maxLines: 1, softWrap: false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('DELETE', maxLines: 1, softWrap: false),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await ref.read(challengesProvider.notifier).deleteChallenge(challenge.id);
      if (context.mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom challenge removed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(challengesProvider);

    // Find latest challenge matching id, or fallback to initialChallenge
    final challenge = state.challenges.cast<LocalChallenge?>().firstWhere(
          (c) => c?.id == widget.challengeId,
          orElse: () => widget.initialChallenge,
        );

    if (challenge == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Challenge Not Found')),
        body: const Center(child: Text('Challenge could not be located.')),
      );
    }

    final diffColor = _getDifficultyColor(challenge.difficulty);
    final trophyColor = _getTrophyTierColor(challenge.trophyReward.tier);
    final estMins = _calculateEstMinutes(
      challenge.targetDistanceMeters,
      challenge.difficulty,
    );

    final runState = ref.watch(runTrackingProvider);
    final userLocation = (runState.waypoints.isNotEmpty)
        ? LatLng(
            runState.waypoints.last.latitude,
            runState.waypoints.last.longitude,
          )
        : state.userLocation;
    final heading = runState.headingDegrees;

    return Scaffold(
      body: Stack(
        children: [
          // Interactive Full-Screen Map
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _calculateCentroid(challenge.loopWaypoints),
                initialZoom: _calculateZoomLevel(challenge.targetDistanceMeters),
                onMapReady: () => _fitRoute(challenge.loopWaypoints),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: isDark
                      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                      : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  retinaMode: RetinaMode.isHighDensity(context),
                  userAgentPackageName: 'com.thews.fitnessapp',
                  tileProvider: PersistentDiskTileProvider(),
                ),
                // Glowing background polyline for rich aesthetics
                if (challenge.loopWaypoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: challenge.loopWaypoints,
                        strokeWidth: 8.0,
                        color: (isDark
                                ? AppColors.primaryVolt
                                : AppColors.lightPrimary)
                            .withValues(alpha: 0.35),
                      ),
                      Polyline(
                        points: challenge.loopWaypoints,
                        strokeWidth: 4.5,
                        color: isDark
                            ? AppColors.primaryVolt
                            : AppColors.lightPrimary,
                      ),
                    ],
                  ),
                // Start & Position Pointer Markers
                MarkerLayer(
                  markers: [
                    // 1. Challenge Start Flag Marker
                    if (challenge.loopWaypoints.isNotEmpty)
                      Marker(
                        point: challenge.loopWaypoints.first,
                        width: 36,
                        height: 36,
                        rotate: false,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.primaryVolt
                                : AppColors.lightPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.flag_rounded,
                              size: 18,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),

                    // 2. User Live Position Pointer Marker
                    Marker(
                      point: userLocation,
                      width: 52,
                      height: 52,
                      rotate: false,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Accuracy / Beacon Halo
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2979FF)
                                  .withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                            ),
                          ),
                          // Inner Core Location Puck with Heading Arrow
                          Transform.rotate(
                            angle: heading * (3.141592653589793 / 180.0),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2979FF),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.navigation,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          // High-contrast 'YOU' Identification Pill
                          Positioned(
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E88E5),
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: Colors.white, width: 1),
                              ),
                              child: const Text(
                                'YOU',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Floating Top App Bar with back button and options
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGlassIconButton(
                  icon: Icons.arrow_back,
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  isDark: isDark,
                  tooltip: 'Back to Challenges',
                ),
                Row(
                  children: [
                    if (challenge.isCustom)
                      _buildGlassIconButton(
                        icon: Icons.delete_outline,
                        color: AppColors.error,
                        onPressed: () => _confirmDelete(context, challenge),
                        isDark: isDark,
                        tooltip: 'Delete Custom Challenge',
                      ),
                    const SizedBox(width: 8),
                    _buildGlassIconButton(
                      icon: Icons.center_focus_strong,
                      onPressed: () => _fitRoute(challenge.loopWaypoints),
                      isDark: isDark,
                      tooltip: 'Fit Route to Screen',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Floating Map Zoom In / Out & My Location Controls
          Positioned(
            right: 16,
            bottom: 300,
            child: Column(
              children: [
                _buildGlassIconButton(
                  icon: Icons.my_location,
                  onPressed: () => _animatedMapMove(userLocation, 16.5),
                  isDark: isDark,
                  tooltip: 'My Location',
                ),
                const SizedBox(height: 8),
                _buildGlassIconButton(
                  icon: Icons.add,
                  onPressed: _zoomIn,
                  isDark: isDark,
                  tooltip: 'Zoom In',
                ),
                const SizedBox(height: 8),
                _buildGlassIconButton(
                  icon: Icons.remove,
                  onPressed: _zoomOut,
                  isDark: isDark,
                  tooltip: 'Zoom Out',
                ),
              ],
            ),
          ),

          // Bottom Slide-Up Card: Challenge Telemetry & Action Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: AppSpacing.base,
                right: AppSpacing.base,
                top: AppSpacing.md,
                bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainerHighest.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.96),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: (isDark ? AppColors.darkOutline : AppColors.lightOutline)
                      .withValues(alpha: 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag indicator handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.darkOutline
                                : AppColors.lightOutline)
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Header Badges: Difficulty & Locality
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: diffColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: diffColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '${challenge.difficulty.label} CIRCUIT',
                          style: AppTypography.labelCaps(color: diffColor)
                              .copyWith(fontWeight: FontWeight.bold, fontSize: 10),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (challenge.isCustom)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryVolt.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primaryVolt.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            'CUSTOM ROUTE',
                            style: AppTypography.labelCaps(
                              color: isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary,
                            ).copyWith(fontWeight: FontWeight.bold, fontSize: 10),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      const Spacer(),
                      if (challenge.isCompleted)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'COMPLETED',
                              style: AppTypography.labelCaps(
                                color: AppColors.success,
                              ).copyWith(fontWeight: FontWeight.w900),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // Challenge Title & Locality
                  Text(
                    challenge.title,
                    style: AppTypography.headlineMd(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ).copyWith(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    challenge.localityName,
                    style: AppTypography.bodySm(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Telemetry Stat Grid (Distance, Est Time, Pace, XP)
                  Row(
                    children: [
                      _buildMetricTile(
                        label: 'DISTANCE',
                        value: '${challenge.targetDistanceKm.toStringAsFixed(1)} KM',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildMetricTile(
                        label: 'EST. TIME',
                        value: '~$estMins MIN',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildMetricTile(
                        label: 'TARGET PACE',
                        value: _formatPace(challenge.difficulty),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildMetricTile(
                        label: 'BOUNTY',
                        value: '+${challenge.trophyReward.xpReward} XP',
                        isDark: isDark,
                        valueColor: trophyColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Start Challenge Button (Single-line constraint adhered)
                  ElevatedButton.icon(
                    onPressed: () {
                      if (challenge.loopWaypoints.isNotEmpty) {
                        final challengeSegment = RunSegment(
                          id: 'challenge_${challenge.id}',
                          name: challenge.title,
                          startPoint: SegmentCoordinate(
                            latitude: challenge.loopWaypoints.first.latitude,
                            longitude: challenge.loopWaypoints.first.longitude,
                          ),
                          endPoint: SegmentCoordinate(
                            latitude: challenge.loopWaypoints.last.latitude,
                            longitude: challenge.loopWaypoints.last.longitude,
                          ),
                          distanceMeters: challenge.targetDistanceMeters,
                          bestTimeSeconds: (challenge.targetDistanceMeters /
                                  1000.0 *
                                  (challenge.difficulty ==
                                          ChallengeDifficulty.easy
                                      ? 360
                                      : challenge.difficulty ==
                                              ChallengeDifficulty.medium
                                          ? 300
                                          : 240))
                              .round(),
                          polyline: challenge.loopWaypoints
                              .map((p) => SegmentCoordinate(
                                    latitude: p.latitude,
                                    longitude: p.longitude,
                                  ))
                              .toList(),
                          createdAt: DateTime.now(),
                        );
                        ref
                            .read(liveSegmentEngineProvider.notifier)
                            .selectGhostSegment(challengeSegment);
                      }
                      context.go('/running');
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary,
                      foregroundColor: isDark
                          ? AppColors.darkBackground
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 24),
                    label: const Text(
                      'START CHALLENGE & RACE GHOST',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDark,
    required String tooltip,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark
            ? AppColors.darkSurfaceContainerHighest.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: (isDark ? AppColors.darkOutline : AppColors.lightOutline)
                .withValues(alpha: 0.3),
          ),
        ),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 20,
              color: color ??
                  (isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required bool isDark,
    Color? valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: (isDark
                  ? AppColors.darkSurfaceContainer
                  : AppColors.lightSurfaceContainer)
              .withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isDark ? AppColors.darkOutline : AppColors.lightOutline)
                .withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppTypography.tinyLabel(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ).copyWith(fontSize: 8, fontWeight: FontWeight.w700),
              maxLines: 1,
              softWrap: false,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTypography.cardTitle(
                color: valueColor ??
                    (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary),
              ).copyWith(fontWeight: FontWeight.w900, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }
}
