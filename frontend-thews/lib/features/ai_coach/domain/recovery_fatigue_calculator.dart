import 'dart:math' as math;
import 'ai_coach_models.dart';

/// Computes systemic fatigue, physiological muscle recovery rates, and
/// daily workout split suggestions.
class RecoveryFatigueCalculator {
  static const List<String> primaryMuscleGroups = [
    'Chest',
    'Back',
    'Legs',
    'Shoulders',
    'Arms',
    'Core',
  ];

  /// Half-life of muscle fatigue in hours (~24 hours for moderate to high volume).
  static const double fatigueHalfLifeHours = 24.0;

  /// Calculate the recovery state for all primary muscle groups given historical workout events.
  static SystemicCoachState computeSystemicReadiness({
    required List<MuscleWorkoutEvent> recentEvents,
    DateTime? referenceTime,
    double? restingHeartRateBpm,
  }) {
    final now = referenceTime ?? DateTime.now();

    if (recentEvents.isEmpty && (restingHeartRateBpm == null || restingHeartRateBpm <= 75.0)) {
      return SystemicCoachState.fresh();
    }

    final List<MuscleRecoveryReadiness> muscleReadinessList = [];
    final List<String> alerts = [];

    // Group events by muscle group
    final Map<String, List<MuscleWorkoutEvent>> eventsByMuscle = {};
    for (final muscle in primaryMuscleGroups) {
      eventsByMuscle[muscle] = [];
    }

    for (final event in recentEvents) {
      final normalized = _normalizeMuscleGroup(event.muscleGroup);
      if (eventsByMuscle.containsKey(normalized)) {
        eventsByMuscle[normalized]!.add(event);
      }
    }

    double weightedSystemicFatigue = 0.0;
    double totalMuscleWeight = 0.0;

    for (final muscle in primaryMuscleGroups) {
      final events = eventsByMuscle[muscle] ?? [];
      double accumulatedFatigue = 0.0;
      double hoursSinceLastTrained = 999.0;
      double recent72hVolume = 0.0;

      for (final ev in events) {
        final hoursAgo = now.difference(ev.timestamp).inMinutes / 60.0;
        if (hoursAgo < 0) continue;

        if (hoursAgo < hoursSinceLastTrained) {
          hoursSinceLastTrained = hoursAgo;
        }

        if (hoursAgo <= 72.0) {
          recent72hVolume += ev.totalVolume;
          // Volume scaling factor: 5 sets standard baseline (~100% initial fatigue)
          final volumeFactor = math.min(1.5, math.max(0.5, ev.totalSets / 5.0));
          final initialFatigue = 100.0 * volumeFactor;
          final decay = math.exp(-0.69315 * (hoursAgo / fatigueHalfLifeHours));
          accumulatedFatigue += initialFatigue * decay;
        }
      }

      accumulatedFatigue = math.min(100.0, accumulatedFatigue);
      final recoveryPct = math.max(0.0, 100.0 - accumulatedFatigue);

      final ReadinessTier tier;
      if (recoveryPct >= 80.0) {
        tier = ReadinessTier.optimal;
      } else if (recoveryPct >= 50.0) {
        tier = ReadinessTier.moderate;
      } else {
        tier = ReadinessTier.fatigued;
      }

      muscleReadinessList.add(
        MuscleRecoveryReadiness(
          muscleGroup: muscle,
          recoveryPercentage: double.parse(recoveryPct.toStringAsFixed(1)),
          tier: tier,
          hoursSinceTrained: hoursSinceLastTrained == 999.0
              ? 999.0
              : double.parse(hoursSinceLastTrained.toStringAsFixed(1)),
          recentVolume: double.parse(recent72hVolume.toStringAsFixed(1)),
        ),
      );

      final weight = _getMuscleFatigueWeight(muscle);
      weightedSystemicFatigue += (100.0 - recoveryPct) * weight;
      totalMuscleWeight += weight;
    }

    final averageSystemicFatigue = totalMuscleWeight > 0
        ? weightedSystemicFatigue / totalMuscleWeight
        : 0.0;

    double systemicScore = math.max(0.0, 100.0 - averageSystemicFatigue);

    // Biometric adjustment: High resting heart rate adds systemic fatigue penalty
    if (restingHeartRateBpm != null && restingHeartRateBpm > 75.0) {
      final penalty = math.min(15.0, (restingHeartRateBpm - 75.0) * 0.75);
      systemicScore = math.max(10.0, systemicScore - penalty);
      alerts.add(
        'Elevated resting heart rate (${restingHeartRateBpm.toStringAsFixed(0)} BPM) indicates systemic nervous fatigue.',
      );
    }

    // Determine optimal daily split recommendation
    final splitRecommendation = _determineRecommendedSplit(muscleReadinessList);

    return SystemicCoachState(
      overallReadinessScore: double.parse(systemicScore.toStringAsFixed(1)),
      recommendedSplit: splitRecommendation.$1,
      splitRationale: splitRecommendation.$2,
      muscleReadiness: muscleReadinessList,
      alerts: alerts,
      deloadAdvised: systemicScore < 45.0,
    );
  }

