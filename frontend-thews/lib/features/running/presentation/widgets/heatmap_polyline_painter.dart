import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/gpx_parser.dart';

/// StreamProvider providing all parsed GPS routes across all historical activities for heatmap rendering.
final heatmapRoutesProvider =
    StreamProvider.autoDispose<List<List<LatLng>>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllRunActivities().map((activities) {
    final List<List<LatLng>> routes = [];
    for (final act in activities) {
      if (act.gpxData != null && act.gpxData!.isNotEmpty) {
        final gpxPoints = GpxParser.parseGpxXml(act.gpxData!);
        final latLngs =
            gpxPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
        if (latLngs.isNotEmpty) {
          routes.add(latLngs);
        }
      }
    }
    return routes;
  });
});

/// Renders glowing multi-pass neon polylines for the running route heatmap.
class HeatmapPolylineLayer extends StatelessWidget {
  final List<List<dynamic>> polylineRoutes; // List of List<LatLng>
  final Color baseGlowColor;

  const HeatmapPolylineLayer({
    super.key,
    required this.polylineRoutes,
    this.baseGlowColor = AppColors.primaryVolt,
  });

  @override
  Widget build(BuildContext context) {
    if (polylineRoutes.isEmpty) return const SizedBox.shrink();

    return PolylineLayer(
      polylines: [
        // Layer 1: Ambient Outer Glow (Broad width, soft opacity)
        for (final route in polylineRoutes)
          Polyline(
            points: route.cast(),
            strokeWidth: 9.0,
            color: baseGlowColor.withValues(alpha: 0.15),
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ),

        // Layer 2: Mid-Glow (Medium width, moderate opacity)
        for (final route in polylineRoutes)
          Polyline(
            points: route.cast(),
            strokeWidth: 5.0,
            color: baseGlowColor.withValues(alpha: 0.40),
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ),

        // Layer 3: High-Intensity Core (Narrow width, solid bright neon)
        for (final route in polylineRoutes)
          Polyline(
            points: route.cast(),
            strokeWidth: 2.2,
            color: baseGlowColor,
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ),
      ],
    );
  }
}
