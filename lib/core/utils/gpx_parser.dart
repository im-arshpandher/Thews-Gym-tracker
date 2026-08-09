import 'dart:math' as math;

class GpxPoint {
  final double latitude;
  final double longitude;
  final double elevation;
  final DateTime timestamp;

  const GpxPoint({
    required this.latitude,
    required this.longitude,
    this.elevation = 0.0,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'ele': elevation,
        'time': timestamp.toIso8601String(),
      };

  factory GpxPoint.fromJson(Map<String, dynamic> json) {
    return GpxPoint(
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      elevation: (json['ele'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['time'] as String),
    );
  }
}

class GpxParser {
  /// Encodes list of points to standard GPX 1.1 XML string format.
  static String toGpxXml(List<GpxPoint> points, {String activityName = 'Outdoor Activity'}) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln('<gpx version="1.1" creator="Thews Gym Tracker" xmlns="http://www.topografix.com/GPX/1/1">');
    sb.writeln('  <trk>');
    sb.writeln('    <name>${_escapeXml(activityName)}</name>');
    sb.writeln('    <trkseg>');

    for (final p in points) {
      sb.writeln(
        '      <trkpt lat="${p.latitude}" lon="${p.longitude}">\n'
        '        <ele>${p.elevation.toStringAsFixed(1)}</ele>\n'
        '        <time>${p.timestamp.toUtc().toIso8601String()}</time>\n'
        '      </trkpt>',
      );
    }

    sb.writeln('    </trkseg>');
    sb.writeln('  </trk>');
    sb.writeln('</gpx>');
    return sb.toString();
  }

  /// Parses GPX 1.1 XML string back into a list of GpxPoint objects.
  static List<GpxPoint> parseGpxXml(String xmlString) {
    final List<GpxPoint> points = [];
    final trkptBlockRegex = RegExp(
      r'<trkpt\s+lat="([^"]+)"\s+lon="([^"]+)"[^>]*>(.*?)</trkpt>',
      dotAll: true,
    );
    final eleRegex = RegExp(r'<ele>([^<]+)</ele>');
    final timeRegex = RegExp(r'<time>([^<]+)</time>');

    final matches = trkptBlockRegex.allMatches(xmlString);
    for (final m in matches) {
      final lat = double.tryParse(m.group(1) ?? '0') ?? 0.0;
      final lng = double.tryParse(m.group(2) ?? '0') ?? 0.0;
      final content = m.group(3) ?? '';

      final eleMatch = eleRegex.firstMatch(content);
      final ele =
          eleMatch != null ? (double.tryParse(eleMatch.group(1) ?? '0') ?? 0.0) : 0.0;

      final timeMatch = timeRegex.firstMatch(content);
      final time = timeMatch != null
          ? (DateTime.tryParse(timeMatch.group(1) ?? '') ?? DateTime.now())
          : DateTime.now();

      points.add(GpxPoint(
        latitude: lat,
        longitude: lng,
        elevation: ele,
        timestamp: time,
      ));
    }
    return points;
  }

  /// Calculates total cumulative distance in meters along the path using Haversine formula.
  static double calculateTotalDistanceMeters(List<GpxPoint> points) {
    if (points.length < 2) return 0.0;
    double totalMeters = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalMeters += _haversineDistance(points[i], points[i + 1]);
    }
    return totalMeters;
  }

  /// Calculates elevation gain in meters across ascending segments.
  static double calculateElevationGainMeters(List<GpxPoint> points) {
    if (points.length < 2) return 0.0;
    double gain = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      final diff = points[i + 1].elevation - points[i].elevation;
      if (diff > 0) gain += diff;
    }
    return gain;
  }

  static double _haversineDistance(GpxPoint p1, GpxPoint p2) {
    const r = 6371000; // Radius of earth in meters
    final lat1 = p1.latitude * math.pi / 180;
    final lat2 = p2.latitude * math.pi / 180;
    final dLat = (p2.latitude - p1.latitude) * math.pi / 180;
    final dLng = (p2.longitude - p1.longitude) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
