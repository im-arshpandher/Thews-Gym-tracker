import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thews/core/services/segment_storage_service.dart';
import 'package:thews/features/running/domain/aerobic_decoupling_engine.dart';
import 'package:thews/features/running/domain/gap_calculator.dart';
import 'package:thews/features/running/domain/live_segment_engine.dart';
import 'package:thews/features/running/domain/live_segment_models.dart';
import 'package:thews/features/running/domain/trimp_workload_calculator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Minetti Grade-Adjusted Pace (GAP) Engine Tests', () {
    test('Flat ground (0% grade) cost equals 3.6 J/kg*m and GAP equals actual pace', () {
      final cost = GapCalculator.calculateEnergyCost(0.0);
      expect(cost, closeTo(3.6, 0.001));

      final actualPace = 300.0; // 5:00 /km
      final gap = GapCalculator.calculateGapPace(
        actualPaceSecondsPerKm: actualPace,
        gradient: 0.0,
      );
      expect(gap, closeTo(300.0, 0.1));
      expect(GapCalculator.formatPace(gap), '05:00 /km');
    });

    test('Uphill (+10% grade) increases energy cost and GAP is significantly faster than actual pace', () {
      final cost = GapCalculator.calculateEnergyCost(0.10);
      expect(cost, greaterThan(GapCalculator.flatEnergyCost));

      final actualPace = 360.0; // 6:00 /km uphill
      final gap = GapCalculator.calculateGapPace(
        actualPaceSecondsPerKm: actualPace,
        gradient: 0.10,
      );
      // Flat equivalent effort should be much faster (e.g. ~4:00-4:30 /km)
      expect(gap, lessThan(actualPace));
      expect(gap, lessThan(300.0));
    });

    test('Downhill (-10% grade) reduces energetic cost and GAP is slower than actual pace', () {
      final cost = GapCalculator.calculateEnergyCost(-0.10);
      expect(cost, lessThan(GapCalculator.flatEnergyCost));

      final actualPace = 240.0; // 4:00 /km running fast downhill
      final gap = GapCalculator.calculateGapPace(
        actualPaceSecondsPerKm: actualPace,
        gradient: -0.10,
      );
      // Flat equivalent effort is slower than gravity-assisted pace
      expect(gap, greaterThan(actualPace));
    });

    test('Gradient calculation divides elevation delta by distance delta', () {
      final gradient = GapCalculator.calculateGradient(
        elevationDeltaMeters: 50.0,
        distanceDeltaMeters: 1000.0,
      );
      expect(gradient, closeTo(0.05, 0.0001)); // +5% grade
    });
  });

  group('Aerobic Decoupling & Cardiac Drift Engine Tests', () {
    test('Steady pace and steady heart rate results in optimal aerobic base (<3.5%)', () {
      // 5km in 1500s at 145 bpm for half 1 and half 2
      final result = AerobicDecouplingEngine.analyze(
        firstHalfDistanceMeters: 5000,
        firstHalfDurationSeconds: 1500,
        firstHalfAvgHr: 145,
        secondHalfDistanceMeters: 5000,
        secondHalfDurationSeconds: 1500,
        secondHalfAvgHr: 146,
      );

      expect(result.decouplingPercentage, closeTo(0.7, 0.5));
      expect(result.isDecoupled, isFalse);
      expect(result.statusHeadline, contains('Optimal Aerobic Base'));
    });

    test('Cardiac drift (HR spikes from 140 to 165 in second half) triggers high decoupling (>5%)', () {
      final result = AerobicDecouplingEngine.analyze(
        firstHalfDistanceMeters: 5000,
        firstHalfDurationSeconds: 1500,
        firstHalfAvgHr: 140,
        secondHalfDistanceMeters: 5000,
        secondHalfDurationSeconds: 1500,
        secondHalfAvgHr: 165,
      );

      expect(result.decouplingPercentage, greaterThan(5.0));
      expect(result.isDecoupled, isTrue);
      expect(result.statusHeadline, contains('High Aerobic Decoupling'));
    });

    test('Zero or invalid biometric data returns graceful insufficient data analysis', () {
      final result = AerobicDecouplingEngine.analyze(
        firstHalfDistanceMeters: 0,
        firstHalfDurationSeconds: 0,
        firstHalfAvgHr: 0,
        secondHalfDistanceMeters: 0,
        secondHalfDurationSeconds: 0,
        secondHalfAvgHr: 0,
      );

      expect(result.isDecoupled, isFalse);
      expect(result.statusHeadline, 'Insufficient Biometric Data');
    });
  });

  group('Bannister TRIMP & ACWR Workload Tests', () {
    test('Calculates positive TRIMP score for a 45 min moderate run', () {
      final trimp = TrimpWorkloadCalculator.calculateTrimp(
        durationSeconds: 2700, // 45 mins
        averageHeartRateBpm: 155,
        restingHeartRateBpm: 55,
        maxHeartRateBpm: 195,
      );

      expect(trimp, greaterThan(30.0));
      expect(trimp, lessThan(200.0));
    });

    test('Zero duration or sub-resting HR returns 0 TRIMP', () {
      final trimp = TrimpWorkloadCalculator.calculateTrimp(
        durationSeconds: 0,
        averageHeartRateBpm: 150,
      );
      expect(trimp, 0.0);
    });

    test('ACWR evaluation correctly detects optimal sweet spot vs danger zone', () {
      // 28 days of baseline ~50 TRIMP daily
      final past28Days = List.filled(28, 50.0);

      // Current session maintains baseline (ACWR ~ 1.0)
      final optimal = TrimpWorkloadCalculator.evaluateAcwr(
        currentSessionTrimp: 50.0,
        past28DaysDailyTrimps: past28Days,
      );
      expect(optimal.acwr, closeTo(1.0, 0.1));
      expect(optimal.riskZone, 'Optimal Sweet Spot');

      // Sudden acute spike: acute avg = 100 vs chronic avg = 50 -> ACWR = 2.0 (Danger Zone)
      final spikedPast28 = [
        120.0, 100.0, 110.0, 95.0, 105.0, 100.0, 110.0, // Last 7 days
        ...List.filled(21, 20.0), // Previous 21 days
      ];
      final danger = TrimpWorkloadCalculator.evaluateAcwr(
        currentSessionTrimp: 120.0,
        past28DaysDailyTrimps: spikedPast28,
      );
      expect(danger.acwr, greaterThan(1.5));
      expect(danger.riskZone, 'Overtraining Danger Zone');
    });
  });

  group('Live Segments & Storage Tests', () {
    test('RunSegment JSON roundtrip serialization', () {
      final segment = RunSegment(
        id: 'seg_test_1',
        name: 'Ocean Beach Sprint',
        startPoint: const SegmentCoordinate(latitude: 37.7749, longitude: -122.4194),
        endPoint: const SegmentCoordinate(latitude: 37.7780, longitude: -122.4150),
        distanceMeters: 500.0,
        bestTimeSeconds: 95,
        elevationGainMeters: 5.0,
        polyline: const [
          SegmentCoordinate(latitude: 37.7749, longitude: -122.4194),
          SegmentCoordinate(latitude: 37.7780, longitude: -122.4150),
        ],
        createdAt: DateTime(2026, 8, 1),
        attemptCount: 2,
      );

      final json = segment.toJson();
      final restored = RunSegment.fromJson(json);

      expect(restored.id, 'seg_test_1');
      expect(restored.name, 'Ocean Beach Sprint');
      expect(restored.distanceMeters, 500.0);
      expect(restored.bestTimeSeconds, 95);
      expect(restored.formattedDistance, '500 m');
      expect(restored.formattedBestTime, '01:35');
    });

    test('LiveSegmentEngine detects entering start line and tracks real-time ghost delta', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = SegmentStorageService(prefs);

      final segment = RunSegment(
        id: 'test_seg_1',
        name: 'Sprint Test',
        startPoint: const SegmentCoordinate(latitude: 37.774900, longitude: -122.419400),
        endPoint: const SegmentCoordinate(latitude: 37.778000, longitude: -122.419400),
        distanceMeters: 350.0,
        bestTimeSeconds: 60, // 60s PR
        polyline: const [
          SegmentCoordinate(latitude: 37.774900, longitude: -122.419400),
          SegmentCoordinate(latitude: 37.778000, longitude: -122.419400),
        ],
        createdAt: DateTime.now(),
      );

      await storage.saveSegment(segment);
      final engine = LiveSegmentEngine(storage);

      final t0 = DateTime(2026, 8, 1, 10, 0, 0);

      // 1. Move to start line (distance ~0m)
      engine.onLocationUpdate(
        latitude: 37.774905,
        longitude: -122.419405,
        timestamp: t0,
      );

      expect(engine.state.isTrackingSegment, isTrue);
      expect(engine.state.activeEffort, isNotNull);
      expect(engine.state.activeEffort!.segment.name, 'Sprint Test');

      // 2. Move midway along segment fast (15s elapsed, target 30s) -> Ahead of PR
      final t1 = t0.add(const Duration(seconds: 15));
      engine.onLocationUpdate(
        latitude: 37.776450,
        longitude: -122.419400,
        timestamp: t1,
      );

      expect(engine.state.activeEffort!.isAhead, isTrue);
      expect(engine.state.activeEffort!.formattedDelta, contains('-'));
    });
  });
}
