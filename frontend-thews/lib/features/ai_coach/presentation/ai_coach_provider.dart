import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/services/health_platform_service.dart';
import '../../../core/utils/volume_calculator.dart';
import '../domain/ai_coach_models.dart';
import '../domain/progressive_overload_engine.dart';
import '../domain/recovery_fatigue_calculator.dart';

/// Provider for systemic recovery score, daily workout split recommendations,
/// and muscle group readiness tiers.
final systemicCoachStateProvider =
    StreamProvider.autoDispose<SystemicCoachState>((ref) {
  final db = ref.watch(databaseProvider);
  final healthState = ref.watch(healthPlatformServiceProvider);

  // Watch workouts so state automatically recalculates when a session is logged or updated
  return db.watchAllWorkouts().asyncMap((workouts) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    final recentWorkouts =
        workouts.where((w) => w.date.isAfter(cutoff)).toList();

    if (recentWorkouts.isEmpty) {
      return SystemicCoachState.fresh();
    }

    final List<MuscleWorkoutEvent> events = [];

    for (final w in recentWorkouts) {
      final weQuery = db.select(db.workoutExercises)
        ..where((t) => t.workoutId.equals(w.id));
      final weList = await weQuery.get();

      for (final we in weList) {
        final exercise = await (db.select(db.exercises)
              ..where((t) => t.id.equals(we.exerciseId)))
            .getSingleOrNull();
        if (exercise == null) continue;

        final sets = await (db.select(db.setEntries)
              ..where((t) => t.workoutExerciseId.equals(we.id)))
            .get();
        if (sets.isEmpty) continue;

        double volume = 0.0;
        for (final s in sets) {
          volume += VolumeCalculator.calculateSetVolume(
            weight: s.weight,
            reps: s.reps,
            type: s.type,
            unit: s.unit,
          );
        }

        events.add(
          MuscleWorkoutEvent(
            muscleGroup: exercise.muscleGroup,
            timestamp: w.date,
            totalVolume: volume,
            totalSets: sets.length,
          ),
        );
      }
    }

    // Get resting heart rate from daily metrics if available
    final restingBpm = healthState.restingHeartRateBpm > 0
        ? healthState.restingHeartRateBpm.toDouble()
        : null;

    return RecoveryFatigueCalculator.computeSystemicReadiness(
      recentEvents: events,
      restingHeartRateBpm: restingBpm,
    );
  });
});

/// Provider for exercise-specific progressive overload recommendation.
final exerciseOverloadProvider = FutureProvider.autoDispose
    .family<OverloadRecommendation, int>((ref, exerciseId) async {
  final db = ref.watch(databaseProvider);

  final exercise = await (db.select(db.exercises)
        ..where((t) => t.id.equals(exerciseId)))
      .getSingleOrNull();

  if (exercise == null) {
    return OverloadRecommendation(
      exerciseId: exerciseId,
      exerciseName: 'Exercise',
      recommendedWeight: 20.0,
      recommendedReps: 8,
      strategy: OverloadStrategy.maintain,
      reason: 'Exercise definition not found.',
      estimatedOneRm: ProgressiveOverloadEngine.calculateEpleyOneRm(20.0, 8),
    );
  }

  // Fetch all previous sessions for this exercise
  final weQuery = db.select(db.workoutExercises)
    ..where((t) => t.exerciseId.equals(exerciseId))
    ..orderBy([(t) => OrderingTerm.asc(t.id)]);
  final weList = await weQuery.get();

  final List<ExerciseSessionHistory> sessionHistories = [];

  for (final we in weList) {
    final workout = await (db.select(db.workouts)
          ..where((t) => t.id.equals(we.workoutId)))
        .getSingleOrNull();
    if (workout == null) continue;

    final sets = await (db.select(db.setEntries)
          ..where((t) => t.workoutExerciseId.equals(we.id))
          ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
        .get();
    if (sets.isEmpty) continue;

    final workingSets = sets
        .map(
          (s) => HistoricalSet(
            weight: s.weight,
            reps: s.reps,
            type: s.type,
          ),
        )
        .toList();

    sessionHistories.add(
      ExerciseSessionHistory(
        workoutDate: workout.date,
        workingSets: workingSets,
      ),
    );
  }

  return ProgressiveOverloadEngine.computeRecommendation(
    exerciseId: exercise.id,
    exerciseName: exercise.name,
    muscleGroup: exercise.muscleGroup,
    sessionHistories: sessionHistories,
  );
});