  static (String, String) _determineRecommendedSplit(
    List<MuscleRecoveryReadiness> readinessList,
  ) {
    final map = {for (var m in readinessList) m.muscleGroup: m.recoveryPercentage};
    final chestRec = map['Chest'] ?? 100.0;
    final backRec = map['Back'] ?? 100.0;
    final legsRec = map['Legs'] ?? 100.0;
    final shouldersRec = map['Shoulders'] ?? 100.0;
    final armsRec = map['Arms'] ?? 100.0;

    final pushReadiness = (chestRec + shouldersRec + armsRec) / 3.0;
    final pullReadiness = (backRec + armsRec) / 2.0;
    final legsReadiness = legsRec;

    if (pushReadiness < 40 && pullReadiness < 40 && legsReadiness < 40) {
      return (
        'Active Recovery & Mobility',
        'Systemic fatigue is elevated across all muscle groups. Focus on hydration, mobility, and light walking.',
      );
    }

    if (pushReadiness >= pullReadiness && pushReadiness >= legsReadiness) {
      return (
        'Push / Chest & Shoulders',
        'Chest (${chestRec.toStringAsFixed(0)}%) and Shoulders (${shouldersRec.toStringAsFixed(0)}%) are well-recovered and ready for progressive overload.',
      );
    } else if (pullReadiness >= legsReadiness) {
      return (
        'Pull / Back & Biceps',
        'Back (${backRec.toStringAsFixed(0)}%) is at peak readiness for heavy vertical and horizontal pulling.',
      );
    } else {
      return (
        'Legs / Quad & Hamstring Power',
        'Lower body (${legsRec.toStringAsFixed(0)}%) is fully rested and primed for heavy squatting and deadlifts.',
      );
    }
  }

  static double _getMuscleFatigueWeight(String muscle) {
    switch (muscle.toLowerCase()) {
      case 'legs':
        return 1.8;
      case 'back':
        return 1.5;
      case 'chest':
        return 1.3;
      case 'shoulders':
        return 1.0;
      case 'arms':
        return 0.8;
      case 'core':
        return 0.6;
      default:
        return 1.0;
    }
  }

  static String _normalizeMuscleGroup(String input) {
    final lower = input.toLowerCase().trim();
    if (lower.contains('chest') || lower.contains('pec')) return 'Chest';
    if (lower.contains('back') || lower.contains('lat') || lower.contains('trap')) return 'Back';
    if (lower.contains('leg') || lower.contains('quad') || lower.contains('hamstring') || lower.contains('glute') || lower.contains('calf')) return 'Legs';
    if (lower.contains('shoulder') || lower.contains('delt')) return 'Shoulders';
    if (lower.contains('arm') || lower.contains('bicep') || lower.contains('tricep') || lower.contains('forearm')) return 'Arms';
    if (lower.contains('core') || lower.contains('ab')) return 'Core';
    return 'Chest';
  }
}
