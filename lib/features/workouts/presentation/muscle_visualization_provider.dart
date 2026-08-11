import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/volume_calculator.dart';

enum MuscleTimeframe { week, month, all }

class MuscleGroupStats {
  final String muscleGroup;
  final double totalVolume;
  final int totalSets;
  final int totalWorkouts;
  final List<MuscleTopExercise> topExercises;

  MuscleGroupStats({
    required this.muscleGroup,
    required this.totalVolume,
    required this.totalSets,
    required this.totalWorkouts,
    required this.topExercises,
  });

  /// Recommended weekly target: ~16 sets for optimal hypertrophy
  double get targetSetPercentage => (totalSets / 16.0).clamp(0.0, 1.0);

  String get statusLabel {
    if (totalSets == 0) return 'Resting';
    if (totalSets < 6) return 'Lightly Trained';
    if (totalSets <= 16) return 'Optimal Target';
    return 'High Volume';
  }
}

class MuscleTopExercise {
  final String name;
  final int sets;
  final double maxWeight;
  final double totalVolume;

  MuscleTopExercise({
    required this.name,
    required this.sets,
    required this.maxWeight,
    required this.totalVolume,
  });
}

final muscleTimeframeProvider = StateProvider<MuscleTimeframe>(
  (ref) => MuscleTimeframe.week,
);
final selectedVisualizationMuscleProvider = StateProvider<String>(
  (ref) => 'Chest',
);

String normalizeMuscleGroupName(String group) {
  final lower = group.toLowerCase().trim();
  if (lower.contains('forearm') || lower.contains('wrist')) return 'Forearms';
  if (lower.contains('bicep')) return 'Biceps';
  if (lower.contains('tricep')) return 'Triceps';
  if (lower.contains('neck')) return 'Neck';
  if (lower.contains('core') || lower.contains('ab')) return 'Core / Abs';
  if (lower.contains('chest')) return 'Chest';
  if (lower.contains('back') || lower.contains('lat')) return 'Back';
  if (lower.contains('shoulder') || lower.contains('delt')) return 'Shoulders';
  if (lower.contains('leg') || lower.contains('quad') || lower.contains('thigh') || lower.contains('calf') || lower.contains('hamstring') || lower.contains('glute')) return 'Legs';
  if (lower.contains('cardio') || lower.contains('run')) return 'Cardio';
  return 'Arms';
}

