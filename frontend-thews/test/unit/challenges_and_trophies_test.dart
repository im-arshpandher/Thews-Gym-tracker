import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thews/core/services/street_routing_service.dart';
import 'package:thews/features/challenges/domain/challenge_models.dart';
import 'package:thews/features/challenges/domain/loop_route_generator.dart';
import 'package:thews/features/challenges/presentation/challenges_provider.dart';

void main() {
  group('LoopRouteGenerator & StreetRoutingService Tests', () {
    const start = LatLng(37.7749, -122.4194); // San Francisco

    test('generateLoopRoute produces a closed loop starting and ending at origin', () {
      final loop = LoopRouteGenerator.generateLoopRoute(
        startLocation: start,
        targetDistanceMeters: 3000.0,
      );

      expect(loop.length, greaterThanOrEqualTo(6));
      expect(loop.first.latitude, closeTo(start.latitude, 0.0001));
      expect(loop.first.longitude, closeTo(start.longitude, 0.0001));
      expect(loop.last.latitude, closeTo(start.latitude, 0.0001));
      expect(loop.last.longitude, closeTo(start.longitude, 0.0001));
    });

    test('calculateTotalRouteDistance returns distance close to target for 1km, 3km, 7km', () {
      final loop1k = LoopRouteGenerator.generateLoopRoute(
        startLocation: start,
        targetDistanceMeters: 1000.0,
      );
      final dist1k = LoopRouteGenerator.calculateTotalRouteDistance(loop1k);
      expect(dist1k, greaterThan(800.0));
      expect(dist1k, lessThan(1300.0));

      final loop3k = LoopRouteGenerator.generateLoopRoute(
        startLocation: start,
        targetDistanceMeters: 3000.0,
      );
      final dist3k = LoopRouteGenerator.calculateTotalRouteDistance(loop3k);
      expect(dist3k, greaterThan(2500.0));
      expect(dist3k, lessThan(3500.0));

      final loop7k = LoopRouteGenerator.generateLoopRoute(
        startLocation: start,
        targetDistanceMeters: 7000.0,
      );
      final dist7k = LoopRouteGenerator.calculateTotalRouteDistance(loop7k);
      expect(dist7k, greaterThan(6000.0));
      expect(dist7k, lessThan(8000.0));
    });

    test('StreetRoutingService parses OSRM GeoJSON response and snaps to real street coordinates', () async {
      final mockClient = MockClient((request) async {
        final mockGeoJson = {
          'code': 'Ok',
          'routes': [
            {
              'distance': 1050.5,
              'duration': 380.0,
              'geometry': {
                'coordinates': [
                  [-122.4194, 37.7749],
                  [-122.4190, 37.7780],
                  [-122.4140, 37.7780],
                  [-122.4140, 37.7749],
                  [-122.4194, 37.7749],
                ]
              }
            }
          ]
        };
        return http.Response(jsonEncode(mockGeoJson), 200);
      });

      final routingService = StreetRoutingService(client: mockClient);
      final result = await routingService.generateStreetSnappedLoop(
        startLocation: start,
        targetDistanceMeters: 1000.0,
      );

      expect(result.isSnappedToRoads, true);
      expect(result.distanceMeters, closeTo(1050.5, 1.0));
      expect(result.waypoints.length, 5);
      expect(result.waypoints.first.latitude, closeTo(37.7749, 0.0001));
      expect(result.waypoints.last.latitude, closeTo(37.7749, 0.0001));
    });

    test('StreetRoutingService falls back cleanly to embedded perimeter block loop when network fails', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final routingService = StreetRoutingService(client: mockClient);
      final result = await routingService.generateStreetSnappedLoop(
        startLocation: start,
        targetDistanceMeters: 3000.0,
      );

      expect(result.isSnappedToRoads, false);
      expect(result.waypoints.length, greaterThanOrEqualTo(10));
      expect(result.waypoints.first.latitude, closeTo(start.latitude, 0.0001));
      expect(result.waypoints.last.latitude, closeTo(start.latitude, 0.0001));
    });
  });

  group('Challenge & Trophy Domain Models Tests', () {
    test('LocalChallenge JSON serialization and deserialization', () {
      final trophy = TrophyBadge(
        id: 'test_trophy',
        title: 'Speed Demon',
        description: 'Run 1km fast',
        tier: TrophyTier.bronze,
        iconName: 'trophy',
        category: 'easy',
        xpReward: 150,
        unlockedAt: DateTime(2026, 1, 1),
      );

      final challenge = LocalChallenge(
        id: 'ch_test_1',
        title: 'Mission 1K',
        description: 'Complete 1K loop',
        difficulty: ChallengeDifficulty.easy,
        targetDistanceMeters: 1000.0,
        localityName: 'Mission District',
        trophyReward: trophy,
        loopWaypoints: [
          const LatLng(37.77, -122.41),
          const LatLng(37.78, -122.42),
          const LatLng(37.77, -122.41),
        ],
        isCompleted: true,
        completedAt: DateTime(2026, 1, 1),
      );

      final json = challenge.toJson();
      final decoded = LocalChallenge.fromJson(json);

      expect(decoded.id, 'ch_test_1');
      expect(decoded.title, 'Mission 1K');
      expect(decoded.difficulty, ChallengeDifficulty.easy);
      expect(decoded.targetDistanceMeters, 1000.0);
      expect(decoded.localityName, 'Mission District');
      expect(decoded.isCompleted, true);
      expect(decoded.trophyReward.tier, TrophyTier.bronze);
      expect(decoded.loopWaypoints.length, 3);
    });

    test('TrophyBadge JSON serialization and deserialization', () {
      final now = DateTime.now();
      final badge = TrophyBadge(
        id: 'gold_trophy',
        title: 'Century King',
        description: 'Complete 100km total',
        tier: TrophyTier.gold,
        iconName: 'trophy',
        category: 'milestone',
        xpReward: 500,
        unlockedAt: now,
      );

      final json = badge.toJson();
      final decoded = TrophyBadge.fromJson(json);

      expect(decoded.id, 'gold_trophy');
      expect(decoded.title, 'Century King');
      expect(decoded.tier, TrophyTier.gold);
      expect(decoded.xpReward, 500);
      expect(decoded.isUnlocked, true);
      expect(decoded.unlockedAt?.year, now.year);
    });

    test('ChallengeDifficulty enum extension helpers', () {
      expect(ChallengeDifficulty.easy.label, 'EASY');
      expect(ChallengeDifficulty.medium.label, 'MEDIUM');
      expect(ChallengeDifficulty.hard.label, 'HARD');
    });

    test('TrophyTier enum extension helpers', () {
      expect(TrophyTier.bronze.label, 'BRONZE');
      expect(TrophyTier.silver.label, 'SILVER');
      expect(TrophyTier.gold.label, 'GOLD');
      expect(TrophyTier.diamond.label, 'DIAMOND');
    });
  });

  group('ChallengesNotifier State & Leveling Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Initializes with default 1k, 3k, 7k challenges and starter XP', () {
      final notifier = ChallengesNotifier(prefs);
      final state = notifier.state;

      expect(state.challenges.length, 3);
      expect(state.challenges[0].difficulty, ChallengeDifficulty.easy);
      expect(state.challenges[0].targetDistanceMeters, 1000.0);
      expect(state.challenges[1].difficulty, ChallengeDifficulty.medium);
      expect(state.challenges[1].targetDistanceMeters, 3000.0);
      expect(state.challenges[2].difficulty, ChallengeDifficulty.hard);
      expect(state.challenges[2].targetDistanceMeters, 7000.0);
      expect(state.trophies.length, greaterThanOrEqualTo(5));
      expect(state.totalXp, 350);
      expect(state.athleteLevel, 1);
      expect(state.athleteRankTitle, 'Rookie Explorer');
    });

    test('Athlete leveling thresholds scale properly on completing Easy 1K', () async {
      final notifier = ChallengesNotifier(prefs);

      await notifier.completeChallenge('challenge_easy_1k');
      final state = notifier.state;

      expect(state.totalXp, 500);
      expect(state.athleteLevel, 2);
      expect(state.athleteRankTitle, 'Pace Setter');

      final easyChallenge = state.challenges.firstWhere((c) => c.id == 'challenge_easy_1k');
      expect(easyChallenge.isCompleted, true);

      final bronzeTrophy = state.trophies.firstWhere((t) => t.id == 'trophy_bronze_1k_loop');
      expect(bronzeTrophy.isUnlocked, true);
    });

    test('evaluateCompletedRun unlocks eligible challenges automatically', () async {
      final notifier = ChallengesNotifier(prefs);

      final unlocked = await notifier.evaluateCompletedRun(
        distanceMeters: 3500.0,
        durationSeconds: 1200,
      );

      expect(unlocked.length, 2); // Unlocks 1k and 3k
      final state = notifier.state;

      final easy = state.challenges.firstWhere((c) => c.difficulty == ChallengeDifficulty.easy);
      final medium = state.challenges.firstWhere((c) => c.difficulty == ChallengeDifficulty.medium);
      final hard = state.challenges.firstWhere((c) => c.difficulty == ChallengeDifficulty.hard);

      expect(easy.isCompleted, true);
      expect(medium.isCompleted, true);
      expect(hard.isCompleted, false);

      expect(state.totalXp, 900);
    });

    test('updateLocation regenerates challenges centered around new GPS location', () async {
      final notifier = ChallengesNotifier(prefs);
      const newLoc = LatLng(40.7128, -74.0060); // New York

      await notifier.updateLocation(newLoc, localityName: 'Manhattan District');

      final state = notifier.state;
      expect(state.localityName, 'Manhattan District');
      expect(state.userLocation.latitude, closeTo(40.7128, 0.001));
      expect(state.challenges.first.loopWaypoints.first.latitude, closeTo(40.7128, 0.001));
    });
  });
}
