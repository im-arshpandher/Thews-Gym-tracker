import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// GPS Coordinate on a segment with elevation.
@immutable
class SegmentCoordinate {
  final double latitude;
  final double longitude;
  final double elevation;

  const SegmentCoordinate({
    required this.latitude,
    required this.longitude,
    this.elevation = 0.0,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'ele': elevation,
      };

  factory SegmentCoordinate.fromJson(Map<String, dynamic> json) {
    return SegmentCoordinate(
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      elevation: (json['ele'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// A defined outdoor running/cycling route segment.
@immutable
class RunSegment {
  final String id;
  final String name;
  final SegmentCoordinate startPoint;
  final SegmentCoordinate endPoint;
  final double distanceMeters;
  final int? bestTimeSeconds; // User's personal record time
  final double elevationGainMeters;
  final List<SegmentCoordinate> polyline;
  final DateTime createdAt;
  final int attemptCount;

  const RunSegment({
    required this.id,
    required this.name,
    required this.startPoint,
    required this.endPoint,
    required this.distanceMeters,
    this.bestTimeSeconds,
    this.elevationGainMeters = 0.0,
    required this.polyline,
    required this.createdAt,
    this.attemptCount = 0,
  });

  String get formattedDistance {
    if (distanceMeters >= 1000.0) {
      return '${(distanceMeters / 1000.0).toStringAsFixed(2)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }

  String get formattedBestTime {
    if (bestTimeSeconds == null || bestTimeSeconds! <= 0) return '--:--';
    final mins = (bestTimeSeconds! ~/ 60).toString().padLeft(2, '0');
    final secs = (bestTimeSeconds! % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  RunSegment copyWith({
    String? name,
    int? bestTimeSeconds,
    int? attemptCount,
  }) {
    return RunSegment(
      id: id,
      name: name ?? this.name,
      startPoint: startPoint,
      endPoint: endPoint,
      distanceMeters: distanceMeters,
      bestTimeSeconds: bestTimeSeconds ?? this.bestTimeSeconds,
      elevationGainMeters: elevationGainMeters,
      polyline: polyline,
      createdAt: createdAt,
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startPoint': startPoint.toJson(),
        'endPoint': endPoint.toJson(),
        'distanceMeters': distanceMeters,
        'bestTimeSeconds': bestTimeSeconds,
        'elevationGainMeters': elevationGainMeters,
        'polyline': polyline.map((p) => p.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'attemptCount': attemptCount,
      };

  factory RunSegment.fromJson(Map<String, dynamic> json) {
    return RunSegment(
      id: json['id'] as String,
      name: json['name'] as String,
      startPoint: SegmentCoordinate.fromJson(
        json['startPoint'] as Map<String, dynamic>,
      ),
      endPoint: SegmentCoordinate.fromJson(
        json['endPoint'] as Map<String, dynamic>,
      ),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      bestTimeSeconds: json['bestTimeSeconds'] as int?,
      elevationGainMeters:
          (json['elevationGainMeters'] as num?)?.toDouble() ?? 0.0,
      polyline: (json['polyline'] as List<dynamic>)
          .map((p) => SegmentCoordinate.fromJson(p as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      attemptCount: (json['attemptCount'] as int?) ?? 0,
    );
  }
}

/// Live telemetry when an athlete is actively traversing a segment.
@immutable
class LiveSegmentEffort {
  final RunSegment segment;
  final int elapsedSeconds;
  final int targetSeconds;
  final double distanceTraversedMeters;
  final double progressFraction; // 0.0 to 1.0
  final double timeDeltaSeconds; // Negative = Ahead of PR (faster), Positive = Behind
  final bool isAhead;
  final bool isCompleted;
  final bool isNewPr;

  const LiveSegmentEffort({
    required this.segment,
    required this.elapsedSeconds,
    required this.targetSeconds,
    required this.distanceTraversedMeters,
    required this.progressFraction,
    required this.timeDeltaSeconds,
    required this.isAhead,
    this.isCompleted = false,
    this.isNewPr = false,
  });

  String get formattedDelta {
    final absSecs = timeDeltaSeconds.abs();
    final sign = isAhead ? '-' : '+';
    return '$sign${absSecs.toStringAsFixed(1)}s';
  }

  String get formattedElapsed {
    final mins = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}