final muscleVisualizationProvider =
    FutureProvider<Map<String, MuscleGroupStats>>((ref) async {
      final db = ref.watch(databaseProvider);
      final timeframe = ref.watch(muscleTimeframeProvider);

      final workouts = await db.getAllWorkouts();
      final now = DateTime.now();

      final filteredWorkouts = workouts.where((w) {
        if (timeframe == MuscleTimeframe.week) {
          final weekAgo = now.subtract(const Duration(days: 7));
          return w.date.isAfter(weekAgo);
        } else if (timeframe == MuscleTimeframe.month) {
          final monthAgo = now.subtract(const Duration(days: 30));
          return w.date.isAfter(monthAgo);
        }
        return true; // All time
      }).toList();

      final Map<String, double> volumeMap = {};
      final Map<String, int> setsMap = {};
      final Map<String, Set<int>> workoutsMap = {};
      final Map<String, Map<String, MuscleTopExercise>> exMap = {};

      final groups = [
        'Forearms',
        'Chest',
        'Core / Abs',
        'Core',
        'Legs',
        'Back',
        'Biceps',
        'Triceps',
        'Shoulders',
        'Neck',
        'Arms',
        'Cardio',
      ];
      for (final g in groups) {
        volumeMap[g] = 0.0;
        setsMap[g] = 0;
        workoutsMap[g] = {};
        exMap[g] = {};
      }

      for (final w in filteredWorkouts) {
        final details = await db.watchWorkoutDetails(w.id).first;
        for (final detail in details) {
          final rawGroup = detail.exercise.muscleGroup;
          final primaryGroup = normalizeMuscleGroupName(rawGroup);
          final setList = detail.sets;

          double exVol = 0.0;
          double exMaxWeight = 0.0;
          for (final s in setList) {
            exVol += VolumeCalculator.calculateSetVolume(
              weight: s.weight,
              reps: s.reps,
              type: s.type,
              unit: s.unit,
            );
            if (s.weight > exMaxWeight) exMaxWeight = s.weight;
          }

          // 1. Primary Muscle Contribution (100% Volume & Sets)
          if (!volumeMap.containsKey(primaryGroup)) {
            volumeMap[primaryGroup] = 0.0;
            setsMap[primaryGroup] = 0;
            workoutsMap[primaryGroup] = {};
            exMap[primaryGroup] = {};
          }

          workoutsMap[primaryGroup]!.add(w.id);
          setsMap[primaryGroup] =
              (setsMap[primaryGroup] ?? 0) + setList.length;
          volumeMap[primaryGroup] = (volumeMap[primaryGroup] ?? 0.0) + exVol;

          if (!exMap[primaryGroup]!.containsKey(detail.exercise.name)) {
            exMap[primaryGroup]![detail.exercise.name] = MuscleTopExercise(
              name: detail.exercise.name,
              sets: setList.length,
              maxWeight: exMaxWeight,
              totalVolume: exVol,
            );
          } else {
            final existing = exMap[primaryGroup]![detail.exercise.name]!;
            exMap[primaryGroup]![detail.exercise.name] = MuscleTopExercise(
              name: detail.exercise.name,
              sets: existing.sets + setList.length,
              maxWeight: exMaxWeight > existing.maxWeight
                  ? exMaxWeight
                  : existing.maxWeight,
              totalVolume: existing.totalVolume + exVol,
            );
          }

          // 2. Secondary / Minor Muscle Group Contribution (50% Volume & Sets)
          final secGroupsStr = detail.exercise.secondaryMuscleGroups;
          if (secGroupsStr != null && secGroupsStr.isNotEmpty) {
            final secList = secGroupsStr
                .split(',')
                .map((s) => normalizeMuscleGroupName(s.trim()))
                .toList();
            for (final sec in secList) {
              if (sec != primaryGroup) {
                if (!volumeMap.containsKey(sec)) {
                  volumeMap[sec] = 0.0;
                  setsMap[sec] = 0;
                  workoutsMap[sec] = {};
                  exMap[sec] = {};
                }

                workoutsMap[sec]!.add(w.id);
                setsMap[sec] =
                    (setsMap[sec] ?? 0) + (setList.length * 0.5).round();
                volumeMap[sec] = (volumeMap[sec] ?? 0.0) + (exVol * 0.5);

                final secExName = '${detail.exercise.name} (Secondary)';
                if (!exMap[sec]!.containsKey(secExName)) {
                  exMap[sec]![secExName] = MuscleTopExercise(
                    name: secExName,
                    sets: setList.length,
                    maxWeight: exMaxWeight,
                    totalVolume: exVol * 0.5,
                  );
                } else {
                  final existing = exMap[sec]![secExName]!;
                  exMap[sec]![secExName] = MuscleTopExercise(
                    name: secExName,
                    sets: existing.sets + setList.length,
                    maxWeight: exMaxWeight > existing.maxWeight
                        ? exMaxWeight
                        : existing.maxWeight,
                    totalVolume: existing.totalVolume + (exVol * 0.5),
                  );
                }
              }
            }
          }
        }
      }

      final Map<String, MuscleGroupStats> result = {};
      for (final g in volumeMap.keys) {
        final topList = (exMap[g]?.values.toList() ?? [])
          ..sort((a, b) => b.totalVolume.compareTo(a.totalVolume));

        result[g] = MuscleGroupStats(
          muscleGroup: g,
          totalVolume: volumeMap[g] ?? 0.0,
          totalSets: setsMap[g] ?? 0,
          totalWorkouts: workoutsMap[g]?.length ?? 0,
          topExercises: topList,
        );
      }

      return result;
    });
