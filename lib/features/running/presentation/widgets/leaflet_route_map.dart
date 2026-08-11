import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/tile_cache_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/gpx_parser.dart';

class LeafletRouteMap extends StatefulWidget {
  final List<GpxPoint> waypoints;
  final bool isDark;
  final bool interactive;
  final bool isTracking;
  final double headingDegrees;

  const LeafletRouteMap({
    super.key,
    required this.waypoints,
    required this.isDark,
    this.interactive = true,
    this.isTracking = false,
    this.headingDegrees = 0.0,
  });

  @override
  State<LeafletRouteMap> createState() => _LeafletRouteMapState();
}

class _LeafletRouteMapState extends State<LeafletRouteMap> {
  late final MapController _mapController;
  bool _hasInitialCentered = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant LeafletRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.waypoints.isNotEmpty) {
      if (!_hasInitialCentered) {
        _hasInitialCentered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _autoZoomAndCenterMap();
        });
      } else if (widget.isTracking && widget.waypoints.length != oldWidget.waypoints.length) {
        // Auto follow live user location during active tracking
        final newCenter = LatLng(
          widget.waypoints.last.latitude,
          widget.waypoints.last.longitude,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapController.move(newCenter, _mapController.camera.zoom);
          } catch (_) {}
        });
      }
    }
  }

  /// Automatically zooms and centers the map based on the geographic distance covered by the waypoints.
  void _autoZoomAndCenterMap() {
    if (widget.waypoints.isEmpty) return;

    final latLngPoints = widget.waypoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    if (latLngPoints.length < 2) {
      try {
        _mapController.move(latLngPoints.first, 16.5);
      } catch (_) {}
      return;
    }

    final bounds = LatLngBounds.fromPoints(latLngPoints);
    final latDiff = (bounds.north - bounds.south).abs();
    final lngDiff = (bounds.east - bounds.west).abs();

    // If points are practically at the same location (< 10 meters distance)
    if (latDiff < 0.0001 && lngDiff < 0.0001) {
      try {
        _mapController.move(latLngPoints.last, 16.5);
      } catch (_) {}
      return;
    }

    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40.0),
        ),
      );
    } catch (_) {
      try {
        _mapController.move(latLngPoints.last, 15.0);
      } catch (_) {}
    }
  }

  void _zoomIn() {
    try {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(_mapController.camera.center, (currentZoom + 1.0).clamp(3.0, 19.0));
    } catch (_) {}
  }

  void _zoomOut() {
    try {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(_mapController.camera.center, (currentZoom - 1.0).clamp(3.0, 19.0));
    } catch (_) {}
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latLngPoints = widget.waypoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // Center on user's last waypoints, fallback to (0,0) if awaiting location
    final centerLatLng = latLngPoints.isNotEmpty
        ? latLngPoints.last
        : const LatLng(0.0, 0.0);

    // Leaflet OpenStreetMap tile URLs for dark and light themes
    // Standard OpenStreetMap provides high-contrast street lines and clear labels
    final tileUrl = widget.isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

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
              if (latLngPoints.length >= 2 && !_hasInitialCentered) {
                _hasInitialCentered = true;
                _autoZoomAndCenterMap();
              }
            },
          ),
          children: [
            TileLayer(
              key: ValueKey(tileUrl),
              urlTemplate: tileUrl,
              subdomains: widget.isDark ? const ['a', 'b', 'c'] : const [],
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
              userAgentPackageName: 'com.thews.gymtracker',
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
            if (latLngPoints.isNotEmpty)
              MarkerLayer(
                markers: [
                  if (widget.isTracking) ...[
                    // Active Workout: Start Origin Pin
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
                      point: latLngPoints.last,
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
                    // Standby (Out of Workout): Upright Location Drop Pin
                    Marker(
                      point: latLngPoints.last,
                      width: 40,
                      height: 40,
                      rotate: true,
                      child: Icon(
                        Icons.location_on,
                        color: widget.isDark
                            ? AppColors.primaryVolt
                            : AppColors.lightPrimary,
                        size: 34,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),

        // Interactive Map Control Column (Zoom In, Zoom Out, Fit Route, Recenter)
        if (widget.interactive)
          Positioned(
            bottom: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom In (+)
                _buildControlButton(
                  icon: Icons.add,
                  tooltip: 'Zoom In',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 8),

                // Zoom Out (-)
                _buildControlButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 8),

                // Fit Full Route / Distance Span
                if (latLngPoints.length >= 2) ...[
                  _buildControlButton(
                    icon: Icons.zoom_out_map,
                    tooltip: 'Fit Entire Route',
                    onTap: _autoZoomAndCenterMap,
                  ),
                  const SizedBox(height: 8),
                ],

                // Recenter to Last / Current Position
                _buildControlButton(
                  icon: Icons.navigation_rounded,
                  tooltip: 'Recenter Location',
                  onTap: () {
                    final target = latLngPoints.isNotEmpty
                        ? latLngPoints.last
                        : const LatLng(0.0, 0.0);
                    try {
                      _mapController.move(target, 16.5);
                    } catch (_) {}
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
  }) {
    return Material(
      color: Colors.transparent,
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: (widget.isDark
                    ? AppColors.darkSurfaceContainerHighest
                    : Colors.white)
                .withValues(alpha: 0.95),
            shape: BoxShape.circle,
            border: Border.all(
              color: (widget.isDark
                      ? AppColors.primaryVolt
                      : AppColors.lightPrimary)
                  .withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: widget.isDark
                ? AppColors.primaryVolt
                : AppColors.lightPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }
}
