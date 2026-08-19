import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/utils/volume_calculator.dart';
import '../../ai_coach/domain/ai_coach_models.dart';
import '../../running/domain/trimp_workload_calculator.dart';
import '../domain/interference_optimizer.dart';
import '../domain/unified_readiness_engine.dart';

/// Provider that calculates the unified hybrid readiness metrics across both
/// strength resistance training and outdoor endurance running activities.
final hybridReadinessProvider =
    StreamProvider.autoDispose<HybridReadinessMetrics>((ref) {
  final db = ref.watch(databaseProvider);

  // Watch both workouts and run activities so state reacts automatically
  return db.watchAllWorkouts().asyncMap((workouts) async {
    final runs = await db.watchAllRunActivities().first;

    final cutoff = DateTime.now().subtract(const Duration(days: 28));
    final recentWorkouts = workouts.where((w) => w.date.isAfter(cutoff)).toList();
    final recentRuns = runs.where((r) => r.startTime.isAfter(cutoff)).toList();

    final List<MuscleWorkoutEvent> muscleEvents = [];
    final List<HybridLiftingSession> liftingSessions = [];

    for (final w in recentWorkouts) {
      final weQuery = db.select(db.workoutExercises)
        ..where((t) => t.workoutId.equals(w.id));
      final weList = await weQuery.get();

      double sessionTotalVolume = 0.0;
      int legSets = 0;
      bool hasHeavyLegCompound = false;

      for (final we in weList) {
        final exercise = await (db.select(db.exercises)
              ..where((t) => t.id.equals(we.exerciseId)))
            .getSingleOrNull();
        if (exercise == null) continue;

        final sets = await (db.select(db.setEntries)
              ..where((t) => t.workoutExerciseId.equals(we.id)))
            .get();
        if (sets.isEmpty) continue;

        double exerciseVolume = 0.0;
        for (final s in sets) {
          final vol = VolumeCalculator.calculateSetVolume(
            weight: s.weight,
            reps: s.reps,
            type: s.type,
            unit: s.unit,
          );
          exerciseVolume += vol;
        }

        sessionTotalVolume += exerciseVolume;

        final muscle = exercise.muscleGroup.toLowerCase();
        final name = exercise.name.toLowerCase();
        final isLeg = muscle.contains('leg') ||
            muscle.contains('quad') ||
            muscle.contains('hamstring') ||
            muscle.contains('glute') ||
            muscle.contains('calv');

        if (isLeg) {
          legSets += sets.length;
          if (name.contains('squat') ||
              name.contains('deadlift') ||
              name.contains('leg press') ||
              name.contains('lunge') ||
              name.contains('rdl')) {
            hasHeavyLegCompound = true;
          }
        }

        muscleEvents.add(
          MuscleWorkoutEvent(
            muscleGroup: exercise.muscleGroup,
            timestamp: w.date,
            totalVolume: exerciseVolume,
            totalSets: sets.length,
          ),
        );
      }

      liftingSessions.add(
        HybridLiftingSession(
          timestamp: w.date,
          totalVolumeKg: sessionTotalVolume,
          legSetsCount: legSets,
          hasHeavyLowerBodyCompound: hasHeavyLegCompound,
        ),
      );
    }

    // Process Running Sessions
    final List<HybridRunningSession> runningSessions = [];
    final List<double> past28DailyTrimps = List.filled(28, 0.0);
    final now = DateTime.now();

    for (final r in recentRuns) {
      final daysAgo = now.difference(r.startTime).inDays.clamp(0, 27);
      final distKm = r.distanceMeters / 1000.0;

      // Estimate TRIMP from pace & duration
      final speedKmh = r.durationSeconds > 0 ? (distKm / (r.durationSeconds / 3600.0)) : 0.0;
      final isHighIntensity = speedKmh > 12.0 || (r.avgPaceSecondsPerKm > 0 && r.avgPaceSecondsPerKm < 300);

      final estTrimp = TrimpWorkloadCalculator.calculateTrimp(
        durationSeconds: r.durationSeconds,
        averageHeartRateBpm: isHighIntensity ? 165 : 140,
      );

      past28DailyTrimps[daysAgo] += estTrimp;

      runningSessions.add(
        HybridRunningSession(
          timestamp: r.startTime,
          distanceKm: distKm,
          durationSeconds: r.durationSeconds,
          isHighIntensity: isHighIntensity,
        ),
      );
    }

    return UnifiedReadinessEngine.calculate(
      recentLiftingEvents: muscleEvents,
      liftingSessions: liftingSessions,
      runningSessions: runningSessions,
      past28DaysDailyTrimps: past28DailyTrimps,
      referenceTime: now,
    );
  });
});
