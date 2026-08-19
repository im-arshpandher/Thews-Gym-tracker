import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thews/features/ai_coach/domain/ai_coach_models.dart';
import 'package:thews/features/hybrid/domain/interference_optimizer.dart';
import 'package:thews/features/hybrid/domain/unified_readiness_engine.dart';
import 'package:thews/features/hybrid/presentation/hybrid_readiness_dashboard_card.dart';
import 'package:thews/features/hybrid/presentation/hybrid_readiness_provider.dart';

void main() {
  group('Phase 5: InterferenceOptimizer Unit Tests', () {
    test('evaluateInterference detects high risk when heavy leg session logged 2h ago', () {
      final now = DateTime(2026, 8, 17, 14, 0);
      final recentLifting = [
        HybridLiftingSession(
          timestamp: DateTime(2026, 8, 17, 12, 0), // 2 hours ago
          totalVolumeKg: 8500.0,
          legSetsCount: 6,
          hasHeavyLowerBodyCompound: true,
        ),
      ];

      final result = InterferenceOptimizer.evaluateInterference(
        recentLiftingSessions: recentLifting,
        recentRunningSessions: [],
        referenceTime: now,
      );

      expect(result.riskLevel, equals(InterferenceRiskLevel.high));
      expect(result.interferencePenaltyScore, equals(25.0));
      expect(result.recommendedRunDelay.inHours, equals(4)); // 6h - 2h = 4h
      expect(result.summary, contains('Heavy lower-body'));
    });

    test('evaluateInterference returns moderate risk when leg session logged 12h ago', () {
      final now = DateTime(2026, 8, 17, 18, 0);
      final recentLifting = [
        HybridLiftingSession(
          timestamp: DateTime(2026, 8, 17, 6, 0), // 12 hours ago
          totalVolumeKg: 7000.0,
          legSetsCount: 5,
          hasHeavyLowerBodyCompound: true,
        ),
      ];

      final result = InterferenceOptimizer.evaluateInterference(
        recentLiftingSessions: recentLifting,
        recentRunningSessions: [],
        referenceTime: now,
      );

      expect(result.riskLevel, equals(InterferenceRiskLevel.moderate));
      expect(result.interferencePenaltyScore, equals(12.0));
      expect(result.summary, contains('active recovery'));
    });

    test('evaluateInterference returns optimal when upper body trained or >36h post legs', () {
      final now = DateTime(2026, 8, 17, 18, 0);
      final recentLifting = [
        HybridLiftingSession(
          timestamp: DateTime(2026, 8, 17, 15, 0), // 3 hours ago, but Upper Body Chest/Arms
          totalVolumeKg: 5000.0,
          legSetsCount: 0,
          hasHeavyLowerBodyCompound: false,
        ),
      ];

      final result = InterferenceOptimizer.evaluateInterference(
        recentLiftingSessions: recentLifting,
        recentRunningSessions: [],
        referenceTime: now,
      );

      expect(result.riskLevel, equals(InterferenceRiskLevel.minimal));
      expect(result.interferencePenaltyScore, equals(0.0));
    });
  });

  group('Phase 5: UnifiedReadinessEngine Unit Tests', () {
    test('calculate returns prime readiness when athlete is fully rested', () {
      final metrics = UnifiedReadinessEngine.calculate(
        recentLiftingEvents: [],
        liftingSessions: [],
        runningSessions: [],
        past28DaysDailyTrimps: List.filled(28, 0.0),
      );

      expect(metrics.overallScore, greaterThanOrEqualTo(85));
      expect(metrics.tier, equals(HybridReadinessTier.prime));
      expect(metrics.suggestedTrainingFocus, contains('Heavy Compound Lifting'));
    });

    test('calculate returns fatigued readiness when acute fatigue & interference is elevated', () {
      final now = DateTime(2026, 8, 17, 15, 0);
      final recentMuscleEvents = [
        MuscleWorkoutEvent(
          muscleGroup: 'Legs',
          timestamp: DateTime(2026, 8, 17, 12, 0), // 3 hours ago
          totalVolume: 12000.0,
          totalSets: 12,
        ),
      ];
      final liftingSessions = [
        HybridLiftingSession(
          timestamp: DateTime(2026, 8, 17, 12, 0),
          totalVolumeKg: 12000.0,
          legSetsCount: 12,
          hasHeavyLowerBodyCompound: true,
        ),
      ];

      final metrics = UnifiedReadinessEngine.calculate(
        recentLiftingEvents: recentMuscleEvents,
        liftingSessions: liftingSessions,
        runningSessions: [],
        past28DaysDailyTrimps: List.filled(28, 20.0),
        referenceTime: now,
      );

      expect(metrics.overallScore, lessThan(85));
      expect(metrics.interferenceResult.riskLevel, equals(InterferenceRiskLevel.high));
      expect(metrics.weeklyLiftingTonnageKg, equals(12000.0));
    });
  });

  group('Phase 5: HybridReadinessDashboardCard Widget Tests', () {
    testWidgets('renders readiness card and opens breakdown modal sheet on tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testMetrics = HybridReadinessMetrics(
        overallScore: 88,
        tier: HybridReadinessTier.prime,
        neuromuscularFatiguePct: 12.0,
        cardiovascularStrainPct: 8.0,
        weeklyLiftingTonnageKg: 14500.0,
        weeklyRunningDistanceKm: 28.5,
        weeklyElevationGainMeters: 140.0,
        weeklyLiftingWorkoutsCount: 4,
        weeklyRunningActivitiesCount: 3,
        interferenceResult: InterferenceAdvisorResult.optimal(),
        primaryRecommendation: 'Prime recovery state for intense lifting or endurance.',
        suggestedTrainingFocus: 'Heavy Lower Body or Tempo Run',
        recoveryInsights: const ['Optimal recovery across all systems'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hybridReadinessProvider.overrideWith((ref) => Stream.value(testMetrics)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: HybridReadinessDashboardCard(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HYBRID ATHLETE ENGINE'), findsOneWidget);
      expect(find.text('PRIME'), findsOneWidget);
      expect(find.text('88'), findsOneWidget);
      expect(find.text('14.5k kg'), findsOneWidget);
      expect(find.text('28.5 km'), findsOneWidget);

      // Tap card to open modal breakdown
      await tester.tap(find.text('HYBRID ATHLETE ENGINE'));
      await tester.pumpAndSettle();

      expect(find.text('HYBRID BIO-MECHANICS & READINESS'), findsOneWidget);
      expect(find.text('MOLECULAR MECHANISM (mTOR vs AMPK):'), findsOneWidget);
      expect(find.text('GOT IT'), findsOneWidget);

      // Dismiss modal
      await tester.tap(find.text('GOT IT'));
      await tester.pumpAndSettle();
      expect(find.text('HYBRID BIO-MECHANICS & READINESS'), findsNothing);
    });
  });
}
