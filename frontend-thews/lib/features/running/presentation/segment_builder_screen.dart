import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/services/segment_storage_service.dart';
import '../../../core/services/tile_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/gpx_parser.dart';
import '../domain/live_segment_engine.dart';
import '../domain/live_segment_models.dart';

/// Interactive tool allowing athletes to create custom Live Segments from any past workout route.
class SegmentBuilderScreen extends ConsumerStatefulWidget {
  final int activityId;

  const SegmentBuilderScreen({super.key, required this.activityId});

  @override
  ConsumerState<SegmentBuilderScreen> createState() =>
      _SegmentBuilderScreenState();
}

class _SegmentBuilderScreenState extends ConsumerState<SegmentBuilderScreen> {
  final TextEditingController _nameController =
      TextEditingController(text: 'My Custom Segment');
  final MapController _mapController = MapController();

  List<GpxPoint> _allPoints = [];
  double _startIndex = 0;
  double _endIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivityRoute();
  }

  Future<void> _loadActivityRoute() async {
    final db = ref.read(databaseProvider);
    final activity = await db.getRunActivityById(widget.activityId);

    if (activity != null &&
        activity.gpxData != null &&
        activity.gpxData!.isNotEmpty) {
      final points = GpxParser.parseGpxXml(activity.gpxData!);
      if (points.isNotEmpty) {
        setState(() {
          _allPoints = points;
          _startIndex = 0;
          _endIndex = (points.length - 1).toDouble();
          _isLoading = false;
        });
        return;
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_allPoints.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('CREATE SEGMENT')),
        body: const Center(
          child: Text('Insufficient GPS points to construct a segment.'),
        ),
      );
    }

    final sIdx = _startIndex.round().clamp(0, _allPoints.length - 2);
    final eIdx = _endIndex.round().clamp(sIdx + 1, _allPoints.length - 1);

    final segmentPoints = _allPoints.sublist(sIdx, eIdx + 1);
    final segmentLatLngs =
        segmentPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final allLatLngs =
        _allPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();

    final distMeters = GpxParser.calculateTotalDistanceMeters(segmentPoints);
    final eleGain = GpxParser.calculateElevationGainMeters(segmentPoints);
    final durationSecs = segmentPoints.last.timestamp
        .difference(segmentPoints.first.timestamp)
        .inSeconds
        .abs();

    final startPoint = segmentPoints.first;
    final endPoint = segmentPoints.last;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'CREATE LIVE SEGMENT',
          style: AppTypography.sectionTitle(
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ).copyWith(fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // 1. Interactive Map View
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: segmentLatLngs.first,
                initialZoom: 14.5,
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
                // Full route in dim color
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: allLatLngs,
                      strokeWidth: 3.5,
                      color: isDark
                          ? AppColors.darkSurfaceContainerHighest
                          : Colors.grey.shade400,
                    ),
                  ],
                ),
                // Highlighted selected segment in Neon Volt
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: segmentLatLngs,
                      strokeWidth: 6.0,
                      color: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary,
                      strokeCap: StrokeCap.round,
                    ),
                  ],
                ),
                // Start and End Markers
                MarkerLayer(
                  markers: [
                    Marker(
                      point: segmentLatLngs.first,
                      width: 32,
                      height: 32,
                      child: const Icon(
                        Icons.flag,
                        color: Colors.greenAccent,
                        size: 28,
                      ),
                    ),
                    Marker(
                      point: segmentLatLngs.last,
                      width: 32,
                      height: 32,
                      child: const Icon(
                        Icons.sports_score,
                        color: Colors.amberAccent,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Bottom Controls & Segment Details Sheet
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceContainerLow
                  : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(
                color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Segment Name Input Field
                TextField(
                  controller: _nameController,
                  style: AppTypography.cardTitle(),
                  decoration: InputDecoration(
                    labelText: 'SEGMENT NAME',
                    labelStyle: AppTypography.labelCaps(
                      color: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Range Slider for Start/End Trimming
                Text(
                  'ADJUST START & FINISH POINTS',
                  maxLines: 1,
                  softWrap: false,
                  style: AppTypography.labelCaps(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ).copyWith(fontSize: 10),
                ),
                RangeSlider(
                  values: RangeValues(_startIndex, _endIndex),
                  min: 0,
                  max: (_allPoints.length - 1).toDouble(),
                  divisions: _allPoints.length,
                  activeColor: isDark
                      ? AppColors.primaryVolt
                      : AppColors.lightPrimary,
                  onChanged: (values) {
                    if (values.end - values.start >= 1) {
                      setState(() {
                        _startIndex = values.start;
                        _endIndex = values.end;
                      });
                    }
                  },
                ),

                // Telemetry Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricCol(
                      label: 'DISTANCE',
                      value: distMeters >= 1000
                          ? '${(distMeters / 1000).toStringAsFixed(2)} km'
                          : '${distMeters.toInt()} m',
                      isDark: isDark,
                    ),
                    _buildMetricCol(
                      label: 'ELEVATION GAIN',
                      value: '+${eleGain.toInt()} m',
                      isDark: isDark,
                    ),
                    _buildMetricCol(
                      label: 'BASE PR TIME',
                      value: durationSecs > 0
                          ? '${(durationSecs ~/ 60).toString().padLeft(2, '0')}:${(durationSecs % 60).toString().padLeft(2, '0')}'
                          : '--:--',
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Save Segment Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = _nameController.text.trim().isEmpty
                          ? 'Custom Segment'
                          : _nameController.text.trim();

                      final newSegment = RunSegment(
                        id: 'seg_${DateTime.now().millisecondsSinceEpoch}',
                        name: name,
                        startPoint: SegmentCoordinate(
                          latitude: startPoint.latitude,
                          longitude: startPoint.longitude,
                          elevation: startPoint.elevation,
                        ),
                        endPoint: SegmentCoordinate(
                          latitude: endPoint.latitude,
                          longitude: endPoint.longitude,
                          elevation: endPoint.elevation,
                        ),
                        distanceMeters: distMeters,
                        bestTimeSeconds: durationSecs > 0 ? durationSecs : null,
                        elevationGainMeters: eleGain,
                        polyline: segmentPoints
                            .map(
                              (p) => SegmentCoordinate(
                                latitude: p.latitude,
                                longitude: p.longitude,
                                elevation: p.elevation,
                              ),
                            )
                            .toList(),
                        createdAt: DateTime.now(),
                        attemptCount: 1,
                      );

                      await ref
                          .read(segmentsProvider.notifier)
                          .addSegment(newSegment);
                      ref
                          .read(liveSegmentEngineProvider.notifier)
                          .refreshSegments();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Segment "$name" created successfully!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        context.pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary,
                      foregroundColor: isDark
                          ? AppColors.primaryVoltOn
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'SAVE LIVE SEGMENT',
                      maxLines: 1,
                      softWrap: false,
                      style: AppTypography.labelCaps().copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
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

  Widget _buildMetricCol({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          softWrap: false,
          style: AppTypography.cardTitle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ).copyWith(fontWeight: FontWeight.bold, fontSize: 15),
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
}
