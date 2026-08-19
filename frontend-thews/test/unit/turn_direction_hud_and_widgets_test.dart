import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thews/core/services/turn_navigation_service.dart';
import 'package:thews/features/running/domain/gpx_course_navigator.dart';
import 'package:thews/features/running/presentation/widgets/course_director_sheet.dart';
import 'package:thews/features/running/presentation/widgets/turn_direction_hud.dart';
import 'package:thews/features/settings/presentation/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TurnDirectionHud & CourseDirectorSheet Widget Tests', () {
    testWidgets('TurnDirectionHud renders nothing when navigation is inactive', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TurnDirectionHud(),
            ),
          ),
        ),
      );

      expect(find.byType(TurnDirectionHud), findsOneWidget);
      expect(find.text('OFF COURSE'), findsNothing);
      expect(find.byIcon(Icons.turn_right_rounded), findsNothing);
    });

    testWidgets('TurnDirectionHud renders turn direction icon, distance, instruction, and progress bar when navigating', (tester) async {
      final points = [
        const LatLng(37.7700, -122.4100),
        const LatLng(37.7750, -122.4100),
        const LatLng(37.7750, -122.4050),
      ];
      final course = CourseRoute(
        id: 'widget_hud_course',
        name: 'HUD Test Loop',
        description: 'Test loop description',
        waypoints: points,
        turnCues: [
          const TurnCue(
            id: 'cue_1',
            type: TurnCueType.turnRight,
            location: LatLng(37.7750, -122.4100),
            instruction: 'Turn right onto Mission St',
            streetName: 'Mission St',
            cumulativeDistanceMeters: 550.0,
            waypointIndex: 1,
          ),
        ],
        totalDistanceMeters: 1000.0,
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer();
      container.read(turnNavigationProvider.notifier).startCourse(course);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: TurnDirectionHud(),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.turn_right_rounded), findsOneWidget);
      expect(find.text('Turn right onto Mission St'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap mute button
      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump();
      expect(container.read(turnNavigationProvider).isVoiceMuted, isTrue);

      // Tap close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(container.read(turnNavigationProvider).isNavigating, isFalse);
    });

    testWidgets('TurnDirectionHud renders off-course warning banner when user veers > 25m', (tester) async {
      final points = [
        const LatLng(37.7700, -122.4100),
        const LatLng(37.7750, -122.4100),
      ];
      final course = CourseRoute(
        id: 'off_course_test',
        name: 'Off Course Test',
        description: 'Test',
        waypoints: points,
        turnCues: const [],
        totalDistanceMeters: 550.0,
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer();
      final navNotifier = container.read(turnNavigationProvider.notifier);
      navNotifier.startCourse(course);

      // User moves 50m off course
      navNotifier.updateLocation(const LatLng(37.7720, -122.4094));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: TurnDirectionHud(),
            ),
          ),
        ),
      );

      expect(find.textContaining('OFF COURSE'), findsOneWidget);
      expect(find.text('Follow line on map'), findsOneWidget);
    });

    testWidgets('CourseDirectorSheet renders curated presets and triggers navigation on start', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CourseDirectorSheet(),
            ),
          ),
        ),
      );

      expect(find.text('Course Director & GPX'), findsOneWidget);
      expect(find.textContaining('Curated Loops'), findsOneWidget);
      expect(find.textContaining('My GPX / Imported'), findsOneWidget);
      expect(find.text('5K Waterfront Circuit'), findsOneWidget);
      expect(find.text('10K City Perimeter Loop'), findsOneWidget);

      // Tap 'Start Course' on the first preset course
      final startButton = find.text('Start Course').first;
      await tester.tap(startButton);
      await tester.pump();

      expect(container.read(turnNavigationProvider).isNavigating, isTrue);
      expect(container.read(turnNavigationProvider).activeCourse?.name, contains('5K Waterfront'));
    });
  });
}
