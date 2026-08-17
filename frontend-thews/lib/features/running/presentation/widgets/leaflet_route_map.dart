import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/tile_cache_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/gpx_parser.dart';
import '../../domain/live_segment_models.dart';
import 'heatmap_polyline_painter.dart';

class LeafletRouteMap extends StatefulWidget {
  final List<GpxPoint> waypoints;
  final bool isDark;
  final bool interactive;
  final bool isTracking;
  final double headingDegrees;
  final bool showHeatmapButton;
  final bool isHeatmapVisible;
  final List<List<LatLng>>? heatmapRoutes;
  final VoidCallback? onHeatmapTap;
  final LatLng? ghostPosition;
  final RunSegment? activeGhostSegment;
  final LatLng? currentLocation;

  const LeafletRouteMap({
    super.key,
    required this.waypoints,
    required this.isDark,
    this.interactive = true,
    this.isTracking = false,
    this.headingDegrees = 0.0,
    this.showHeatmapButton = false,
    this.isHeatmapVisible = false,
    this.heatmapRoutes,
    this.onHeatmapTap,
    this.ghostPosition,
    this.activeGhostSegment,
    this.currentLocation,
  });

  @override
  State<LeafletRouteMap> createState() => _LeafletRouteMapState();
}

class _LeafletRouteMapState extends State<LeafletRouteMap>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  bool _hasInitialCentered = false;
  AnimationController? _animController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant LeafletRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeGhostSegment?.id != oldWidget.activeGhostSegment?.id &&
        widget.activeGhostSegment != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoZoomAndCenterMap(animate: true);
      });
    } else if (widget.waypoints.isNotEmpty) {
      if (!_hasInitialCentered) {
        _hasInitialCentered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _autoZoomAndCenterMap();
        });
      } else if (widget.isTracking &&
          widget.waypoints.length != oldWidget.waypoints.length) {
        // Auto follow live user location during active tracking
        final newCenter = LatLng(
          widget.waypoints.last.latitude,
          widget.waypoints.last.longitude,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapController.move(newCenter, _mapController.camera.zoom);
          } catch (e) {
            debugPrint('Map move follow location notice: $e');
          }
        });
      }
    }
  }

  /// Smoothly animates the map center and zoom level to [destLocation] and [destZoom]
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
        debugPrint('Animated map move notice: $e');
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

  /// Automatically zooms and centers the map based on the geographic distance covered by the waypoints and active ghost segment.
  void _autoZoomAndCenterMap({bool animate = false}) {
    final latLngPoints = widget.waypoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    final allBoundsPoints = <LatLng>[...latLngPoints];
    if (widget.currentLocation != null && latLngPoints.isEmpty) {
      allBoundsPoints.add(widget.currentLocation!);
    }
    if (widget.activeGhostSegment != null) {
      allBoundsPoints.addAll(
        widget.activeGhostSegment!.polyline.map((p) => p.toLatLng()),
      );
    }

    if (allBoundsPoints.isEmpty) return;

    if (allBoundsPoints.length < 2) {
      if (animate) {
        _animatedMapMove(allBoundsPoints.first, 16.5);
      } else {
        try {
          _mapController.move(allBoundsPoints.first, 16.5);
        } catch (e) {
          debugPrint('Map move single point notice: $e');
        }
      }
      return;
    }

    final bounds = LatLngBounds.fromPoints(allBoundsPoints);
    final latDiff = (bounds.north - bounds.south).abs();
    final lngDiff = (bounds.east - bounds.west).abs();

    // If points are practically at the same location (< 10 meters distance)
    if (latDiff < 0.0001 && lngDiff < 0.0001) {
      if (animate) {
        _animatedMapMove(allBoundsPoints.last, 16.5);
      } else {
        try {
          _mapController.move(allBoundsPoints.last, 16.5);
        } catch (e) {
          debugPrint('Map move same location notice: $e');
        }
      }
      return;
    }

    if (animate) {
      _animatedMapMove(bounds.center, _mapController.camera.zoom);
    }
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40.0),
        ),
      );
    } catch (e) {
      try {
        _mapController.move(allBoundsPoints.last, 15.0);
      } catch (err) {
        debugPrint('Map fitCamera fallback notice: $err');
      }
    }
  }

  void _zoomIn() {
    try {
      final currentZoom = _mapController.camera.zoom;
      final nextZoom = (currentZoom + 1.0).clamp(3.0, 19.0);
      _animatedMapMove(
        _mapController.camera.center,
        nextZoom,
        duration: const Duration(milliseconds: 300),
      );
    } catch (e) {
      debugPrint('Map zoomIn notice: $e');
    }
  }

  void _zoomOut() {
    try {
      final currentZoom = _mapController.camera.zoom;
      final nextZoom = (currentZoom - 1.0).clamp(3.0, 19.0);
      _animatedMapMove(
        _mapController.camera.center,
        nextZoom,
        duration: const Duration(milliseconds: 300),
      );
    } catch (e) {
      debugPrint('Map zoomOut notice: $e');
    }
  }

  @override
  void dispose() {
    _animController?.stop();
    _animController?.dispose();
    _animController = null;
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latLngPoints = widget.waypoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    final effectiveUserLocation = (latLngPoints.isNotEmpty)
        ? latLngPoints.last
        : widget.currentLocation;

    // Center on user's last waypoints or current location, fallback to active ghost start point or (0,0)
    final centerLatLng = effectiveUserLocation ??
        widget.activeGhostSegment?.startPoint.toLatLng() ??
        const LatLng(0.0, 0.0);

    // Leaflet OpenStreetMap tile URLs for dark and light themes
    // CartoDB Positron & Dark Matter provide high-contrast street lines and clear labels
    final tileUrl = widget.isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

    // Show markers & route polylines when tracking or when activity has waypoints
    final showRoute = widget.isTracking || latLngPoints.length >= 2;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: centerLatLng,
            initialZoom: 16.5,
            interactionOptions: InteractionOptions(
              flags: widget.interactive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
            onMapReady: () {
              if ((latLngPoints.length >= 2 || widget.activeGhostSegment != null) &&
                  !_hasInitialCentered) {
                _hasInitialCentered = true;
                _autoZoomAndCenterMap();
              }
            },
          ),
          children: [
            TileLayer(
              key: ValueKey(tileUrl),
              urlTemplate: tileUrl,
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.thews.fitnessapp',
              retinaMode: RetinaMode.isHighDensity(context),
              tileProvider: PersistentDiskTileProvider(),
              keepBuffer: 3,
              panBuffer: 2,
              tileDisplay: const TileDisplay.instantaneous(),
              tileBuilder: (context, tileWidget, tile) {
                return ColorFiltered(
                  colorFilter: widget.isDark
                      ? const ColorFilter.matrix([
                          1.2, 0.0, 0.0, 0.0, -8.0,
                          0.0, 1.2, 0.0, 0.0, -8.0,
                          0.0, 0.0, 1.2, 0.0, -8.0,
                          0.0, 0.0, 0.0, 1.0,  0.0,
                        ])
                      : const ColorFilter.matrix([
                          1.05, 0.0,  0.0,  0.0, -6.0,
                          0.0,  1.05, 0.0,  0.0, -6.0,
                          0.0,  0.0,  1.05, 0.0, -6.0,
                          0.0,  0.0,  0.0,  1.0,  0.0,
                        ]),
                  child: Container(
                    color: widget.isDark
                        ? AppColors.darkSurfaceContainerLowest
                        : AppColors.lightSurfaceContainerLow,
                    child: tileWidget,
                  ),
                );
              },
            ),

            // Heatmap Polylines Layer when toggled on
            if (widget.isHeatmapVisible &&
                widget.heatmapRoutes != null &&
                widget.heatmapRoutes!.isNotEmpty)
              HeatmapPolylineLayer(
                polylineRoutes: widget.heatmapRoutes!,
                baseGlowColor: widget.isDark
                    ? AppColors.chestAccent
                    : const Color(0xFFE65100),
              ),

            // 1. Ghost Pre-Path Lead-in Connector Line (from current user position -> Ghost start line)
            if (widget.activeGhostSegment != null && effectiveUserLocation != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      effectiveUserLocation,
                      widget.activeGhostSegment!.startPoint.toLatLng(),
                    ],
                    pattern: StrokePattern.dashed(segments: const [8, 6]),
                    strokeWidth: 3.5,
                    color: AppColors.neonCyan.withValues(alpha: 0.85),
                  ),
                ],
              ),

            // 2. Ghost Racer Target Segment Pre-Path Polyline (Glowing Neon Cyan)
            if (widget.activeGhostSegment != null &&
                widget.activeGhostSegment!.polyline.length >= 2)
              PolylineLayer(
                polylines: [
                  // Outer Glow Halo
                  Polyline(
                    points: widget.activeGhostSegment!.polyline
                        .map((p) => p.toLatLng())
                        .toList(),
                    strokeWidth: 9.5,
                    color: AppColors.neonCyan.withValues(alpha: 0.32),
                  ),
                  // Core Electric Track Polyline
                  Polyline(
                    points: widget.activeGhostSegment!.polyline
                        .map((p) => p.toLatLng())
                        .toList(),
                    strokeWidth: 5.0,
                    color: AppColors.neonCyan,
                    borderColor: Colors.black.withValues(alpha: 0.5),
                    borderStrokeWidth: 1.2,
                  ),
                ],
              ),

            // Route Polyline outlining the whole activity route
            if (showRoute && latLngPoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: latLngPoints,
                    strokeWidth: 5.0,
                    color: widget.isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                  ),
                ],
              ),

            // Marker Layer (Fixed upright markers that do not spin when map rotates)
            MarkerLayer(
              markers: [
                // 1. Ghost Segment Start & Finish Markers
                if (widget.activeGhostSegment != null) ...[
                  Marker(
                    point: widget.activeGhostSegment!.startPoint.toLatLng(),
                    width: 36,
                    height: 36,
                    rotate: false,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
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
                          Icons.flag_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  Marker(
                    point: widget.activeGhostSegment!.endPoint.toLatLng(),
                    width: 36,
                    height: 36,
                    rotate: false,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent.shade700,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
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
                          Icons.sports_score,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],

                // 2. Ghost Runner Position Marker (Moving 👻 along segment, or waiting at start line)
                if (widget.ghostPosition != null ||
                    widget.activeGhostSegment != null)
                  Marker(
                    point: widget.ghostPosition ??
                        widget.activeGhostSegment!.startPoint.toLatLng(),
                    width: 44,
                    height: 44,
                    rotate: false,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonCyan.withValues(alpha: 0.65),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Text('👻', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),

                // 3. User Tracker Markers
                if (effectiveUserLocation != null) ...[
                  if (widget.isTracking) ...[
                    // Active Workout: Start Origin Pin
                    if (latLngPoints.isNotEmpty)
                      Marker(
                        point: latLngPoints.first,
                        width: 32,
                        height: 32,
                        rotate: true,
                        child: const Icon(
                          Icons.trip_origin,
                          color: AppColors.success,
                          size: 26,
                        ),
                      ),
                    // Active Workout: Live Navigation Pointer
                    Marker(
                      point: effectiveUserLocation,
                      width: 40,
                      height: 40,
                      rotate: true,
                      child: Container(
                        decoration: BoxDecoration(
                          color: (widget.isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary)
                              .withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.near_me,
                          color: widget.isDark
                              ? AppColors.primaryVolt
                              : AppColors.lightPrimary,
                          size: 26,
                        ),
                      ),
                    ),
                  ] else ...[
                    // Standby Live Location Pointer with Compass Heading Halo
                    Marker(
                      point: effectiveUserLocation,
                      width: 52,
                      height: 52,
                      rotate: false,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2979FF)
                                  .withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Transform.rotate(
                            angle: widget.headingDegrees *
                                (3.141592653589793 / 180.0),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2979FF),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
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
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
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
                ],
              ],
            ),
          ],
        ),

        // Interactive Map Control Column (Heatmap, Zoom In, Zoom Out, Fit Route, Recenter)
        if (widget.interactive)
          Positioned(
            bottom: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Territory Heatmap Toggle Button (Direct toggle on this map)
                if (widget.showHeatmapButton) ...[
                  _buildControlButton(
                    icon: Icons.local_fire_department_rounded,
                    tooltip: widget.isHeatmapVisible
                        ? 'Hide Heatmap Overlay'
                        : 'Show Heatmap Overlay',
                    iconColor: widget.isHeatmapVisible
                        ? Colors.white
                        : (widget.isDark
                            ? AppColors.chestAccent
                            : const Color(0xFFE65100)),
                    backgroundColor: widget.isHeatmapVisible
                        ? (widget.isDark
                            ? AppColors.chestAccent
                            : const Color(0xFFE65100))
                        : null,
                    borderColor: widget.isDark
                        ? AppColors.chestAccent
                        : const Color(0xFFE65100),
                    onTap: () {
                      if (widget.onHeatmapTap != null) {
                        widget.onHeatmapTap!();
                      } else {
                        context.push('/running/heatmap');
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                ],

                // Zoom In (+)
                _buildControlButton(
                  icon: Icons.add,
                  tooltip: 'Zoom In',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 5),

                // Zoom Out (-)
                _buildControlButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 5),

                // Fit Full Route / Distance Span
                if (latLngPoints.length >= 2) ...[
                  _buildControlButton(
                    icon: Icons.zoom_out_map,
                    tooltip: 'Fit Entire Route',
                    onTap: () => _autoZoomAndCenterMap(animate: true),
                  ),
                  const SizedBox(height: 5),
                ],

                // Recenter to Last / Current Position (Smoothly animated)
                _buildControlButton(
                  icon: Icons.navigation_rounded,
                  tooltip: 'Recenter Location',
                  onTap: () {
                    final target = latLngPoints.isNotEmpty
                        ? latLngPoints.last
                        : const LatLng(0.0, 0.0);
                    _animatedMapMove(target, 16.5);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    final defaultColor =
        widget.isDark ? AppColors.primaryVolt : AppColors.lightPrimary;
    return Material(
      color: Colors.transparent,
      elevation: 3,
      shape: const CircleBorder(),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: backgroundColor ??
                  (widget.isDark
                          ? AppColors.darkSurfaceContainerHighest
                          : Colors.white)
                      .withValues(alpha: 0.95),
              shape: BoxShape.circle,
              border: Border.all(
                color: (borderColor ?? defaultColor).withValues(alpha: 0.7),
                width: 1.2,
              ),
            ),
            child: Icon(
              icon,
              color: iconColor ?? defaultColor,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}
