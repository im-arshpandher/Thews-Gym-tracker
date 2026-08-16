import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/presentation/settings_provider.dart';
import '../domain/challenge_models.dart';
import '../domain/loop_route_generator.dart';

class ChallengesState {
  final List<LocalChallenge> challenges;
  final List<TrophyBadge> trophies;
  final int totalXp;
  final LatLng userLocation;
  final String localityName;
  final bool isLoading;
  final bool isRoadSnapped;
  final String? todayDateKey;

  const ChallengesState({
    required this.challenges,
    required this.trophies,
    required this.totalXp,
    required this.userLocation,
    required this.localityName,
    this.isLoading = false,
    this.isRoadSnapped = false,
    this.todayDateKey,
  });

  int get unlockedTrophyCount => trophies.where((t) => t.isUnlocked).length;

  int get athleteLevel {
    if (totalXp < 500) return 1;
    if (totalXp < 1200) return 2;
    if (totalXp < 2200) return 3;
    if (totalXp < 3500) return 4;
    if (totalXp < 5000) return 5;
    return 5 + ((totalXp - 5000) ~/ 2000);
  }

  String get athleteRankTitle {
    final lvl = athleteLevel;
    if (lvl <= 1) return 'Rookie Explorer';
    if (lvl == 2) return 'Pace Setter';
    if (lvl == 3) return 'Endurance Knight';
    if (lvl == 4) return 'Vanguard Master';
    return 'Titan of Thews';
  }

  ChallengesState copyWith({
    List<LocalChallenge>? challenges,
    List<TrophyBadge>? trophies,
    int? totalXp,
    LatLng? userLocation,
    String? localityName,
    bool? isLoading,
    bool? isRoadSnapped,
    String? todayDateKey,
  }) {
    return ChallengesState(
      challenges: challenges ?? this.challenges,
      trophies: trophies ?? this.trophies,
      totalXp: totalXp ?? this.totalXp,
      userLocation: userLocation ?? this.userLocation,
      localityName: localityName ?? this.localityName,
      isLoading: isLoading ?? this.isLoading,
      isRoadSnapped: isRoadSnapped ?? this.isRoadSnapped,
      todayDateKey: todayDateKey ?? this.todayDateKey,
    );
  }
}

class ChallengesNotifier extends StateNotifier<ChallengesState> {
  static const String _challengesKey = 'thews_local_challenges_v2';
  static const String _trophiesKey = 'thews_unlocked_trophies_v2';
  static const String _xpKey = 'thews_athlete_xp_v2';
  static const String _latKey = 'thews_last_user_lat_v2';
  static const String _lngKey = 'thews_last_user_lng_v2';
  static const String _localityKey = 'thews_last_user_locality_v2';
  static const String _dailyDateKey = 'thews_last_daily_date_v2';

  final SharedPreferences _prefs;

  ChallengesNotifier(this._prefs)
      : super(
          ChallengesState(
            challenges: const [],
            trophies: const [],
            totalXp: 0,
            userLocation: const LatLng(37.7749, -122.4194),
            localityName: 'Local District',
          ),
        ) {
    _loadState();
  }

  String _getTodayDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int _calculateDaySeed() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  void _loadState() {
    final rawChallenges = _prefs.getString(_challengesKey);
    final rawTrophies = _prefs.getString(_trophiesKey);
    final savedXp = _prefs.getInt(_xpKey) ?? 350;

    final savedLat = _prefs.getDouble(_latKey);
    final savedLng = _prefs.getDouble(_lngKey);
    final savedLocality = _prefs.getString(_localityKey) ?? 'My Neighborhood';
    final savedDate = _prefs.getString(_dailyDateKey);
    final today = _getTodayDateKey();

    final initialLocation = (savedLat != null && savedLng != null)
        ? LatLng(savedLat, savedLng)
        : const LatLng(37.7749, -122.4194);

    List<LocalChallenge> loadedChallenges = [];
    if (rawChallenges != null && rawChallenges.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawChallenges);
        loadedChallenges = list
            .map((e) => LocalChallenge.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        loadedChallenges = [];
      }
    }

    final isNewDay = savedDate != today;

    if (loadedChallenges.isEmpty || isNewDay) {
      loadedChallenges =
          _generateDefaultChallenges(initialLocation, savedLocality, today);
      _prefs.setString(_dailyDateKey, today);
    }

