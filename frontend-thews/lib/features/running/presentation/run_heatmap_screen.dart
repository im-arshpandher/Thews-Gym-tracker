import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/gpx_parser.dart';
import 'widgets/heatmap_polyline_painter.dart';

/// Fullscreen interactive GPS Route Heatmap Explorer.
class RunHeatmapScreen extends ConsumerStatefulWidget {
  const RunHeatmapScreen({super.key});

  @override
  ConsumerState<RunHeatmapScreen> createState() => _RunHeatmapScreenState();
}

class _RunHeatmapScreenState extends ConsumerState<RunHeatmapScreen>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  AnimationController? _animController;
  bool _isMapReady = false;
  String _lastFittedSignature = '';

  String _selectedActivityFilter = 'all'; // 'all', 'jog', 'cycle'
  String _selectedDateFilter = 'all_time'; // 'all_time', 'this_year', 'last_30_days'

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
      } catch (_) {}
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

  void _fitTerritory(List<List<LatLng>> routes, {bool animate = false}) {
    final allPoints = routes.expand((r) => r).toList();
    if (allPoints.isEmpty) return;

    if (allPoints.length < 2) {
      if (animate) {
        _animatedMapMove(allPoints.first, 16.5);
      } else {
        try {
          _mapController.move(allPoints.first, 16.5);
        } catch (_) {}
      }
      return;
    }

    final bounds = LatLngBounds.fromPoints(allPoints);
    final latDiff = (bounds.north - bounds.south).abs();
    final lngDiff = (bounds.east - bounds.west).abs();

    if (latDiff < 0.0001 && lngDiff < 0.0001) {
      if (animate) {
        _animatedMapMove(bounds.center, 16.5);
      } else {
        try {
          _mapController.move(bounds.center, 16.5);
        } catch (_) {}
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
          padding: const EdgeInsets.only(
            top: 130.0,
            bottom: 120.0,
            left: 36.0,
            right: 36.0,
          ),
        ),
      );
    } catch (_) {
      try {
        _mapController.move(bounds.center, 16.0);
      } catch (_) {}
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'TERRITORY HEATMAP',
          style: AppTypography.sectionTitle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ).copyWith(fontSize: 18),
        ),
      ),
      body: StreamBuilder<List<RunActivityData>>(
        stream: db.watchAllRunActivities(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allActivities = snapshot.data ?? [];
          final filteredActivities = _filterActivities(allActivities);

          // Extract polylines
          final List<List<LatLng>> routes = [];
          double totalDistanceMeters = 0.0;
          double totalElevationGainMeters = 0.0;

          for (final act in filteredActivities) {
            totalDistanceMeters += act.distanceMeters;
            totalElevationGainMeters += act.elevationGainMeters;

            if (act.gpxData != null && act.gpxData!.isNotEmpty) {
              final gpxPoints = GpxParser.parseGpxXml(act.gpxData!);
              final latLngs = gpxPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
              if (latLngs.isNotEmpty) {
                routes.add(latLngs);
              }
            }
          }

          final allPoints = routes.expand((r) => r).toList();
          final defaultCenter = allPoints.isNotEmpty
              ? (allPoints.length >= 2
                  ? LatLngBounds.fromPoints(allPoints).center
                  : allPoints.first)
              : const LatLng(37.7749, -122.4194);

          final currentSignature =
              '${routes.length}_${_selectedActivityFilter}_${_selectedDateFilter}_${allPoints.length}';
          if (currentSignature != _lastFittedSignature && _isMapReady && routes.isNotEmpty) {
            _lastFittedSignature = currentSignature;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitTerritory(routes, animate: true);
            });
          }

          return Stack(
            children: [
              // 1. Interactive Heatmap Vector Map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: defaultCenter,
                  initialZoom: allPoints.isNotEmpty ? 16.0 : 13.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                  onMapReady: () {
                    _isMapReady = true;
                    if (routes.isNotEmpty) {
                      _lastFittedSignature = currentSignature;
                      _fitTerritory(routes, animate: false);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: isDark
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    retinaMode: RetinaMode.isHighDensity(context),
                    userAgentPackageName: 'com.thews.fitnessapp',
                  ),
                  HeatmapPolylineLayer(
                    polylineRoutes: routes,
                    baseGlowColor: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                  ),
                ],
              ),

              // 2. Top Filter Bar (Sport & Date Range)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Column(
                  children: [
                    // Activity Type Filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: 'All Sports',
                            isSelected: _selectedActivityFilter == 'all',
                            onTap: () => setState(() => _selectedActivityFilter = 'all'),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Jog / Runs',
                            isSelected: _selectedActivityFilter == 'jog',
                            onTap: () => setState(() => _selectedActivityFilter = 'jog'),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Cycling',
                            isSelected: _selectedActivityFilter == 'cycle',
                            onTap: () => setState(() => _selectedActivityFilter = 'cycle'),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Date Horizon Filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: 'All Time',
                            isSelected: _selectedDateFilter == 'all_time',
                            onTap: () => setState(() => _selectedDateFilter = 'all_time'),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'This Year',
                            isSelected: _selectedDateFilter == 'this_year',
                            onTap: () => setState(() => _selectedDateFilter = 'this_year'),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Last 30 Days',
                            isSelected: _selectedDateFilter == 'last_30_days',
                            onTap: () => setState(() => _selectedDateFilter = 'last_30_days'),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Floating Map Controls (Zoom In, Zoom Out, Fit Territory)
              Positioned(
                right: 14,
                bottom: 110,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGlassControlButton(
                      icon: Icons.add,
                      tooltip: 'Zoom In',
                      isDark: isDark,
                      onTap: _zoomIn,
                    ),
                    const SizedBox(height: 8),
                    _buildGlassControlButton(
                      icon: Icons.remove,
                      tooltip: 'Zoom Out',
                      isDark: isDark,
                      onTap: _zoomOut,
                    ),
                    const SizedBox(height: 8),
                    _buildGlassControlButton(
                      icon: Icons.center_focus_strong,
                      tooltip: 'Fit Heatmap Territory',
                      isDark: isDark,
                      onTap: () => _fitTerritory(routes, animate: true),
                    ),
                  ],
                ),
              ),

              // 4. Floating Explorer Telemetry Card (Bottom)
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainerLow.withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        label: 'TERRITORY DISTANCE',
                        value: '${(totalDistanceMeters / 1000.0).toStringAsFixed(1)} km',
                        isDark: isDark,
                        highlightColor: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                      ),
                      Container(
                        height: 36,
                        width: 1,
                        color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
                      ),
                      _buildStatColumn(
                        label: 'ELEVATION CLIMBED',
                        value: '${totalElevationGainMeters.toInt()} m',
                        isDark: isDark,
                      ),
                      Container(
                        height: 36,
                        width: 1,
                        color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
                      ),
                      _buildStatColumn(
                        label: 'ACTIVITIES',
                        value: '${filteredActivities.length}',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlassControlButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final defaultColor = isDark ? AppColors.primaryVolt : AppColors.lightPrimary;
    return Material(
      color: Colors.transparent,
      elevation: 4,
      shape: const CircleBorder(),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (isDark
                      ? AppColors.darkSurfaceContainerHighest
                      : Colors.white)
                  .withValues(alpha: 0.95),
              shape: BoxShape.circle,
              border: Border.all(
                color: defaultColor.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: defaultColor,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final activeColor = isDark ? AppColors.primaryVolt : AppColors.lightPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : (isDark ? AppColors.darkSurfaceContainerLow : Colors.white)
                  .withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? AppColors.darkOutline : AppColors.lightOutline),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: AppTypography.labelCaps(
            color: isSelected
                ? (isDark ? AppColors.primaryVoltOn : Colors.white)
                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ).copyWith(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required String label,
    required String value,
    required bool isDark,
    Color? highlightColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          softWrap: false,
          style: AppTypography.cardTitle(
            color: highlightColor ??
                (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ).copyWith(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: AppTypography.labelCaps(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ).copyWith(fontSize: 9),
        ),
      ],
    );
  }

  List<RunActivityData> _filterActivities(List<RunActivityData> all) {
    final now = DateTime.now();

    return all.where((a) {
      // Activity type filter
      if (_selectedActivityFilter != 'all' &&
          a.activityType.toLowerCase() != _selectedActivityFilter.toLowerCase()) {
        return false;
      }

      // Date horizon filter
      if (_selectedDateFilter == 'this_year' && a.startTime.year != now.year) {
        return false;
      }
      if (_selectedDateFilter == 'last_30_days') {
        final daysDiff = now.difference(a.startTime).inDays;
        if (daysDiff > 30) return false;
      }

      return true;
    }).toList();
  }
}
