import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../../core/theme/app_colors.dart';

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
