import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thews/core/database/app_database.dart';
import 'package:thews/core/services/gps_tracking_service.dart';
import 'package:thews/core/utils/gpx_parser.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('GpxParser Unit Tests', () {
    test('toGpxXml and parseGpxXml encode and decode route points correctly', () {
      final now = DateTime.now();
      final originalPoints = [
        GpxPoint(latitude: 37.7749, longitude: -122.4194, elevation: 10.0, timestamp: now),
        GpxPoint(latitude: 37.7750, longitude: -122.4195, elevation: 12.5, timestamp: now.add(const Duration(seconds: 10))),
      ];

      final gpxXml = GpxParser.toGpxXml(originalPoints, activityName: 'Test Outdoor Run');
      expect(gpxXml, contains('<gpx version="1.1"'));
      expect(gpxXml, contains('Test Outdoor Run'));

      final parsedPoints = GpxParser.parseGpxXml(gpxXml);
      expect(parsedPoints.length, 2);
      expect(parsedPoints.first.latitude, closeTo(37.7749, 0.0001));
      expect(parsedPoints.first.longitude, closeTo(-122.4194, 0.0001));
    });

    test('calculateTotalDistanceMeters calculates Haversine distance', () {
      final p1 = GpxPoint(latitude: 37.7749, longitude: -122.4194, timestamp: DateTime.now());
      final p2 = GpxPoint(latitude: 37.7759, longitude: -122.4194, timestamp: DateTime.now());

      final distance = GpxParser.calculateTotalDistanceMeters([p1, p2]);
      expect(distance, greaterThan(100.0)); // Approx ~111m
      expect(distance, lessThan(120.0));
    });
  });

  group('RunTrackingState Formatting Tests', () {
    test('RunSplit formattedPace formats minutes and seconds per km', () {
      const split = RunSplit(
        splitIndex: 1,
        distanceMeters: 1000.0,
        durationSeconds: 300,
        paceSecondsPerKm: 300.0,
      );
      expect(split.formattedPace, '05:00 /km');
    });

    test('RunTrackingState formattedDuration formats HH:MM:SS correctly', () {
      const state = RunTrackingState(durationSeconds: 3665);
      expect(state.formattedDuration, '1:01:05');
    });
  });

  group('Database RunActivities Operations Tests', () {
    test('insertRunActivity and watchRunActivityById flow', () async {
      final now = DateTime.now();
      final id = await database.insertRunActivity(
        RunActivitiesCompanion.insert(
          activityType: const Value('run'),
          startTime: Value(now),
          distanceMeters: const Value(5000.0),
          durationSeconds: const Value(1500),
          avgPaceSecondsPerKm: const Value(300.0),
          elevationGainMeters: const Value(45.0),
          gpxData: const Value('<gpx></gpx>'),
        ),
      );

      final activity = await database.watchRunActivityById(id).first;
      expect(activity, isNotNull);
      expect(activity!.distanceMeters, 5000.0);
      expect(activity.durationSeconds, 1500);
      expect(activity.avgPaceSecondsPerKm, 300.0);
      expect(activity.activityType, 'run');

      // Test delete
      await database.deleteRunActivity(id);
      final deleted = await database.watchRunActivityById(id).first;
      expect(deleted, isNull);
    });
  });
}
