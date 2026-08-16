import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Result of a real-world road snapped routing query.
class StreetRouteResult {
  final List<LatLng> waypoints;
  final double distanceMeters;
  final double durationSeconds;
  final bool isSnappedToRoads;

  const StreetRouteResult({
    required this.waypoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.isSnappedToRoads,
  });
}

/// Service that integrates with OpenStreetMap / OSRM foot routing engine
/// to snap athletic routes to actual real-world roads, streets, sidewalks, and city blocks.
class StreetRoutingService {
  final http.Client _client;

  // Public OSRM foot routing servers (OpenStreetMap road network)
  static const String _primaryOsrmBase =
      'https://routing.openstreetmap.de/routed-foot/route/v1/driving';
  static const String _fallbackOsrmBase =
      'https://router.project-osrm.org/route/v1/foot';

  StreetRoutingService({http.Client? client}) : _client = client ?? http.Client();

  /// Calculates a closed-loop route snapped to real roads starting and finishing at [startLocation].
  ///
  /// [targetDistanceMeters] is the desired loop distance (e.g., 3000m, 5000m, 10000m).
  /// [bearingOffsetDeg] rotates the neighborhood sector (e.g., North-East, South-West).
  Future<StreetRouteResult> generateStreetSnappedLoop({
    required LatLng startLocation,
    required double targetDistanceMeters,
    double bearingOffsetDeg = 45.0,
  }) async {
    // 1. Calculate milestone city block waypoints around the athlete's neighborhood
    final milestones = _calculateBlockMilestones(
      startLocation: startLocation,
      targetDistanceMeters: targetDistanceMeters,
      bearingOffsetDeg: bearingOffsetDeg,
    );

    // 2. Try routing across real streets via OSRM
    try {
      final route = await _queryOsrmRoute(milestones, _primaryOsrmBase);
      if (route != null && route.waypoints.length >= 4) {
        return route;
      }
    } catch (_) {
      // Primary server unavailable, try secondary public server
      try {
        final route = await _queryOsrmRoute(milestones, _fallbackOsrmBase);
        if (route != null && route.waypoints.length >= 4) {
          return route;
        }
      } catch (_) {
        // Fall through to offline city-grid block synthesizer
      }
    }

    // 3. Fallback: Synthesize an orthogonal city block loop following street grid lines
    final gridWaypoints = _generateOrthogonalBlockLoop(
      startLocation: startLocation,
      targetDistanceMeters: targetDistanceMeters,
      bearingOffsetDeg: bearingOffsetDeg,
    );

    return StreetRouteResult(
      waypoints: gridWaypoints,
      distanceMeters: targetDistanceMeters,
      durationSeconds: targetDistanceMeters / 3.0, // ~10 km/h run
      isSnappedToRoads: false,
    );
  }

