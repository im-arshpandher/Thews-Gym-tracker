import '../../ai_coach/domain/ai_coach_models.dart';
import '../../ai_coach/domain/recovery_fatigue_calculator.dart';
import '../../running/domain/trimp_workload_calculator.dart';
import 'interference_optimizer.dart';

enum HybridReadinessTier {
  prime, // 85 - 100
  optimal, // 65 - 84
  fatigued, // 45 - 64
  overreached, // 0 - 44
}

class HybridReadinessMetrics {
  final int overallScore; // 0 - 100
  final HybridReadinessTier tier;
  final double neuromuscularFatiguePct; // 0.0 - 100.0%
  final double cardiovascularStrainPct; // 0.0 - 100.0%
  final double weeklyLiftingTonnageKg;
  final double weeklyRunningDistanceKm;
  final double weeklyElevationGainMeters;
  final int weeklyLiftingWorkoutsCount;
  final int weeklyRunningActivitiesCount;
  final InterferenceAdvisorResult interferenceResult;
  final String primaryRecommendation;
  final String suggestedTrainingFocus;
  final List<String> recoveryInsights;

  const HybridReadinessMetrics({
    required this.overallScore,
    required this.tier,
    required this.neuromuscularFatiguePct,
    required this.cardiovascularStrainPct,
    required this.weeklyLiftingTonnageKg,
    required this.weeklyRunningDistanceKm,
    required this.weeklyElevationGainMeters,
    required this.weeklyLiftingWorkoutsCount,
    required this.weeklyRunningActivitiesCount,
    required this.interferenceResult,
    required this.primaryRecommendation,
    required this.suggestedTrainingFocus,
    required this.recoveryInsights,
  });

  factory HybridReadinessMetrics.initial() {
    return HybridReadinessMetrics(
      overallScore: 92,
      tier: HybridReadinessTier.prime,
      neuromuscularFatiguePct: 8.0,
      cardiovascularStrainPct: 5.0,
      weeklyLiftingTonnageKg: 0.0,
      weeklyRunningDistanceKm: 0.0,
      weeklyElevationGainMeters: 0.0,
      weeklyLiftingWorkoutsCount: 0,
      weeklyRunningActivitiesCount: 0,
      interferenceResult: InterferenceAdvisorResult.optimal(),
      primaryRecommendation: 'Fully primed for high-performance resistance or endurance work.',
      suggestedTrainingFocus: 'Heavy Lower Body Hypertrophy or High-Intensity Intervals',
      recoveryInsights: const ['Muscles fully restored (100% freshness)', 'Aerobic capacity primed'],
    );
  }
}

