import 'package:flutter_test/flutter_test.dart';
import 'package:thews/core/models/smartwatch_models.dart';
import 'package:thews/core/services/smartwatch_sync_service.dart';
import 'package:thews/core/services/health_platform_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Smartwatch & Biometrics Models Tests', () {
    test('HeartRateZone calculateZones returns 5 progressive zones for 20yo', () {
      final zones = HeartRateZone.calculateZones(age: 20); // max HR = 200
      expect(zones.length, equals(5));

      expect(zones[0].type, equals(HeartRateZoneType.warmup));
      expect(zones[0].minBpm, equals(100)); // 50%
      expect(zones[0].maxBpm, equals(120)); // 60%

      expect(zones[1].type, equals(HeartRateZoneType.fatBurn));
      expect(zones[1].minBpm, equals(121));
      expect(zones[1].maxBpm, equals(140)); // 70%

      expect(zones[4].type, equals(HeartRateZoneType.peak));
      expect(zones[4].minBpm, equals(181));
      expect(zones[4].maxBpm, equals(200)); // 100%
    });

    test('HeartRateZone getZoneForBpm correctly categorizes BPM levels', () {
      final zoneLow = HeartRateZone.getZoneForBpm(105, age: 25);
      expect(zoneLow.type, equals(HeartRateZoneType.warmup));

      final zoneMid = HeartRateZone.getZoneForBpm(140, age: 25);
      expect(zoneMid.type, equals(HeartRateZoneType.cardio));

      final zonePeak = HeartRateZone.getZoneForBpm(185, age: 25);
      expect(zonePeak.type, equals(HeartRateZoneType.peak));
    });

    test('SmartwatchWorkoutPayload serialization to map', () {
      const payload = SmartwatchWorkoutPayload(
        workoutTitle: 'Leg Day',
        currentExerciseName: 'Barbell Squat',
        currentSetIndex: 2,
        totalSets: 4,
        targetWeightKg: 100.0,
        targetReps: 8,
        restTimerSecondsRemaining: 60,
        isRestTimerActive: true,
      );

      final map = payload.toMap();
      expect(map['workoutTitle'], equals('Leg Day'));
      expect(map['currentExerciseName'], equals('Barbell Squat'));
      expect(map['targetWeightKg'], equals(100.0));
      expect(map['targetReps'], equals(8));
      expect(map['restTimerSecondsRemaining'], equals(60));
      expect(map['isRestTimerActive'], isTrue);
    });
  });

  group('SmartwatchSyncService Unit Tests', () {
    test('Connect and disconnect flow updates state cleanly', () async {
      final service = SmartwatchSyncService();

      expect(service.state.status, equals(SmartwatchConnectionStatus.disconnected));

      await service.connectSmartwatch(simulated: true);
      expect(service.state.status, equals(SmartwatchConnectionStatus.connected));
      expect(service.state.device?.isConnected, isTrue);

      service.disconnectSmartwatch();
      expect(service.state.status, equals(SmartwatchConnectionStatus.disconnected));
      expect(service.state.device?.isConnected, isFalse);

      service.dispose();
    });

    test('Trigger simulated wrist set complete streams action', () async {
      final service = SmartwatchSyncService();
      WristSetAction? receivedAction;

      final sub = service.wristActionStream.listen((action) {
        receivedAction = action;
      });

      service.triggerSimulatedWristSetComplete(
        exerciseName: 'Bench Press',
        setIndex: 1,
        weightKg: 80.0,
        reps: 10,
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(receivedAction, isNotNull);
      expect(receivedAction!.actionType, equals(WristActionType.completeSet));
      expect(receivedAction!.exerciseName, equals('Bench Press'));
      expect(receivedAction!.weightKg, equals(80.0));
      expect(receivedAction!.reps, equals(10));

      await sub.cancel();
      service.dispose();
    });
  });

  group('HealthPlatformService Unit Tests', () {
    test('Export workout session creates audit sync log', () async {
      SharedPreferences.setMockInitialValues({});
      final healthService = HealthPlatformService();

      final now = DateTime.now();
      final success = await healthService.exportWorkoutSessionToHealth(
        title: 'Morning Upper Body',
        startTime: now.subtract(const Duration(minutes: 45)),
        endTime: now,
        activeCalories: 340.0,
        averageHeartRate: 135,
        totalVolumeKg: 4200.0,
      );

      expect(success, isTrue);
      expect(healthService.state.syncLogs.isNotEmpty, isTrue);
      expect(healthService.state.syncLogs.first.success, isTrue);
      expect(healthService.state.syncLogs.first.message, contains('Morning Upper Body'));

      healthService.dispose();
    });

    test('Toggle auto sync persists preference', () async {
      SharedPreferences.setMockInitialValues({});
      final healthService = HealthPlatformService();

      await healthService.setAutoSyncEnabled(false);
      expect(healthService.state.isAutoSyncEnabled, isFalse);

      await healthService.setAutoSyncEnabled(true);
      expect(healthService.state.isAutoSyncEnabled, isTrue);

      healthService.dispose();
    });
  });
}