  /// Queries the OSRM foot/walking engine with a list of coordinates.
  Future<StreetRouteResult?> _queryOsrmRoute(
    List<LatLng> milestones,
    String baseUrl,
  ) async {
    if (milestones.length < 2) return null;

    // OSRM format: lon1,lat1;lon2,lat2;lon3,lat3;...
    final coordsString = milestones
        .map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');

    final uri = Uri.parse(
      '$baseUrl/$coordsString?overview=full&geometries=geojson&steps=false&continue_straight=true',
    );

    final response = await _client.get(uri).timeout(
      const Duration(seconds: 6),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['code'] == 'Ok' && data['routes'] != null) {
        final routes = data['routes'] as List<dynamic>;
        if (routes.isNotEmpty) {
          final firstRoute = routes[0] as Map<String, dynamic>;
          final double distance = (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
          final double duration = (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;
          final geometry = firstRoute['geometry'] as Map<String, dynamic>?;

          if (geometry != null && geometry['coordinates'] != null) {
            final rawCoords = geometry['coordinates'] as List<dynamic>;
            final parsedWaypoints = <LatLng>[];

            for (final item in rawCoords) {
              if (item is List && item.length >= 2) {
                final lon = (item[0] as num).toDouble();
                final lat = (item[1] as num).toDouble();
                parsedWaypoints.add(LatLng(lat, lon));
              }
            }

            if (parsedWaypoints.length >= 2) {
              // Ensure closed loop
              if (parsedWaypoints.first.latitude != parsedWaypoints.last.latitude ||
                  parsedWaypoints.first.longitude != parsedWaypoints.last.longitude) {
                parsedWaypoints.add(parsedWaypoints.first);
              }

              return StreetRouteResult(
                waypoints: parsedWaypoints,
                distanceMeters: distance,
                durationSeconds: duration,
                isSnappedToRoads: true,
              );
            }
          }
        }
      }
    }
    return null;
  }

  /// Calculates 4 cardinal/diagonal neighborhood block milestone waypoints forming
  /// a true 4-corner perimeter circuit around neighborhood blocks.
  List<LatLng> _calculateBlockMilestones({
    required LatLng startLocation,
    required double targetDistanceMeters,
    required double bearingOffsetDeg,
  }) {
    // For a 4-sided block perimeter, side length S = targetDistance / 4.0
    final sideMeters = targetDistanceMeters / 4.0;

    // Convert meters to approximate delta degrees
    final metersPerDegLat = 111320.0;
    final latRad = startLocation.latitude * (math.pi / 180.0);
    final metersPerDegLng = 111320.0 * math.cos(latRad);
    final safeMetersPerDegLng = metersPerDegLng.abs() < 1.0 ? 111320.0 : metersPerDegLng;

    // Rotate the 4-corner rectangular block by bearingOffsetDeg
    final angleRad = bearingOffsetDeg * (math.pi / 180.0);
    final cosA = math.cos(angleRad);
    final sinA = math.sin(angleRad);

    // 4 corners of a rectangular city block loop in local coordinates (meters):
    // P0: Start (0, 0)
    // P1: Along first street (+S, 0)
    // P2: Corner 2 (+S, +S)
    // P3: Return street (0, +S)
    // P4: Back to Start (0, 0)
    final localCorners = [
      [0.0, 0.0],
      [sideMeters, 0.0],
      [sideMeters, sideMeters],
      [0.0, sideMeters],
      [0.0, 0.0],
    ];

    final milestones = <LatLng>[];
    for (final corner in localCorners) {
      final x = corner[0];
      final y = corner[1];

      // Rotate by bearing angle
      final rotX = x * cosA - y * sinA;
      final rotY = x * sinA + y * cosA;

      final dLat = rotX / metersPerDegLat;
      final dLng = rotY / safeMetersPerDegLng;

      milestones.add(
        LatLng(
          startLocation.latitude + dLat,
          startLocation.longitude + dLng,
        ),
      );
    }

    return milestones;
  }

  /// Embedded fallback & offline synthesizer: generates a clean 4-sided
  /// city-grid perimeter block loop with smooth corner transitions.
  /// Simulates running around neighborhood street blocks with zero U-turns.
  List<LatLng> _generateOrthogonalBlockLoop({
    required LatLng startLocation,
    required double targetDistanceMeters,
    required double bearingOffsetDeg,
  }) {
    final milestones = _calculateBlockMilestones(
      startLocation: startLocation,
      targetDistanceMeters: targetDistanceMeters,
      bearingOffsetDeg: bearingOffsetDeg,
    );

    final waypoints = <LatLng>[];
    // Interpolate along the 4 edges of the block circuit
    for (int i = 0; i < milestones.length - 1; i++) {
      final pA = milestones[i];
      final pB = milestones[i + 1];
      const steps = 7;
      for (int s = 0; s < steps; s++) {
        final t = s / steps;
        waypoints.add(
          LatLng(
            pA.latitude + (pB.latitude - pA.latitude) * t,
            pA.longitude + (pB.longitude - pA.longitude) * t,
          ),
        );
      }
    }
    waypoints.add(startLocation);
    return waypoints;
  }
}

