import 'package:flutter/foundation.dart';

/// Strategy applied by the progressive overload engine for an exercise.
enum OverloadStrategy {
  increaseWeight,
  increaseReps,
  maintain,
  deload,
}

/// Readiness tier representing a muscle group's recovery status.
enum ReadinessTier {
  optimal, // >= 80% recovered
  moderate, // 50% - 79% recovered
  fatigued, // < 50% recovered
}

/// A completed historical set entry.
@immutable
class HistoricalSet {
  final double weight;
  final int reps;
  final String type; // warmup, normal, drop, failure
  final int? rir; // Reps in reserve (0-5)

  const HistoricalSet({
    required this.weight,
    required this.reps,
    this.type = 'normal',
    this.rir,
  });

  bool get isWarmup => type.toLowerCase() == 'warmup';
}

/// Historical session summary for an exercise.
@immutable
class ExerciseSessionHistory {
  final DateTime workoutDate;
  final List<HistoricalSet> workingSets;

  const ExerciseSessionHistory({
    required this.workoutDate,
    required this.workingSets,
  });

  HistoricalSet? get topSet {
    if (workingSets.isEmpty) return null;
    return workingSets.reduce((curr, next) {
      final curr1RM = curr.weight * (1.0 + (curr.reps / 30.0));
      final next1RM = next.weight * (1.0 + (next.reps / 30.0));
      return curr1RM >= next1RM ? curr : next;
    });
  }

  double get maxOneRm {
    final top = topSet;
    if (top == null) return 0.0;
    if (top.reps <= 0 || top.weight <= 0) return 0.0;
    if (top.reps == 1) return top.weight;
    return top.weight * (1.0 + (top.reps / 30.0));
  }
}

/// Muscle group workout event record.
@immutable
class MuscleWorkoutEvent {
  final String muscleGroup;
  final DateTime timestamp;
  final double totalVolume;
  final int totalSets;

  const MuscleWorkoutEvent({
    required this.muscleGroup,
    required this.timestamp,
    required this.totalVolume,
    required this.totalSets,
  });
}

/// Actionable progressive overload recommendation for a specific exercise set.
@immutable
class OverloadRecommendation {
  final int exerciseId;
  final String exerciseName;
  final double recommendedWeight;
  final int recommendedReps;
  final OverloadStrategy strategy;
  final String reason;
  final double? previousWeight;
  final int? previousReps;
  final double estimatedOneRm;
  final double estimatedOneRmDelta;
  final bool isDeload;

  const OverloadRecommendation({
    required this.exerciseId,
    required this.exerciseName,
    required this.recommendedWeight,
    required this.recommendedReps,
    required this.strategy,
    required this.reason,
    this.previousWeight,
    this.previousReps,
    required this.estimatedOneRm,
    this.estimatedOneRmDelta = 0.0,
    this.isDeload = false,
  });

  /// Short headline formatted for HUDs and cards (e.g. "+2.5 kg Overload")
  String get headline {
    switch (strategy) {
      case OverloadStrategy.increaseWeight:
        final diff = (recommendedWeight - (previousWeight ?? 0.0)).abs();
        return '+${diff.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} kg Overload';
      case OverloadStrategy.increaseReps:
        final diff = (recommendedReps - (previousReps ?? 0)).abs();
        return '+$diff Reps Progression';
      case OverloadStrategy.deload:
        return 'Strategic Deload';
      case OverloadStrategy.maintain:
        return 'Consolidate Form';
    }
  }

  /// Compact target text (e.g. "82.5 kg × 8 reps")
  String formattedTarget(String weightUnit) {
    return '${recommendedWeight.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} $weightUnit × $recommendedReps reps';
  }
}

/// Muscle group recovery state and fatigue evaluation.
@immutable
class MuscleRecoveryReadiness {
  final String muscleGroup;
  final double recoveryPercentage; // 0.0 to 100.0
  final ReadinessTier tier;
  final double hoursSinceTrained;
  final double recentVolume; // Total volume in last 72h

  const MuscleRecoveryReadiness({
    required this.muscleGroup,
    required this.recoveryPercentage,
    required this.tier,
    required this.hoursSinceTrained,
    required this.recentVolume,
  });
}

/// System-wide recovery and daily workout split recommendation.
@immutable
class SystemicCoachState {
  final double overallReadinessScore; // 0.0 to 100.0
  final String recommendedSplit; // e.g. "Push (Chest & Triceps)", "Active Recovery"
  final String splitRationale;
  final List<MuscleRecoveryReadiness> muscleReadiness;
  final List<String> alerts;
  final bool deloadAdvised;

  const SystemicCoachState({
    required this.overallReadinessScore,
    required this.recommendedSplit,
    required this.splitRationale,
    required this.muscleReadiness,
    this.alerts = const [],
    this.deloadAdvised = false,
  });

  /// Factory for a fresh default state (e.g. new user or full recovery)
  factory SystemicCoachState.fresh() {
    const defaultMuscles = [
      'Chest',
      'Back',
      'Legs',
      'Shoulders',
      'Arms',
      'Core',
    ];
    return SystemicCoachState(
      overallReadinessScore: 100.0,
      recommendedSplit: 'Full Body / Compound Strength',
      splitRationale: 'All muscle groups are 100% primed and ready for intense training.',
      muscleReadiness: defaultMuscles
          .map(
            (m) => MuscleRecoveryReadiness(
              muscleGroup: m,
              recoveryPercentage: 100.0,
              tier: ReadinessTier.optimal,
              hoursSinceTrained: 999.0,
              recentVolume: 0.0,
            ),
          )
          .toList(),
    );
  }
}