    List<TrophyBadge> loadedTrophies = [];
    if (rawTrophies != null && rawTrophies.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawTrophies);
        loadedTrophies = list
            .map((e) => TrophyBadge.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        loadedTrophies = [];
      }
    }

    final catalog = _getDefaultTrophyCatalog();
    final mergedTrophies = <TrophyBadge>[];

    for (final catTrophy in catalog) {
      final existing = loadedTrophies.cast<TrophyBadge?>().firstWhere(
            (t) => t?.id == catTrophy.id,
            orElse: () => null,
          );
      if (existing != null && existing.isUnlocked) {
        mergedTrophies.add(existing);
      } else {
        mergedTrophies.add(catTrophy);
      }
    }

    state = state.copyWith(
      challenges: loadedChallenges,
      trophies: mergedTrophies,
      totalXp: savedXp,
      userLocation: initialLocation,
      localityName: savedLocality,
      todayDateKey: today,
    );
  }

  /// Syncs with the user's live or last known GPS coordinate and snaps
  /// real-world road loops across OpenStreetMap street network around the user's locality.
  Future<void> syncWithUserLocation() async {
    state = state.copyWith(isLoading: true);
    try {
      Position? position;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        position = await Geolocator.getLastKnownPosition();
        position ??= await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
      }

      if (position != null) {
        final newLoc = LatLng(position.latitude, position.longitude);
        await _saveUserLocation(newLoc, 'Current Locality');
        await updateLocationAndSnapToStreets(newLoc, localityName: 'Local Circuit');
      } else {
        // Use saved location and ensure street snapping
        await updateLocationAndSnapToStreets(state.userLocation, localityName: state.localityName);
      }
    } catch (_) {
      // Fallback cleanly
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateLocation(LatLng location, {String? localityName}) async {
    await updateLocationAndSnapToStreets(location, localityName: localityName);
  }

  /// Calculates real-world street network loop routes around [location] with daily rotating bearings.
  Future<void> updateLocationAndSnapToStreets(
    LatLng location, {
    String? localityName,
  }) async {
    final newLocality = localityName ?? state.localityName;
    final today = _getTodayDateKey();
    final daySeed = _calculateDaySeed();

    // Daily rotating bearings
    final easyBearing = ((daySeed * 47) % 360).toDouble();
    final medBearing = (((daySeed * 47) + 120) % 360).toDouble();
    final hardBearing = (((daySeed * 47) + 240) % 360).toDouble();

    state = state.copyWith(isLoading: true);

    try {
      // 1. Generate real road-snapped loop routes (1km, 3km, 7km)
      final easyResult = await LoopRouteGenerator.generateStreetSnappedLoopRoute(
        startLocation: location,
        targetDistanceMeters: 1000.0,
        bearingOffsetDeg: easyBearing,
      );

      final medResult = await LoopRouteGenerator.generateStreetSnappedLoopRoute(
        startLocation: location,
        targetDistanceMeters: 3000.0,
        bearingOffsetDeg: medBearing,
      );

      final hardResult = await LoopRouteGenerator.generateStreetSnappedLoopRoute(
        startLocation: location,
        targetDistanceMeters: 7000.0,
        bearingOffsetDeg: hardBearing,
      );

      final updatedChallenges = [
        LocalChallenge(
          id: 'challenge_easy_1k',
          title: '$newLocality 1K Street Loop',
          description:
              'A quick 1.0 km warm-up circuit routed around your immediate neighborhood blocks.',
          difficulty: ChallengeDifficulty.easy,
          targetDistanceMeters: easyResult.distanceMeters > 300
              ? easyResult.distanceMeters
              : 1000.0,
          localityName: newLocality,
          loopWaypoints: easyResult.waypoints,
          dateKey: today,
          isDaily: true,
          trophyReward: const TrophyBadge(
            id: 'trophy_bronze_1k_loop',
            title: 'Bronze 1K Pioneer',
            description: 'Conquered the local 1.0 km Easy Street Loop challenge.',
            tier: TrophyTier.bronze,
            iconName: 'trophy_bronze',
            category: 'easy',
            xpReward: 150,
          ),
        ),
        LocalChallenge(
          id: 'challenge_med_3k',
          title: '$newLocality 3K District Circuit',
          description:
              'A 3.0 km tempo loop routed along city blocks and road corridors to build your aerobic base.',
          difficulty: ChallengeDifficulty.medium,
          targetDistanceMeters: medResult.distanceMeters > 500
              ? medResult.distanceMeters
              : 3000.0,
          localityName: newLocality,
          loopWaypoints: medResult.waypoints,
          dateKey: today,
          isDaily: true,
          trophyReward: const TrophyBadge(
            id: 'trophy_silver_3k_loop',
            title: 'Silver 3K Tempo Master',
            description: 'Crushed the local 3.0 km Medium District Loop challenge.',
            tier: TrophyTier.silver,
            iconName: 'trophy_silver',
            category: 'medium',
            xpReward: 400,
          ),
        ),
        LocalChallenge(
          id: 'challenge_hard_7k',
          title: '$newLocality 7K District Gran Fondo',
          description:
              'A 7.0 km round-trip street perimeter circuit traversing through your surrounding urban district.',
          difficulty: ChallengeDifficulty.hard,
          targetDistanceMeters: hardResult.distanceMeters > 1000
              ? hardResult.distanceMeters
              : 7000.0,
          localityName: newLocality,
          loopWaypoints: hardResult.waypoints,
          dateKey: today,
          isDaily: true,
          trophyReward: const TrophyBadge(
            id: 'trophy_gold_7k_loop',
            title: 'Gold 7K Titan',
            description: 'Completed the challenging 7.0 km Hard Street Loop challenge.',
            tier: TrophyTier.gold,
            iconName: 'trophy_gold',
            category: 'hard',
            xpReward: 800,
          ),
        ),
      ];

      // Retain completion status if completed on the same date
      final mergedChallenges = updatedChallenges.map((newCh) {
        final existing = state.challenges.cast<LocalChallenge?>().firstWhere(
              (c) => c?.id == newCh.id,
              orElse: () => null,
            );
        if (existing != null &&
            existing.isCompleted &&
            existing.dateKey == today) {
          return newCh.copyWith(
            isCompleted: true,
            completedAt: existing.completedAt,
          );
        }
        return newCh;
      }).toList();

      state = state.copyWith(
        userLocation: location,
        localityName: newLocality,
        challenges: mergedChallenges,
        isLoading: false,
        isRoadSnapped: easyResult.isSnappedToRoads || medResult.isSnappedToRoads,
        todayDateKey: today,
      );

      await _saveUserLocation(location, newLocality);
      await _prefs.setString(_dailyDateKey, today);
      await _saveChallenges();
    } catch (_) {
      // Fallback
      final fallbackList = _generateDefaultChallenges(location, newLocality, today);
      state = state.copyWith(
        userLocation: location,
        localityName: newLocality,
        challenges: fallbackList,
        isLoading: false,
        todayDateKey: today,
      );
      await _saveChallenges();
    }
  }

  Future<void> completeChallenge(String challengeId) async {
    final index = state.challenges.indexWhere((c) => c.id == challengeId);
    if (index < 0) return;

    final targetChallenge = state.challenges[index];
    if (targetChallenge.isCompleted) return;

    final updatedChallenge = targetChallenge.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );

    final updatedList = List<LocalChallenge>.from(state.challenges);
    updatedList[index] = updatedChallenge;

    final trophyIndex = state.trophies.indexWhere(
      (t) => t.id == targetChallenge.trophyReward.id,
    );

    List<TrophyBadge> updatedTrophies = List.from(state.trophies);
    int newXp = state.totalXp + targetChallenge.trophyReward.xpReward;

    if (trophyIndex >= 0) {
      updatedTrophies[trophyIndex] = state.trophies[trophyIndex].copyWith(
        unlockedAt: DateTime.now(),
      );
    } else {
      updatedTrophies.add(
        targetChallenge.trophyReward.copyWith(unlockedAt: DateTime.now()),
      );
    }

    state = state.copyWith(
      challenges: updatedList,
      trophies: updatedTrophies,
      totalXp: newXp,
    );

    await _saveChallenges();
    await _saveTrophies();
    await _prefs.setInt(_xpKey, newXp);
  }

  Future<List<TrophyBadge>> evaluateCompletedRun({
    required double distanceMeters,
    required int durationSeconds,
  }) async {
    final newlyUnlocked = <TrophyBadge>[];

    for (final challenge in state.challenges) {
      if (!challenge.isCompleted && distanceMeters >= (challenge.targetDistanceMeters * 0.95)) {
        await completeChallenge(challenge.id);
        newlyUnlocked.add(challenge.trophyReward);
      }
    }

    return newlyUnlocked;
  }

  Future<void> _saveUserLocation(LatLng location, String locality) async {
    await _prefs.setDouble(_latKey, location.latitude);
    await _prefs.setDouble(_lngKey, location.longitude);
    await _prefs.setString(_localityKey, locality);
  }

  Future<void> _saveChallenges() async {
    final jsonList = state.challenges.map((c) => c.toJson()).toList();
    await _prefs.setString(_challengesKey, jsonEncode(jsonList));
  }

  Future<void> _saveTrophies() async {
    final jsonList = state.trophies.map((t) => t.toJson()).toList();
    await _prefs.setString(_trophiesKey, jsonEncode(jsonList));
  }

  List<LocalChallenge> _generateDefaultChallenges(
    LatLng startLoc,
    String locality, [
    String? dateKey,
  ]) {
    final today = dateKey ?? _getTodayDateKey();
    final daySeed = _calculateDaySeed();

    final easyBearing = ((daySeed * 47) % 360).toDouble();
    final medBearing = (((daySeed * 47) + 120) % 360).toDouble();
    final hardBearing = (((daySeed * 47) + 240) % 360).toDouble();

    final easyLoop = LoopRouteGenerator.generateLoopRoute(
      startLocation: startLoc,
      targetDistanceMeters: 1000.0,
      bearingOffsetDeg: easyBearing,
    );

    final medLoop = LoopRouteGenerator.generateLoopRoute(
      startLocation: startLoc,
      targetDistanceMeters: 3000.0,
      bearingOffsetDeg: medBearing,
    );

    final hardLoop = LoopRouteGenerator.generateLoopRoute(
      startLocation: startLoc,
      targetDistanceMeters: 7000.0,
      bearingOffsetDeg: hardBearing,
    );

    return [
      LocalChallenge(
        id: 'challenge_easy_1k',
        title: '$locality 1K Morning Loop',
        description:
            'Start from your location and complete a scenic 1.0 km circuit returning to your doorstep.',
        difficulty: ChallengeDifficulty.easy,
        targetDistanceMeters: 1000.0,
        localityName: locality,
        loopWaypoints: easyLoop,
        dateKey: today,
        isDaily: true,
        trophyReward: const TrophyBadge(
          id: 'trophy_bronze_1k_loop',
          title: 'Bronze 1K Pioneer',
          description: 'Conquered the local 1.0 km Easy Loop challenge.',
          tier: TrophyTier.bronze,
          iconName: 'trophy_bronze',
          category: 'easy',
          xpReward: 150,
        ),
      ),
      LocalChallenge(
        id: 'challenge_med_3k',
        title: '$locality 3K Tempo Circuit',
        description:
            'A 3.0 km mid-range tempo loop designed to challenge your aerobic base.',
        difficulty: ChallengeDifficulty.medium,
        targetDistanceMeters: 3000.0,
        localityName: locality,
        loopWaypoints: medLoop,
        dateKey: today,
        isDaily: true,
        trophyReward: const TrophyBadge(
          id: 'trophy_silver_3k_loop',
          title: 'Silver 3K Tempo Master',
          description: 'Crushed the local 3.0 km Medium Loop challenge.',
          tier: TrophyTier.silver,
          iconName: 'trophy_silver',
          category: 'medium',
          xpReward: 400,
        ),
      ),
      LocalChallenge(
        id: 'challenge_hard_7k',
        title: '$locality 7K District Gran Fondo',
        description:
            'A 7.0 km round-trip loop traversing through your surrounding urban district.',
        difficulty: ChallengeDifficulty.hard,
        targetDistanceMeters: 7000.0,
        localityName: locality,
        loopWaypoints: hardLoop,
        dateKey: today,
        isDaily: true,
        trophyReward: const TrophyBadge(
          id: 'trophy_gold_7k_loop',
          title: 'Gold 7K Titan',
          description: 'Completed the challenging 7.0 km Hard Loop challenge.',
          tier: TrophyTier.gold,
          iconName: 'trophy_gold',
          category: 'hard',
          xpReward: 800,
        ),
      ),
    ];
  }

  List<TrophyBadge> _getDefaultTrophyCatalog() {
    return const [
      TrophyBadge(
        id: 'trophy_bronze_1k_loop',
        title: 'Bronze 1K Pioneer',
        description: 'Complete a 1.0 km local neighborhood loop.',
        tier: TrophyTier.bronze,
        iconName: 'trophy_bronze',
        category: 'easy',
        xpReward: 150,
      ),
      TrophyBadge(
        id: 'trophy_silver_3k_loop',
        title: 'Silver 3K Tempo Master',
        description: 'Complete a 3.0 km district tempo circuit.',
        tier: TrophyTier.silver,
        iconName: 'trophy_silver',
        category: 'medium',
        xpReward: 400,
      ),
      TrophyBadge(
        id: 'trophy_gold_7k_loop',
        title: 'Gold 7K Titan',
        description: 'Complete a challenging 7.0 km endurance road loop.',
        tier: TrophyTier.gold,
        iconName: 'trophy_gold',
        category: 'hard',
        xpReward: 800,
      ),
      TrophyBadge(
        id: 'trophy_diamond_streak',
        title: 'Century Master',
        description: 'Log over 100 km of outdoor running in a single month.',
        tier: TrophyTier.diamond,
        iconName: 'trophy_diamond',
        category: 'milestone',
        xpReward: 2500,
      ),
      TrophyBadge(
        id: 'trophy_first_run',
        title: 'Trailblazer Pioneer',
        description: 'Completed your very first outdoor GPS tracked activity.',
        tier: TrophyTier.bronze,
        iconName: 'trophy_pioneer',
        category: 'milestone',
        xpReward: 150,
      ),
    ];
  }
}

final challengesProvider =
    StateNotifierProvider<ChallengesNotifier, ChallengesState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ChallengesNotifier(prefs);
});
