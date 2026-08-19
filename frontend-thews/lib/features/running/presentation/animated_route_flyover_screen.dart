import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/tile_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/gpx_parser.dart';
import 'widgets/gradient_route_painter.dart';

class AnimatedRouteFlyoverScreen extends ConsumerStatefulWidget {
  final int activityId;
  final RunActivityData? initialActivity;

  const AnimatedRouteFlyoverScreen({
    super.key,
    required this.activityId,
    this.initialActivity,
  });

  @override
  ConsumerState<AnimatedRouteFlyoverScreen> createState() =>
      _AnimatedRouteFlyoverScreenState();
}

class _AnimatedRouteFlyoverScreenState
    extends ConsumerState<AnimatedRouteFlyoverScreen>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  AnimationController? _animController;

  List<GpxPoint> _waypoints = [];
  List<double> _cumulativeDistances = [];
  double _totalDistanceMeters = 0.0;

  double _playbackSpeed = 1.0;
  bool _isPlaying = false;
  double _progress = 0.0; // 0.0 to 1.0
  RouteColorMode _colorMode = RouteColorMode.slopeGradient;

  int _lastAnnouncedSplitKm = 0;
  String? _milestoneBannerText;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  void _initPlayback(RunActivityData activity) {
    if (_waypoints.isNotEmpty) return;

    if (activity.gpxData != null && activity.gpxData!.isNotEmpty) {
      _waypoints = GpxParser.parseGpxXml(activity.gpxData!);
    }

    if (_waypoints.isEmpty) return;

    final distanceCalc = const Distance();
    _cumulativeDistances = [0.0];
    double runningDist = 0.0;

    for (int i = 0; i < _waypoints.length - 1; i++) {
      final d = distanceCalc.as(
        LengthUnit.Meter,
        LatLng(_waypoints[i].latitude, _waypoints[i].longitude),
        LatLng(_waypoints[i + 1].latitude, _waypoints[i + 1].longitude),
      );
      runningDist += d;
      _cumulativeDistances.add(runningDist);
    }
    _totalDistanceMeters = runningDist > 0 ? runningDist : activity.distanceMeters;

    final baseDurationMs = math.max(
      15000,
      math.min(60000, (_totalDistanceMeters / 100.0 * 1000).toInt()),
    );

    _animController = AnimationController(
      duration: Duration(milliseconds: (baseDurationMs / _playbackSpeed).round()),
      vsync: this,
    )..addListener(_onAnimationTick)
     ..addStatusListener((status) {
       if (status == AnimationStatus.completed) {
         setState(() => _isPlaying = false);
       }
     });

    // Start playback automatically on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _play();
      }
    });
  }

  void _onAnimationTick() {
    if (_animController == null || _waypoints.isEmpty) return;

    final val = _animController!.value;
    setState(() {
      _progress = val;
    });

    final currentPoint = _interpolatePointAtProgress(val);
    final targetLatLng = LatLng(currentPoint.latitude, currentPoint.longitude);

    try {
      _mapController.move(targetLatLng, 17.2);
    } catch (_) {}

    // Check kilometer milestone triggers
    final currentKm = ((val * _totalDistanceMeters) / 1000.0).floor();
    if (currentKm > _lastAnnouncedSplitKm && currentKm > 0) {
      _lastAnnouncedSplitKm = currentKm;
      setState(() {
        _milestoneBannerText = 'SPLIT $currentKm KM COMPLETED ⚡';
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _milestoneBannerText = null);
        }
      });
    }
  }

  GpxPoint _interpolatePointAtProgress(double progress) {
    if (_waypoints.isEmpty) {
      return GpxPoint(latitude: 0, longitude: 0, elevation: 0, timestamp: DateTime.now());
    }
    if (_waypoints.length == 1 || progress <= 0.0) return _waypoints.first;
    if (progress >= 1.0) return _waypoints.last;

    final targetDist = progress * _totalDistanceMeters;

    // Find segment
    int idx = 0;
    for (int i = 0; i < _cumulativeDistances.length - 1; i++) {
      if (targetDist >= _cumulativeDistances[i] && targetDist <= _cumulativeDistances[i + 1]) {
        idx = i;
        break;
      }
    }

    final p1 = _waypoints[idx];
    final p2 = _waypoints[math.min(idx + 1, _waypoints.length - 1)];

    final segStartDist = _cumulativeDistances[idx];
    final segEndDist = _cumulativeDistances[math.min(idx + 1, _cumulativeDistances.length - 1)];
    final segLength = segEndDist - segStartDist;

    final t = segLength > 0 ? (targetDist - segStartDist) / segLength : 0.0;

    final lat = p1.latitude + (p2.latitude - p1.latitude) * t;
    final lng = p1.longitude + (p2.longitude - p1.longitude) * t;
    final elev = p1.elevation + (p2.elevation - p1.elevation) * t;

    return GpxPoint(
      latitude: lat,
      longitude: lng,
      elevation: elev,
      timestamp: p1.timestamp,
    );
  }

  void _play() {
    if (_animController == null) return;
    if (_animController!.isCompleted) {
      _animController!.reset();
      _lastAnnouncedSplitKm = 0;
    }
    _animController!.forward();
    setState(() => _isPlaying = true);
  }

  void _pause() {
    _animController?.stop();
    setState(() => _isPlaying = false);
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }
  }

  void _seekTo(double value) {
    _progress = value;
    _animController?.value = value;
    _onAnimationTick();
  }

  void _setSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
    if (_animController != null) {
      final baseDurationMs = math.max(
        15000,
        math.min(60000, (_totalDistanceMeters / 100.0 * 1000).toInt()),
      );
      _animController!.duration = Duration(
        milliseconds: (baseDurationMs / _playbackSpeed).round(),
      );
      if (_isPlaying) {
        _animController!.forward();
      }
    }
  }

  @override
  void dispose() {
    _animController?.stop();
    _animController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  String _formatPace(double paceSecPerKm) {
    if (paceSecPerKm <= 0 || paceSecPerKm.isInfinite) return '--:--';
    final mins = (paceSecPerKm ~/ 60).toString().padLeft(2, '0');
    final secs = (paceSecPerKm % 60).toInt().toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final db = ref.watch(databaseProvider);

    return FutureBuilder<RunActivityData?>(
      future: widget.initialActivity != null
          ? Future.value(widget.initialActivity)
          : db.getRunActivityById(widget.activityId),
      builder: (context, snapshot) {
        final activity = snapshot.data;
        if (activity == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        _initPlayback(activity);

        final currentPoint = _interpolatePointAtProgress(_progress);
        final currentLatLng = LatLng(currentPoint.latitude, currentPoint.longitude);
        final currentDistKm = (_progress * _totalDistanceMeters) / 1000.0;
        final totalDistKm = _totalDistanceMeters / 1000.0;

        // Calculate traveled path
        final traveledPoints = <LatLng>[];
        final targetDist = _progress * _totalDistanceMeters;
        for (int i = 0; i < _waypoints.length; i++) {
          if (i < _cumulativeDistances.length && _cumulativeDistances[i] <= targetDist) {
            traveledPoints.add(LatLng(_waypoints[i].latitude, _waypoints[i].longitude));
          } else {
            break;
          }
        }
        traveledPoints.add(currentLatLng);

        final allLatLngPoints =
            _waypoints.map((p) => LatLng(p.latitude, p.longitude)).toList();

        final tileUrl = isDark
            ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
            : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          body: Stack(
            children: [
              // 1. Vector Map Canvas
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: allLatLngPoints.isNotEmpty
                      ? allLatLngPoints.first
                      : const LatLng(0, 0),
                  initialZoom: 17.2,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    key: ValueKey(tileUrl),
                    urlTemplate: tileUrl,
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.thews.fitnessapp',
                    tileProvider: PersistentDiskTileProvider(),
                    retinaMode: RetinaMode.isHighDensity(context),
                  ),

                  // Base Route Polyline
                  if (_colorMode == RouteColorMode.slopeGradient)
                    PolylineLayer(
                      polylines: SlopeGradientUtils.buildSlopeGradientPolylines(
                        _waypoints,
                        isDark: isDark,
                        strokeWidth: 4.5,
                      ),
                    )
                  else if (_colorMode == RouteColorMode.heartRateZone)
                    PolylineLayer(
                      polylines: SlopeGradientUtils.buildHeartRateZonePolylines(
                        _waypoints,
                        strokeWidth: 4.5,
                      ),
                    )
                  else
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: allLatLngPoints,
                          strokeWidth: 4.0,
                          color: (isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary)
                              .withValues(alpha: 0.35),
                        ),
                      ],
                    ),

                  // Active Glowing Traveled Trail Polyline
                  if (traveledPoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: traveledPoints,
                          strokeWidth: 8.0,
                          color: AppColors.neonCyan.withValues(alpha: 0.4),
                        ),
                        Polyline(
                          points: traveledPoints,
                          strokeWidth: 4.5,
                          color: AppColors.neonCyan,
                          borderColor: Colors.black45,
                          borderStrokeWidth: 1.0,
                        ),
                      ],
                    ),

                  // Moving 3D Athlete Halo & Chevron Marker
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: currentLatLng,
                        width: 54,
                        height: 54,
                        rotate: false,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulsing radar glow
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.neonCyan.withValues(alpha: 0.25),
                                ),
                              ),
                              // Core indicator beacon
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.primaryVolt
                                      : AppColors.lightPrimary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isDark
                                              ? AppColors.primaryVolt
                                              : AppColors.lightPrimary)
                                          .withValues(alpha: 0.8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.navigation_rounded,
                                    color: Colors.black,
                                    size: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // 2. Top Header Toolbar & Navigation
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 14,
                right: 14,
                child: Row(
                  children: [
                    // Back Button
                    _buildGlassIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => context.pop(),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    // Title Pill
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? AppColors.darkSurfaceContainerHighest
                                  : Colors.white)
                              .withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.flight_takeoff_rounded,
                              color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${activity.activityType.toUpperCase()} 3D FLYOVER',
                                style: AppTypography.labelCaps(
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Color Mode Switcher
                    _buildGlassIconButton(
                      icon: Icons.palette_outlined,
                      tooltip: 'Toggle Color Mode',
                      onTap: () {
                        setState(() {
                          if (_colorMode == RouteColorMode.slopeGradient) {
                            _colorMode = RouteColorMode.heartRateZone;
                          } else if (_colorMode == RouteColorMode.heartRateZone) {
                            _colorMode = RouteColorMode.solidVolt;
                          } else {
                            _colorMode = RouteColorMode.slopeGradient;
                          }
                        });
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              // 3. Milestone Notification Toast
              if (_milestoneBannerText != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 65,
                  left: 20,
                  right: 20,
                  child: AnimatedOpacity(
                    opacity: _milestoneBannerText != null ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                            AppColors.neonCyan,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonCyan.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.black, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _milestoneBannerText!,
                            style: AppTypography.labelCaps(color: Colors.black)
                                .copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 4. Floating Live Telemetry HUD (Upper-Mid Overlay)
              Positioned(
                top: MediaQuery.of(context).padding.top + 68,
                left: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: (isDark
                            ? AppColors.darkSurfaceContainerHighest
                            : Colors.white)
                        .withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _telemetryColumn(
                        label: 'DISTANCE',
                        value: '${currentDistKm.toStringAsFixed(2)} / ${totalDistKm.toStringAsFixed(1)} km',
                        isDark: isDark,
                        highlightColor: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                      ),
                      _telemetryDivider(isDark),
                      _telemetryColumn(
                        label: 'AVG PACE',
                        value: '${_formatPace(activity.avgPaceSecondsPerKm)}/km',
                        isDark: isDark,
                      ),
                      _telemetryDivider(isDark),
                      _telemetryColumn(
                        label: 'ALTITUDE',
                        value: '${currentPoint.elevation.toInt()} m',
                        isDark: isDark,
                      ),
                      _telemetryDivider(isDark),
                      _telemetryColumn(
                        label: 'ELEV GAIN',
                        value: '+${activity.elevationGainMeters.toInt()} m',
                        isDark: isDark,
                        highlightColor: const Color(0xFF00E5FF),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Bottom Interactive Flight Deck & Scrubber
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 14,
                    bottom: MediaQuery.of(context).padding.bottom + 14,
                  ),
                  decoration: BoxDecoration(
                    color: (isDark
                            ? AppColors.darkSurfaceContainerHighest
                            : Colors.white)
                        .withValues(alpha: 0.96),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(
                      color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Elevation Silhouette Mini-Chart
                      if (_waypoints.length >= 2) ...[
                        SizedBox(
                          height: 48,
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              lineTouchData: const LineTouchData(enabled: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _waypoints.asMap().entries.map((e) {
                                    return FlSpot(e.key.toDouble(), e.value.elevation);
                                  }).toList(),
                                  isCurved: true,
                                  color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                                  barWidth: 2.0,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: (isDark
                                            ? AppColors.primaryVolt
                                            : AppColors.lightPrimary)
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Scrubber Progress Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                          inactiveTrackColor: isDark
                              ? AppColors.darkOutline
                              : AppColors.lightOutline,
                          thumbColor: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                          overlayColor: (isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary)
                              .withValues(alpha: 0.2),
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        ),
                        child: Slider(
                          value: _progress.clamp(0.0, 1.0),
                          onChanged: _seekTo,
                        ),
                      ),

                      // Transport Playback Controls & Speed Multipliers
                      Row(
                        children: [
                          // Play/Pause Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                              foregroundColor: isDark ? AppColors.primaryVoltOn : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _togglePlayPause,
                            icon: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 20,
                            ),
                            label: Text(
                              _isPlaying ? 'PAUSE' : 'PLAY FLYOVER',
                              maxLines: 1,
                              softWrap: false,
                              style: AppTypography.labelCaps().copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.primaryVoltOn : Colors.white,
                              ),
                            ),
                          ),
                          const Spacer(),

                          // Speed Multiplier Chips
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [1.0, 2.0, 4.0, 8.0].map((speed) {
                              final isSelected = _playbackSpeed == speed;
                              return Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: InkWell(
                                  onTap: () => _setSpeed(speed),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDark
                                                  ? AppColors.primaryVolt
                                                  : AppColors.lightPrimary)
                                              .withValues(alpha: 0.25)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? (isDark
                                                ? AppColors.primaryVolt
                                                : AppColors.lightPrimary)
                                            : (isDark
                                                ? AppColors.darkOutline
                                                : AppColors.lightOutline),
                                      ),
                                    ),
                                    child: Text(
                                      '${speed.toInt()}x',
                                      maxLines: 1,
                                      softWrap: false,
                                      style: AppTypography.tinyLabel(
                                        color: isSelected
                                            ? (isDark
                                                ? AppColors.primaryVolt
                                                : AppColors.lightPrimary)
                                            : (isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary),
                                      ).copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    String? tooltip,
  }) {
    final widgetChild = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkSurfaceContainerHighest : Colors.white)
                .withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
            ),
          ),
          child: Icon(
            icon,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            size: 20,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: widgetChild);
    }
    return widgetChild;
  }

  Widget _telemetryColumn({
    required String label,
    required String value,
    required bool isDark,
    Color? highlightColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.tinyLabel(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ).copyWith(fontSize: 9),
          maxLines: 1,
          softWrap: false,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.cardTitle(
            color: highlightColor ??
                (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ).copyWith(fontSize: 13, fontWeight: FontWeight.bold),
          maxLines: 1,
          softWrap: false,
        ),
      ],
    );
  }

  Widget _telemetryDivider(bool isDark) {
    return Container(
      width: 1,
      height: 24,
      color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
    );
  }
}
