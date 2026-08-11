import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:thews/core/utils/gpx_parser.dart';
import 'package:thews/core/services/tile_cache_service.dart';
import 'package:thews/core/services/gps_tracking_service.dart';

void main() {
  group('Enhanced GPX Parser Tests', () {
    test('parseGpxXml parses lon before lat correctly', () {
      const xmlWithLonFirst = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Thews Gym Tracker">
  <trk>
    <name>Test Reverse Attributes</name>
    <trkseg>
      <trkpt lon="-122.4194" lat="37.7749">
        <ele>15.0</ele>
        <time>2026-08-11T12:00:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';

      final points = GpxParser.parseGpxXml(xmlWithLonFirst);
      expect(points.length, 1);
      expect(points.first.latitude, closeTo(37.7749, 0.0001));
      expect(points.first.longitude, closeTo(-122.4194, 0.0001));
      expect(points.first.elevation, 15.0);
    });

    test('parseGpxXml handles single quotes in attributes', () {
      const xmlWithSingleQuotes = '''
<gpx version='1.1'>
  <trk>
    <trkseg>
      <trkpt lat='40.7128' lon='-74.0060'>
        <ele>5.0</ele>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';

      final points = GpxParser.parseGpxXml(xmlWithSingleQuotes);
      expect(points.length, 1);
      expect(points.first.latitude, closeTo(40.7128, 0.0001));
      expect(points.first.longitude, closeTo(-74.0060, 0.0001));
    });

    test('parseGpxXml returns empty list for empty or invalid XML', () {
      expect(GpxParser.parseGpxXml(''), isEmpty);
      expect(GpxParser.parseGpxXml('not xml content'), isEmpty);
    });
  });

  group('TileCacheService Theme Scoping Tests', () {
    test('PersistentDiskTileProvider generates theme-scoped tile keys', () {
      final provider = PersistentDiskTileProvider();
      const coords = TileCoordinates(10, 20, 5);

      final darkOptions = TileLayer(
        urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
      );
      final lightOptions = TileLayer(
        urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
      );

      final darkImageProvider = provider.getImage(coords, darkOptions) as DiskCachedTileImageProvider;
      final lightImageProvider = provider.getImage(coords, lightOptions) as DiskCachedTileImageProvider;

      expect(darkImageProvider.tileKey, startsWith('dark_'));
      expect(lightImageProvider.tileKey, startsWith('light_'));
      expect(darkImageProvider.tileKey, isNot(equals(lightImageProvider.tileKey)));
    });
  });

  group('Stride Length and Telemetry Tests', () {
    test('dynamic stride length expands with speed in jog mode', () {
      const stateSlow = RunTrackingState(
        activityType: 'jog',
        distanceMeters: 1000,
        currentSpeedKmH: 4.0,
      );
      const stateFast = RunTrackingState(
        activityType: 'jog',
        distanceMeters: 1000,
        currentSpeedKmH: 15.0,
      );

      expect(stateSlow.totalSteps, greaterThan(stateFast.totalSteps));
    });

    test('manual stride length overrides dynamic speed stride', () {
      const stateManual = RunTrackingState(
        activityType: 'jog',
        distanceMeters: 1000,
        currentSpeedKmH: 15.0,
        manualStrideLengthMeters: 1.0,
      );

      expect(stateManual.totalSteps, 1000);
    });

    test('cycle mode hides steps', () {
      const stateCycle = RunTrackingState(
        activityType: 'cycle',
        distanceMeters: 1000,
        currentSpeedKmH: 25.0,
      );

      expect(stateCycle.totalSteps, 0);
    });
  });
}
