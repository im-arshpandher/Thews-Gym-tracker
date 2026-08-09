import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
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
      final newCenter = LatLng(
        widget.waypoints.last.latitude,
        widget.waypoints.last.longitude,
      );
      // Auto move map camera to street-level zoom when initial user GPS position arrives or during active tracking
      if (!_hasInitialCentered || widget.isTracking) {
        _hasInitialCentered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapController.move(newCenter, 16.5);
          } catch (_) {}
        });
      }
    }
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

    // Leaflet OpenStreetMap tile URLs for dark and light themes (CartoDB internationalized Latin/English labels)
    final tileUrl = widget.isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

    // Show markers & route polylines when tracking or when activity has waypoints
    final showRoute = widget.isTracking || latLngPoints.length >= 2;

    final headingRad = widget.headingDegrees * (math.pi / 180.0);

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
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              subdomains: const ['a', 'b', 'c'],
              retinaMode: RetinaMode.isHighDensity(context),
              tileProvider: PersistentDiskTileProvider(),
              keepBuffer: 3,
              panBuffer: 2,
              tileDisplay: const TileDisplay.instantaneous(),
              tileBuilder: (context, tileWidget, tile) {
                return Container(
                  color: widget.isDark
                      ? AppColors.darkSurfaceContainerLowest
                      : AppColors.lightSurfaceContainerLow,
                  child: tileWidget,
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

        // Round Navigation Icon at Bottom Right of Map (Recenters map without starting tracking)
        if (widget.interactive)
          Positioned(
            bottom: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              elevation: 4,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  final target = latLngPoints.isNotEmpty
                      ? latLngPoints.last
                      : const LatLng(0.0, 0.0);
                  _mapController.move(target, 16.5);
                },
                child: Container(
                  width: 44,
                  height: 44,
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
                    Icons.navigation_rounded,
                    color: widget.isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
