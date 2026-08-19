import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thews/core/services/course_storage_service.dart';
import 'package:thews/core/services/turn_navigation_service.dart';
import 'package:thews/core/utils/gpx_parser.dart';
import 'package:thews/features/running/domain/gpx_course_navigator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GpxCourseNavigator Domain Unit Tests', () {
    test('calculateBearing returns 0 for North, 90 for East, 180 for South, 270 for West', () {
      final pOrigin = const LatLng(0.0, 0.0);
      final pNorth = const LatLng(1.0, 0.0);
      final pEast = const LatLng(0.0, 1.0);
      final pSouth = const LatLng(-1.0, 0.0);
      final pWest = const LatLng(0.0, -1.0);

      expect(GpxCourseNavigator.calculateBearing(pOrigin, pNorth), closeTo(0.0, 0.5));
      expect(GpxCourseNavigator.calculateBearing(pOrigin, pEast), closeTo(90.0, 0.5));
      expect(GpxCourseNavigator.calculateBearing(pOrigin, pSouth), closeTo(180.0, 0.5));
      expect(GpxCourseNavigator.calculateBearing(pOrigin, pWest), closeTo(270.0, 0.5));
    });

    test('generateTurnCues accurately detects 90-degree Right and Left turns', () {
      // Create an L-shaped path going North then turning East (90 deg Right)
      final lPathRight = [
        const LatLng(37.7749, -122.4194),
        const LatLng(37.7770, -122.4194), // North
        const LatLng(37.7770, -122.4150), // East (Turn Right)
        const LatLng(37.7770, -122.4100),
      ];

      final cuesRight = GpxCourseNavigator.generateTurnCues(lPathRight, courseName: 'Test L Loop');
      expect(cuesRight.first.type, equals(TurnCueType.start));
      expect(cuesRight.last.type, equals(TurnCueType.finish));

      final turnRightCue = cuesRight.firstWhere((c) => c.type == TurnCueType.turnRight);
      expect(turnRightCue.instruction, contains('Turn right'));
      expect(turnRightCue.waypointIndex, equals(1));

      // Create an L-shaped path going North then turning West (90 deg Left)
      final lPathLeft = [
        const LatLng(37.7749, -122.4194),
        const LatLng(37.7770, -122.4194), // North
        const LatLng(37.7770, -122.4230), // West (Turn Left)
        const LatLng(37.7770, -122.4270),
      ];

      final cuesLeft = GpxCourseNavigator.generateTurnCues(lPathLeft);
      final turnLeftCue = cuesLeft.firstWhere((c) => c.type == TurnCueType.turnLeft);
      expect(turnLeftCue.instruction, contains('Turn left'));
    });

    test('calculateCrossTrackDistance accurately measures perpendicular deviation from polyline', () {
      // Polyline along the Equator from longitude 0.0 to 0.01 (~1113 meters)
      final polyline = [
        const LatLng(0.0, 0.0),
        const LatLng(0.0, 0.01),
      ];

      // Point directly on the segment
      final onTrackPoint = const LatLng(0.0, 0.005);
      final onTrackResult = GpxCourseNavigator.calculateCrossTrackDistance(onTrackPoint, polyline);
      expect(onTrackResult.distanceMeters, closeTo(0.0, 1.0));

      // Point shifted 0.0005 degrees North (~55 meters deviation)
      final offTrackPoint = const LatLng(0.0005, 0.005);
      final offTrackResult = GpxCourseNavigator.calculateCrossTrackDistance(offTrackPoint, polyline);
      expect(offTrackResult.distanceMeters, closeTo(55.6, 2.0));
      expect(offTrackResult.closestSegmentIndex, equals(0));
    });

    test('fromGpxPoints converts track points into valid CourseRoute with turn cues', () {
      final now = DateTime.now();
      final gpxPoints = [
        GpxPoint(latitude: 37.7749, longitude: -122.4194, elevation: 10.0, timestamp: now),
        GpxPoint(latitude: 37.7780, longitude: -122.4194, elevation: 15.0, timestamp: now.add(const Duration(minutes: 2))),
        GpxPoint(latitude: 37.7780, longitude: -122.4140, elevation: 20.0, timestamp: now.add(const Duration(minutes: 4))),
        GpxPoint(latitude: 37.7749, longitude: -122.4194, elevation: 10.0, timestamp: now.add(const Duration(minutes: 8))),
      ];

      final course = GpxCourseNavigator.fromGpxPoints(
        name: 'Marina Closed Circuit',
        points: gpxPoints,
        description: 'Test circuit description',
      );

      expect(course.name, equals('Marina Closed Circuit'));
      expect(course.isClosedLoop, isTrue);
      expect(course.totalDistanceMeters, greaterThan(500.0));
      expect(course.elevationGainMeters, equals(10.0)); // 10->15 (+5), 15->20 (+5), 20->10 (0) = 10
      expect(course.turnCues.isNotEmpty, isTrue);
    });

    test('evaluateNavigationStep triggers advance voice alert, immediate turn cue, and off-course alert', () {
      final polyline = [
        const LatLng(37.7700, -122.4100),
        const LatLng(37.7750, -122.4100), // ~556m North
        const LatLng(37.7750, -122.4050), // Turn Right East
      ];

      final course = CourseRoute(
        id: 'test_course',
        name: 'Evaluation Test Route',
        description: 'Test',
        waypoints: polyline,
        turnCues: GpxCourseNavigator.generateTurnCues(polyline),
        totalDistanceMeters: 1000.0,
        createdAt: DateTime.now(),
      );

      var state = CourseNavigationState(
        activeCourse: course,
        isNavigating: true,
        currentCueIndex: 0,
        nextCue: course.turnCues.first,
        remainingDistanceMeters: 1000.0,
      );

      // 1. User is starting near origin
      state = GpxCourseNavigator.evaluateNavigationStep(
        currentState: state,
        userLocation: const LatLng(37.7701, -122.4100),
      );
      expect(state.isOffCourse, isFalse);

      // 2. User moves 40m before the right turn at waypoint 1 (37.7750, -122.4100)
      // 40m south is ~37.77464
      state = GpxCourseNavigator.evaluateNavigationStep(
        currentState: state,
        userLocation: const LatLng(37.77464, -122.4100),
      );
      expect(state.pendingVoiceAlert, isNotNull);
      expect(state.pendingVoiceAlert!.textToSpeak, contains('turn right'));

      // 3. User veers 60m East off course (37.7720, -122.4093)
      state = GpxCourseNavigator.evaluateNavigationStep(
        currentState: state,
        userLocation: const LatLng(37.7720, -122.4093),
      );
      expect(state.isOffCourse, isTrue);
      expect(state.crossTrackDistanceMeters, greaterThan(25.0));

      // 4. User recovers back to track (within 5m)
      state = GpxCourseNavigator.evaluateNavigationStep(
        currentState: state,
        userLocation: const LatLng(37.7720, -122.4100),
      );
      expect(state.isOffCourse, isFalse);
    });
  });

  group('TurnNavigationNotifier & CourseStorageService Unit Tests', () {
    test('TurnNavigationNotifier starts, updates location, toggles mute, and stops course', () {
      final notifier = TurnNavigationNotifier();

      final points = [
        const LatLng(37.7700, -122.4100),
        const LatLng(37.7750, -122.4100),
      ];
      final course = CourseRoute(
        id: 'test_notifier_course',
        name: 'Notifier Course',
        description: 'Test',
        waypoints: points,
        turnCues: GpxCourseNavigator.generateTurnCues(points),
        totalDistanceMeters: 550.0,
        createdAt: DateTime.now(),
      );

      notifier.startCourse(course);
      expect(notifier.state.isNavigating, isTrue);
      expect(notifier.state.activeCourse?.id, equals('test_notifier_course'));
      expect(notifier.state.isVoiceMuted, isFalse);

      notifier.toggleVoiceMute();
      expect(notifier.state.isVoiceMuted, isTrue);

      notifier.updateLocation(const LatLng(37.7720, -122.4100));
      expect(notifier.state.crossTrackDistanceMeters, closeTo(0.0, 1.0));

      notifier.stopCourse();
      expect(notifier.state.isNavigating, isFalse);
      expect(notifier.state.activeCourse, isNull);
    });

    test('CourseStorageService loads seed presets, saves courses, and deletes courses', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = CourseStorageService(prefs);

      final initialCourses = storage.loadCourses();
      expect(initialCourses.length, greaterThanOrEqualTo(3));
      expect(initialCourses.any((c) => c.name.contains('5K Waterfront')), isTrue);

      // Save a new custom course
      final customCourse = CourseRoute(
        id: 'my_custom_10k',
        name: 'Custom Sunset 10K',
        description: 'Neighborhood run',
        waypoints: [const LatLng(37.77, -122.41), const LatLng(37.78, -122.42)],
        turnCues: const [],
        totalDistanceMeters: 10000.0,
        createdAt: DateTime.now(),
      );

      await storage.saveCourse(customCourse);
      var updated = storage.loadCourses();
      expect(updated.any((c) => c.id == 'my_custom_10k'), isTrue);

      // Delete the course
      await storage.deleteCourse('my_custom_10k');
      updated = storage.loadCourses();
      expect(updated.any((c) => c.id == 'my_custom_10k'), isFalse);
    });
  });
}
