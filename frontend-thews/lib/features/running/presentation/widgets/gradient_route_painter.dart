import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/gpx_parser.dart';

enum RouteColorMode {
  solidVolt,
  slopeGradient,
  heartRateZone,
}

class SlopeGradientUtils {
  static const Distance _distanceCalculator = Distance();

  /// Calculates instantaneous slope grade percentage between two GPX points.
  static double calculateGradePercent(GpxPoint p1, GpxPoint p2) {
    final dist = _distanceCalculator.as(
      LengthUnit.Meter,
      LatLng(p1.latitude, p1.longitude),
      LatLng(p2.latitude, p2.longitude),
    );
    if (dist < 1.0) return 0.0;
    final elevDiff = p2.elevation - p1.elevation;
    return (elevDiff / dist) * 100.0;
  }

  /// Resolves the color for a specific slope grade percentage.
  static Color getSlopeColor(double gradePercent, {bool isDark = true}) {
    if (gradePercent < -3.0) {
      // Downhill (< -3%)
      return const Color(0xFF00E5FF); // Electric Cyan
    } else if (gradePercent <= 3.0) {
      // Flat / Gentle (±3%)
      return isDark ? AppColors.primaryVolt : const Color(0xFF00C853); // Neon Green/Volt
    } else if (gradePercent <= 8.0) {
      // Rolling Incline (4-7%)
      return const Color(0xFFFFD600); // Amber Yellow
    } else {
      // Steep Climb (> 8%)
      return const Color(0xFFFF1744); // Crimson / Burning Red
    }
  }

  /// Resolves the color for a heart rate BPM level.
  static Color getHeartRateColor(int? bpm) {
    if (bpm == null || bpm <= 0) return const Color(0xFF9E9E9E);
    if (bpm < 120) return const Color(0xFF00E5FF); // Zone 1 - Recovery
    if (bpm < 140) return const Color(0xFF00E676); // Zone 2 - Aerobic Base
    if (bpm < 160) return const Color(0xFFFFD600); // Zone 3 - Tempo
    if (bpm < 175) return const Color(0xFFFF9100); // Zone 4 - Threshold
    return const Color(0xFFFF1744); // Zone 5 - Anaerobic / Max
  }

  /// Builds a list of colored [Polyline] segments reflecting slope grade changes.
  static List<Polyline> buildSlopeGradientPolylines(
    List<GpxPoint> waypoints, {
    bool isDark = true,
    double strokeWidth = 5.0,
  }) {
    if (waypoints.length < 2) return [];

    final List<Polyline> polylines = [];
    final smoothedElevations = _smoothElevations(waypoints);

    for (int i = 0; i < waypoints.length - 1; i++) {
      final p1 = waypoints[i];
      final p2 = waypoints[i + 1];

      final dist = _distanceCalculator.as(
        LengthUnit.Meter,
        LatLng(p1.latitude, p1.longitude),
        LatLng(p2.latitude, p2.longitude),
      );

      final elevDiff = smoothedElevations[i + 1] - smoothedElevations[i];
      final grade = (dist >= 1.0) ? (elevDiff / dist) * 100.0 : 0.0;
      final segmentColor = getSlopeColor(grade, isDark: isDark);

      polylines.add(
        Polyline(
          points: [
            LatLng(p1.latitude, p1.longitude),
            LatLng(p2.latitude, p2.longitude),
          ],
          strokeWidth: strokeWidth,
          color: segmentColor,
          borderColor: Colors.black.withValues(alpha: 0.25),
          borderStrokeWidth: 0.8,
        ),
      );
    }

    return polylines;
  }

  /// Builds a list of colored [Polyline] segments reflecting relative speed/elevation gradient.
  static List<Polyline> buildHeartRateZonePolylines(
    List<GpxPoint> waypoints, {
    double strokeWidth = 5.0,
  }) {
    if (waypoints.length < 2) return [];

    final List<Polyline> polylines = [];
    for (int i = 0; i < waypoints.length - 1; i++) {
      final p1 = waypoints[i];
      final p2 = waypoints[i + 1];
      
      final dt = p2.timestamp.difference(p1.timestamp).inSeconds;
      final dist = _distanceCalculator.as(
        LengthUnit.Meter,
        LatLng(p1.latitude, p1.longitude),
        LatLng(p2.latitude, p2.longitude),
      );
      final speedMps = dt > 0 ? dist / dt : 0.0;
      final paceSecKm = speedMps > 0.5 ? 1000.0 / speedMps : 0.0;

      // Color by pace / effort intensity
      Color color = const Color(0xFF00E676);
      if (paceSecKm > 0 && paceSecKm < 300) { // faster than 5:00/km
        color = const Color(0xFFFF1744);
      } else if (paceSecKm >= 300 && paceSecKm < 360) { // 5:00 - 6:00/km
        color = const Color(0xFFFF9100);
      } else if (paceSecKm >= 360 && paceSecKm < 420) { // 6:00 - 7:00/km
        color = const Color(0xFFFFD600);
      }

      polylines.add(
        Polyline(
          points: [
            LatLng(p1.latitude, p1.longitude),
            LatLng(p2.latitude, p2.longitude),
          ],
          strokeWidth: strokeWidth,
          color: color,
          borderColor: Colors.black.withValues(alpha: 0.25),
          borderStrokeWidth: 0.8,
        ),
      );
    }

    return polylines;
  }

  /// 3-Point Gaussian-weighted window smoothing on elevation to remove GPS micro-jitter
  static List<double> _smoothElevations(List<GpxPoint> points) {
    final elevations = points.map((p) => p.elevation).toList();
    if (elevations.length < 3) return elevations;

    final List<double> smoothed = List.filled(elevations.length, 0.0);
    smoothed[0] = elevations[0];
    smoothed[elevations.length - 1] = elevations.last;

    for (int i = 1; i < elevations.length - 1; i++) {
      smoothed[i] = (elevations[i - 1] * 0.25) +
          (elevations[i] * 0.50) +
          (elevations[i + 1] * 0.25);
    }
    return smoothed;
  }
}

/// Floating glass legend chip for slope gradient terrain visualization.
class SlopeGradientLegendChip extends StatelessWidget {
  final bool isDark;

  const SlopeGradientLegendChip({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark
                ? AppColors.darkSurfaceContainerHighest
                : Colors.white)
            .withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendItem(const Color(0xFF00E5FF), 'Downhill (< -3%)'),
          const SizedBox(width: 8),
          _legendItem(const Color(0xFFC6FF00), 'Flat (±3%)'),
          const SizedBox(width: 8),
          _legendItem(const Color(0xFFFFD600), 'Roll (4-7%)'),
          const SizedBox(width: 8),
          _legendItem(const Color(0xFFFF1744), 'Climb (8%+)'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.tinyLabel(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ).copyWith(fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
