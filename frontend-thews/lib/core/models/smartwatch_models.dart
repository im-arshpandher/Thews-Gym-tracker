import 'package:flutter/material.dart';

enum SmartwatchConnectionStatus {
  disconnected,
  connecting,
  connected,
  syncing,
}

enum SmartwatchPlatform {
  wearOs,
  appleWatch,
  simulated,
}

enum HeartRateZoneType {
  warmup,
  fatBurn,
  cardio,
  anaerobic,
  peak,
}

class HeartRateZone {
  final HeartRateZoneType type;
  final String name;
  final int minBpm;
  final int maxBpm;
  final Color color;
  final String description;

  const HeartRateZone({
    required this.type,
    required this.name,
    required this.minBpm,
    required this.maxBpm,
    required this.color,
    required this.description,
  });

  /// Computes the 5 physiological heart rate zones based on user's age (standard formula: max HR = 220 - age).
  static List<HeartRateZone> calculateZones({int age = 25}) {
    final maxHr = 220 - age;
    return [
      HeartRateZone(
        type: HeartRateZoneType.warmup,
        name: 'Zone 1: Warmup',
        minBpm: (maxHr * 0.50).round(),
        maxBpm: (maxHr * 0.60).round(),
        color: const Color(0xFF64B5F6),
        description: 'Light recovery & activation (50-60%)',
      ),
      HeartRateZone(
        type: HeartRateZoneType.fatBurn,
        name: 'Zone 2: Fat Burn',
        minBpm: (maxHr * 0.60).round() + 1,
        maxBpm: (maxHr * 0.70).round(),
        color: const Color(0xFF81C784),
        description: 'Aerobic base building (60-70%)',
      ),
      HeartRateZone(
        type: HeartRateZoneType.cardio,
        name: 'Zone 3: Cardio',
        minBpm: (maxHr * 0.70).round() + 1,
        maxBpm: (maxHr * 0.80).round(),
        color: const Color(0xFFFFD54F),
        description: 'Aerobic fitness & endurance (70-80%)',
      ),
      HeartRateZone(
        type: HeartRateZoneType.anaerobic,
        name: 'Zone 4: Anaerobic',
        minBpm: (maxHr * 0.80).round() + 1,
        maxBpm: (maxHr * 0.90).round(),
        color: const Color(0xFFFF8A65),
        description: 'Hard effort & lactic threshold (80-90%)',
      ),
      HeartRateZone(
        type: HeartRateZoneType.peak,
        name: 'Zone 5: Peak',
        minBpm: (maxHr * 0.90).round() + 1,
        maxBpm: maxHr,
        color: const Color(0xFFE53935),
        description: 'Maximum intensity redline (90-100%)',
      ),
    ];
  }

  static HeartRateZone getZoneForBpm(int bpm, {int age = 25}) {
    final zones = calculateZones(age: age);
    if (bpm < zones.first.minBpm) return zones.first;
    for (final zone in zones) {
      if (bpm <= zone.maxBpm) return zone;
    }
    return zones.last;
  }
}

class HeartRateSample {
  final int bpm;
  final DateTime timestamp;
  final HeartRateZoneType zone;

  const HeartRateSample({
    required this.bpm,
    required this.timestamp,
    required this.zone,
  });

  Map<String, dynamic> toJson() => {
    'bpm': bpm,
    'timestamp': timestamp.toIso8601String(),
    'zone': zone.name,
  };

  factory HeartRateSample.fromJson(Map<String, dynamic> json) => HeartRateSample(
    bpm: json['bpm'] as int,
    timestamp: DateTime.parse(json['timestamp'] as String),
    zone: HeartRateZoneType.values.firstWhere(
      (z) => z.name == json['zone'],
      orElse: () => HeartRateZoneType.warmup,
    ),
  );
}

class SmartwatchDevice {
  final String id;
  final String name;
  final SmartwatchPlatform platform;
  final int batteryLevelPercent;
  final bool isConnected;
  final DateTime? lastSyncTime;

  const SmartwatchDevice({
    required this.id,
    required this.name,
    required this.platform,
    this.batteryLevelPercent = 85,
    this.isConnected = false,
    this.lastSyncTime,
  });

  SmartwatchDevice copyWith({
    String? id,
    String? name,
    SmartwatchPlatform? platform,
    int? batteryLevelPercent,
    bool? isConnected,
    DateTime? lastSyncTime,
  }) {
    return SmartwatchDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      batteryLevelPercent: batteryLevelPercent ?? this.batteryLevelPercent,
      isConnected: isConnected ?? this.isConnected,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class SmartwatchWorkoutPayload {
  final String workoutTitle;
  final String currentExerciseName;
  final int currentSetIndex;
  final int totalSets;
  final double targetWeightKg;
  final int targetReps;
  final int restTimerSecondsRemaining;
  final bool isRestTimerActive;

  const SmartwatchWorkoutPayload({
    required this.workoutTitle,
    required this.currentExerciseName,
    required this.currentSetIndex,
    required this.totalSets,
    required this.targetWeightKg,
    required this.targetReps,
    this.restTimerSecondsRemaining = 0,
    this.isRestTimerActive = false,
  });

  Map<String, dynamic> toMap() => {
    'workoutTitle': workoutTitle,
    'currentExerciseName': currentExerciseName,
    'currentSetIndex': currentSetIndex,
    'totalSets': totalSets,
    'targetWeightKg': targetWeightKg,
    'targetReps': targetReps,
    'restTimerSecondsRemaining': restTimerSecondsRemaining,
    'isRestTimerActive': isRestTimerActive,
  };
}

enum WristActionType {
  completeSet,
  adjustWeight,
  adjustReps,
  skipRestTimer,
  addRestTime,
}

class WristSetAction {
  final WristActionType actionType;
  final String exerciseName;
  final int setIndex;
  final double? weightKg;
  final int? reps;
  final int? secondsAdded;
  final DateTime timestamp;

  const WristSetAction({
    required this.actionType,
    required this.exerciseName,
    required this.setIndex,
    this.weightKg,
    this.reps,
    this.secondsAdded,
    required this.timestamp,
  });
}

enum HealthPlatformType {
  appleHealth,
  healthConnect,
  simulated,
}

class HealthSyncLog {
  final String id;
  final DateTime timestamp;
  final HealthPlatformType platform;
  final bool success;
  final String message;
  final int syncedRecordsCount;

  const HealthSyncLog({
    required this.id,
    required this.timestamp,
    required this.platform,
    required this.success,
    required this.message,
    required this.syncedRecordsCount,
  });
}
