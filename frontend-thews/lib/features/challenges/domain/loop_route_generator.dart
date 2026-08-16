import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../../../core/services/street_routing_service.dart';

/// Algorithmic loop route generator that calculates real road-snapped closed circuits
/// starting and finishing at the athlete's exact current coordinate.
class LoopRouteGenerator {
  static const double earthRadiusMeters = 6371000.0;
  static const Distance _distanceCalculator = Distance();
  static final StreetRoutingService _defaultRoutingService =
      StreetRoutingService();

  /// Generates a real-world closed loop snapped to actual streets, roads, and city blocks
  /// starting and finishing at [startLocation].
  static Future<StreetRouteResult> generateStreetSnappedLoopRoute({
    required LatLng startLocation,
    required double targetDistanceMeters,
    double bearingOffsetDeg = 45.0,
    StreetRoutingService? routingService,
  }) async {
    final service = routingService ?? _defaultRoutingService;
    return service.generateStreetSnappedLoop(
      startLocation: startLocation,
      targetDistanceMeters: targetDistanceMeters,
      bearingOffsetDeg: bearingOffsetDeg,
    );
  }

  /// Generates an organic closed-circuit loop of approximately [targetDistanceMeters]
  /// starting and finishing at [startLocation].
  ///
  /// [bearingOffsetDeg] specifies the general direction the loop expands toward (0=North, 90=East).
  /// [pointCount] specifies the number of waypoints along the loop.
  static List<LatLng> generateLoopRoute({
    required LatLng startLocation,
    required double targetDistanceMeters,
    double bearingOffsetDeg = 45.0,
    int pointCount = 28,
  }) {
    if (targetDistanceMeters <= 100) {
      return [startLocation, startLocation];
    }

    final radiusMeters = targetDistanceMeters / (2 * math.pi);

    final startLatRad = _degToRad(startLocation.latitude);
    final startLngRad = _degToRad(startLocation.longitude);
    final bearingRad = _degToRad(bearingOffsetDeg);

    final centerLatRad = math.asin(
      math.sin(startLatRad) * math.cos(radiusMeters / earthRadiusMeters) +
          math.cos(startLatRad) *
              math.sin(radiusMeters / earthRadiusMeters) *
              math.cos(bearingRad),
    );

    final centerLngRad =
        startLngRad +
        math.atan2(
          math.sin(bearingRad) *
              math.sin(radiusMeters / earthRadiusMeters) *
              math.cos(startLatRad),
          math.cos(radiusMeters / earthRadiusMeters) -
              math.sin(startLatRad) * math.sin(centerLatRad),
        );

    final centerLat = _radToDeg(centerLatRad);
    final centerLng = _radToDeg(centerLngRad);

    final angleFromCenterToStart = math.atan2(
      startLocation.latitude - centerLat,
      (startLocation.longitude - centerLng) *
          math.cos(_degToRad(centerLat)),
    );

    final waypoints = <LatLng>[];

    for (int i = 0; i <= pointCount; i++) {
      if (i == 0 || i == pointCount) {
        waypoints.add(startLocation);
        continue;
      }

      final progress = i / pointCount;
      final angle = angleFromCenterToStart + (2 * math.pi * progress);

      final harmonic = 1.0 + 0.06 * math.sin(3 * angle);
      final currentRadius = radiusMeters * harmonic;

      final deltaLat = (currentRadius * math.sin(angle)) / 111320.0;
      final deltaLng =
          (currentRadius * math.cos(angle)) /
          (111320.0 * math.cos(_degToRad(centerLat)));

      waypoints.add(LatLng(centerLat + deltaLat, centerLng + deltaLng));
    }

    return waypoints;
  }

  /// Measures total distance across a list of GPS waypoints in meters.
  static double calculateTotalRouteDistance(List<LatLng> waypoints) {
    if (waypoints.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      total += _distanceCalculator.as(
        LengthUnit.Meter,
        waypoints[i],
        waypoints[i + 1],
      );
    }
    return total;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
  static double _radToDeg(double rad) => rad * (180.0 / math.pi);
}