class UnifiedReadinessEngine {
  /// Computes the unified hybrid athlete readiness score and prescriptive advice.
  static HybridReadinessMetrics calculate({
    required List<MuscleWorkoutEvent> recentLiftingEvents,
    required List<HybridLiftingSession> liftingSessions,
    required List<HybridRunningSession> runningSessions,
    required List<double> past28DaysDailyTrimps,
    double currentSessionTrimp = 0.0,
    DateTime? referenceTime,
  }) {
    final now = referenceTime ?? DateTime.now();

    // 1. Calculate Systemic Neuromuscular Fatigue from Lifting
    final systemicState = RecoveryFatigueCalculator.computeSystemicReadiness(
      recentEvents: recentLiftingEvents,
      referenceTime: now,
    );
    final double neuromuscularFatigue = (100.0 - systemicState.overallReadinessScore).clamp(0.0, 100.0);

    // 2. Calculate Cardiovascular Strain from Running (TRIMP & ACWR)
    final workload = TrimpWorkloadCalculator.evaluateAcwr(
      currentSessionTrimp: currentSessionTrimp,
      past28DaysDailyTrimps: past28DaysDailyTrimps,
    );

    // Cardiovascular strain scaled 0 - 100% based on acute load and ACWR ratio
    double cardioStrain = (workload.acuteWorkload / 80.0 * 50.0);
    if (workload.acwr > 1.3) {
      cardioStrain += (workload.acwr - 1.3) * 60.0;
    }
    cardioStrain = cardioStrain.clamp(0.0, 100.0);

    // 3. Evaluate mTOR vs AMPK Interference
    final interference = InterferenceOptimizer.evaluateInterference(
      recentLiftingSessions: liftingSessions,
      recentRunningSessions: runningSessions,
      referenceTime: now,
    );

    // 4. Compute 7-day Totals
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    double weeklyTonnage = 0.0;
    int weeklyLiftingCount = 0;
    for (final session in liftingSessions) {
      if (session.timestamp.isAfter(sevenDaysAgo)) {
        weeklyTonnage += session.totalVolumeKg;
        weeklyLiftingCount++;
      }
    }

    double weeklyDistance = 0.0;
    int weeklyRunCount = 0;
    for (final session in runningSessions) {
      if (session.timestamp.isAfter(sevenDaysAgo)) {
        weeklyDistance += session.distanceKm;
        weeklyRunCount++;
      }
    }

    // 5. Unified Readiness Formula:
    // 50% Neuromuscular + 35% Cardiovascular + 15% Interference Penalty
    final double rawFatigue = (neuromuscularFatigue * 0.50) +
        (cardioStrain * 0.35) +
        (interference.interferencePenaltyScore * 0.60);

    final int readinessScore = (100.0 - rawFatigue).round().clamp(0, 100);

    final HybridReadinessTier tier;
    if (readinessScore >= 85) {
      tier = HybridReadinessTier.prime;
    } else if (readinessScore >= 65) {
      tier = HybridReadinessTier.optimal;
    } else if (readinessScore >= 45) {
      tier = HybridReadinessTier.fatigued;
    } else {
      tier = HybridReadinessTier.overreached;
    }

    // 6. Actionable recommendations & insights
    final List<String> insights = [];
    final String suggestedFocus;
    final String recommendation;

    if (interference.riskLevel == InterferenceRiskLevel.high) {
      insights.add('⚠️ High interference risk: Recent heavy leg volume requires 6h+ window.');
      suggestedFocus = 'Zone 2 Active Recovery or Upper Body Push/Pull';
      recommendation = 'Hold off on high-intensity running for ${interference.recommendedRunDelay.inHours}h to maximize muscle protein synthesis.';
    } else if (tier == HybridReadinessTier.prime) {
      insights.add('⚡ Optimal neuromuscular & aerobic readiness across all systems.');
      suggestedFocus = 'Heavy Compound Lifting or High-Intensity Tempo Run';
      recommendation = 'Prime recovery state. Excellent window for PR attempts or high-volume hybrid sessions.';
    } else if (tier == HybridReadinessTier.optimal) {
      insights.add('Balanced hybrid load. Recovery rates within target threshold.');
      suggestedFocus = 'Standard Hypertrophy or Steady-State Aerobic Base';
      recommendation = 'Proceed with planned split. Stay hydrated and prioritize post-session nutrition.';
    } else if (tier == HybridReadinessTier.fatigued) {
      insights.add('Cumulative fatigue elevated. Neuromuscular readiness at ${systemicState.overallReadinessScore.toInt()}%.');
      suggestedFocus = 'Deload Session, Core/Mobility, or Light Walk';
      recommendation = 'Reduce working sets by 20–30% or keep running pace strictly in Zone 1/2.';
    } else {
      insights.add('🚨 High overtraining risk. Acute workload spike detected.');
      suggestedFocus = 'Full Rest & Recovery';
      recommendation = 'Prioritize 8+ hours of sleep and full systemic rest to prevent joint/tendon injury.';
    }

    return HybridReadinessMetrics(
      overallScore: readinessScore,
      tier: tier,
      neuromuscularFatiguePct: double.parse(neuromuscularFatigue.toStringAsFixed(1)),
      cardiovascularStrainPct: double.parse(cardioStrain.toStringAsFixed(1)),
      weeklyLiftingTonnageKg: double.parse(weeklyTonnage.toStringAsFixed(1)),
      weeklyRunningDistanceKm: double.parse(weeklyDistance.toStringAsFixed(2)),
      weeklyElevationGainMeters: 0.0,
      weeklyLiftingWorkoutsCount: weeklyLiftingCount,
      weeklyRunningActivitiesCount: weeklyRunCount,
      interferenceResult: interference,
      primaryRecommendation: recommendation,
      suggestedTrainingFocus: suggestedFocus,
      recoveryInsights: insights,
    );
  }
}
