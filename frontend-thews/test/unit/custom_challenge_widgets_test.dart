import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thews/core/database/app_database.dart';
import 'package:thews/core/database/database_provider.dart';
import 'package:thews/features/challenges/domain/challenge_models.dart';
import 'package:thews/features/challenges/presentation/challenge_detail_screen.dart';
import 'package:thews/features/challenges/presentation/challenges_screen.dart';
import 'package:thews/features/challenges/presentation/create_custom_challenge_screen.dart';
import 'package:thews/features/running/presentation/run_heatmap_screen.dart';
import 'package:thews/features/running/presentation/run_tracker_screen.dart';
import 'package:thews/features/settings/presentation/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late AppDatabase testDb;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    testDb = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await testDb.close();
  });

  const testChallenge = LocalChallenge(
    id: 'test_circuit_1',
    title: 'Mission 3K Sprint Circuit',
    description: 'A fast 3.0 km tempo loop through neighborhood streets.',
    difficulty: ChallengeDifficulty.medium,
    targetDistanceMeters: 3000.0,
    localityName: 'Mission District',
    loopWaypoints: [
      LatLng(37.7749, -122.4194),
      LatLng(37.7800, -122.4194),
      LatLng(37.7800, -122.4100),
      LatLng(37.7749, -122.4194),
    ],
    trophyReward: TrophyBadge(
      id: 'trophy_silver_3k',
      title: 'Silver 3K Master',
      description: 'Completed 3K circuit',
      tier: TrophyTier.silver,
      iconName: 'trophy_silver',
      category: 'medium',
      xpReward: 400,
    ),
  );

  group('ChallengeDetailScreen Widget Tests', () {
    testWidgets('Renders zoomable map and telemetry details cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: ChallengeDetailScreen(
              challengeId: 'test_circuit_1',
              initialChallenge: testChallenge,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mission 3K Sprint Circuit'), findsOneWidget);
      expect(find.text('Mission District'), findsOneWidget);
      expect(find.text('3.0 KM'), findsOneWidget);
      expect(find.text('MEDIUM CIRCUIT'), findsOneWidget);
      expect(find.text('START CHALLENGE & RACE GHOST'), findsOneWidget);
      expect(find.text('+400 XP'), findsOneWidget);

      // Verify floating zoom controls exist
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);

      // Tap Zoom In and Zoom Out
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('CreateCustomChallengeScreen Widget Tests', () {
    testWidgets('Renders map canvas, plots waypoints, updates distance and creates challenge', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: CreateCustomChallengeScreen(
              initialWaypoints: [
                LatLng(37.7749, -122.4194),
                LatLng(37.7800, -122.4194),
                LatLng(37.7800, -122.4100),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('TAP MAP TO PLOT ROUTE'), findsOneWidget);
      expect(find.text('CREATE & SAVE CHALLENGE'), findsOneWidget);

      // Verify Toolbar Controls
      expect(find.byIcon(Icons.undo), findsOneWidget);
      expect(find.byIcon(Icons.all_inclusive), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // Tap Close Loop
      await tester.tap(find.byIcon(Icons.all_inclusive));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Create & Save Challenge
      await tester.tap(find.text('CREATE & SAVE CHALLENGE'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('ChallengesScreen Widget Tests', () {
    testWidgets('Renders locality bar with + NEW ROUTE button and challenge list with VIEW MAP', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: ChallengesScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('LOCALITY CHALLENGES'), findsOneWidget);
      expect(find.text('NEW ROUTE'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.text('VIEW MAP'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('RunTrackerScreen Heatmap Toggle Widget Tests', () {
    testWidgets('Tapping heatmap button toggles heatmap on map directly without navigating away', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: RunTrackerScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Thews AI Run Coach'), findsOneWidget);
      expect(find.text('Run'), findsOneWidget);
      expect(find.text('Switch Route'), findsOneWidget);
      expect(find.text('Share live location'), findsOneWidget);
      expect(find.text('Route alerts'), findsOneWidget);
      expect(find.text('Add a sensor'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Verify floating heatmap control on map
      expect(find.byTooltip('Show Heatmap Overlay'), findsWidgets);

      // Tap the heatmap button on the map to toggle ON
      await tester.tap(find.byTooltip('Show Heatmap Overlay').first);
      await tester.pump(const Duration(milliseconds: 100));

      // Now heatmap overlay is active and Hide tooltip is present
      expect(find.byTooltip('Hide Heatmap Overlay'), findsWidgets);

      // Tap again to toggle OFF
      await tester.tap(find.byTooltip('Hide Heatmap Overlay').first);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byTooltip('Show Heatmap Overlay'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('RunHeatmapScreen Widget Tests', () {
    testWidgets('Renders heatmap screen with filters, telemetry cards, and controls', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const MaterialApp(
            home: RunHeatmapScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('TERRITORY HEATMAP'), findsOneWidget);
      expect(find.text('All Sports'), findsOneWidget);
      expect(find.text('Jog / Runs'), findsOneWidget);
      expect(find.text('Cycling'), findsOneWidget);
      expect(find.text('All Time'), findsOneWidget);
      expect(find.text('This Year'), findsOneWidget);
      expect(find.text('Last 30 Days'), findsOneWidget);
      expect(find.text('TERRITORY DISTANCE'), findsOneWidget);
      expect(find.text('ELEVATION CLIMBED'), findsOneWidget);
      expect(find.text('ACTIVITIES'), findsOneWidget);

      // Verify floating map controls
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);

      // Tap filter chips
      await tester.tap(find.text('Jog / Runs'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Last 30 Days'));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Fit Territory button
      await tester.tap(find.byIcon(Icons.center_focus_strong));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
