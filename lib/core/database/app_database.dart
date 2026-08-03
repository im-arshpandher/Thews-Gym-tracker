import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Exercises,
    Workouts,
    WorkoutExercises,
    SetEntries,
    Routines,
    RoutineExercises,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        // Seed default exercise library
        await batch((b) {
          b.insertAll(exercises, [
            ExercisesCompanion.insert(
              name: 'Barbell Bench Press',
              muscleGroup: 'Chest',
              secondaryMuscleGroups: const Value('Shoulders, Arms'),
            ),
            ExercisesCompanion.insert(
              name: 'Incline Dumbbell Press',
              muscleGroup: 'Chest',
              secondaryMuscleGroups: const Value('Shoulders, Arms'),
            ),
            ExercisesCompanion.insert(
              name: 'Chest Fly',
              muscleGroup: 'Chest',
              secondaryMuscleGroups: const Value('Shoulders'),
            ),
            ExercisesCompanion.insert(
              name: 'Barbell Squat',
              muscleGroup: 'Legs',
              secondaryMuscleGroups: const Value('Core'),
            ),
            ExercisesCompanion.insert(name: 'Leg Press', muscleGroup: 'Legs'),
            ExercisesCompanion.insert(
              name: 'Romanian Deadlift',
              muscleGroup: 'Legs',
              secondaryMuscleGroups: const Value('Back'),
            ),
            ExercisesCompanion.insert(
              name: 'Conventional Deadlift',
              muscleGroup: 'Back',
              secondaryMuscleGroups: const Value('Legs, Core'),
            ),
            ExercisesCompanion.insert(
              name: 'Lat Pulldown',
              muscleGroup: 'Back',
              secondaryMuscleGroups: const Value('Arms'),
            ),
            ExercisesCompanion.insert(
              name: 'Bent Over Row',
              muscleGroup: 'Back',
              secondaryMuscleGroups: const Value('Arms'),
            ),
            ExercisesCompanion.insert(
              name: 'Overhead Shoulder Press',
              muscleGroup: 'Shoulders',
              secondaryMuscleGroups: const Value('Arms, Core'),
            ),
            ExercisesCompanion.insert(
              name: 'Lateral Raise',
              muscleGroup: 'Shoulders',
            ),
            ExercisesCompanion.insert(
              name: 'Bicep Barbell Curl',
              muscleGroup: 'Arms',
            ),
            ExercisesCompanion.insert(
              name: 'Tricep Rope Pushdown',
              muscleGroup: 'Arms',
            ),
            ExercisesCompanion.insert(
              name: 'Hanging Leg Raise',
              muscleGroup: 'Core',
            ),
            ExercisesCompanion.insert(
              name: 'Ab Wheel Rollout',
              muscleGroup: 'Core',
              secondaryMuscleGroups: const Value('Arms'),
            ),
            ExercisesCompanion.insert(
              name: 'Treadmill Run',
              muscleGroup: 'Cardio',
              secondaryMuscleGroups: const Value('Legs'),
            ),
          ]);
        });

        // Seed initial sample routines
        final pushId = await into(routines).insert(
          RoutinesCompanion.insert(
            name: 'Push Hypertrophy',
            description: Value('Chest, Shoulders & Triceps focus routine'),
          ),
        );
        await into(routineExercises).insert(
          RoutineExercisesCompanion.insert(
            routineId: pushId,
            exerciseId: 1,
            targetSets: const Value(3),
            targetReps: const Value(10),
            sortOrder: const Value(0),
          ),
        );
        await into(routineExercises).insert(
          RoutineExercisesCompanion.insert(
            routineId: pushId,
            exerciseId: 2,
            targetSets: const Value(3),
            targetReps: const Value(12),
            sortOrder: const Value(1),
          ),
        );
        await into(routineExercises).insert(
          RoutineExercisesCompanion.insert(
            routineId: pushId,
            exerciseId: 10,
            targetSets: const Value(3),
            targetReps: const Value(10),
            sortOrder: const Value(2),
          ),
        );
        await into(routineExercises).insert(
          RoutineExercisesCompanion.insert(
            routineId: pushId,
            exerciseId: 13,
            targetSets: const Value(3),
            targetReps: const Value(12),
            sortOrder: const Value(3),
          ),
        );

        final pullId = await into(routines).insert(
          RoutinesCompanion.insert(
            name: 'Pull Power',
            description: Value('Back & Biceps workout routine'),
          ),
        );
        await into(routineExercises).insert(
          RoutineExercisesCompanion.insert(
            routineId: pullId,
            exerciseId: 7,
            targetSets: const Value(3),
            targetReps: const Value(8),
            sortOrder: const Value(0),
          ),
        );
        await into(routineExercises).insert(
          RoutineExercisesCompanion.insert(
            routineId: pullId,
            exerciseId: 8,
            targetSets: const Value(3),
            targetReps: const Value(10),
            sortOrder: const Value(1),
          ),
        );
        await into(routineExercises).insert(
          RoutineExercisesCompanion.insert(
            routineId: pullId,
            exerciseId: 9,
            targetSets: const Value(3),
            targetReps: const Value(10),
            sortOrder: const Value(2),
          ),
        );
        await into(routineExercises).insert(
          RoutineExercisesCompanion.insert(
            routineId: pullId,
            exerciseId: 12,
            targetSets: const Value(3),
            targetReps: const Value(12),
            sortOrder: const Value(3),
          ),
        );
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(exercises, exercises.videoUrl);
        }
        if (from < 3) {
          await m.addColumn(setEntries, setEntries.type);
          await m.createTable(routines);
          await m.createTable(routineExercises);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
        try {
          await customStatement(
            'ALTER TABLE exercises ADD COLUMN video_url TEXT;',
          );
        } catch (_) {}
        try {
          await customStatement(
            "ALTER TABLE set_entries ADD COLUMN type TEXT DEFAULT 'normal';",
          );
        } catch (_) {}
        try {
          await customStatement(
            "CREATE TABLE IF NOT EXISTS routines (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, description TEXT, created_at INTEGER NOT NULL DEFAULT (UNIXEPOCH()));",
          );
        } catch (_) {}
        try {
          await customStatement(
            "CREATE TABLE IF NOT EXISTS routine_exercises (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, routine_id INTEGER NOT NULL REFERENCES routines (id) ON DELETE CASCADE, exercise_id INTEGER NOT NULL REFERENCES exercises (id) ON DELETE CASCADE, target_sets INTEGER NOT NULL DEFAULT 3, target_reps INTEGER NOT NULL DEFAULT 10, target_weight REAL NOT NULL DEFAULT 0.0, sort_order INTEGER NOT NULL DEFAULT 0);",
          );
        } catch (_) {}
        try {
          await customStatement(
            "ALTER TABLE routine_exercises ADD COLUMN target_weight REAL DEFAULT 0.0;",
          );
        } catch (_) {}
        try {
          await customStatement(
            "ALTER TABLE exercises ADD COLUMN secondary_muscle_groups TEXT;",
          );
        } catch (_) {}
      },
    );
  }

  // --- Exercises Queries ---
  Future<List<ExerciseData>> getAllExercises() => select(exercises).get();
  Stream<List<ExerciseData>> watchAllExercises() => select(exercises).watch();

  Stream<List<ExerciseData>> watchExercisesByMuscleGroup(String muscleGroup) {
    if (muscleGroup.toLowerCase() == 'all') {
      return watchAllExercises();
    }
    return (select(
      exercises,
    )..where((t) => t.muscleGroup.equals(muscleGroup))).watch();
  }

  Future<int> insertExercise(ExercisesCompanion exercise) =>
      into(exercises).insert(exercise);
  Future<bool> updateExercise(ExerciseData exercise) =>
      update(exercises).replace(exercise);
  Future<int> deleteExercise(int id) =>
      (delete(exercises)..where((t) => t.id.equals(id))).go();

  // --- Workouts Queries ---
  Future<List<WorkoutData>> getAllWorkouts() =>
      (select(workouts)..orderBy([(t) => OrderingTerm.desc(t.date)])).get();
  Stream<List<WorkoutData>> watchAllWorkouts() =>
      (select(workouts)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

  Future<int> insertWorkout(WorkoutsCompanion workout) =>
      into(workouts).insert(workout);
  Future<bool> updateWorkout(WorkoutData workout) =>
      update(workouts).replace(workout);
  Future<int> deleteWorkout(int id) =>
      (delete(workouts)..where((t) => t.id.equals(id))).go();

  // --- Workout Exercises Queries ---
  Future<int> insertWorkoutExercise(WorkoutExercisesCompanion entry) =>
      into(workoutExercises).insert(entry);
  Stream<List<WorkoutExerciseData>> watchWorkoutExercises(int workoutId) {
    return (select(
      workoutExercises,
    )..where((t) => t.workoutId.equals(workoutId))).watch();
  }

  // --- Set Entries Queries ---
  Future<int> insertSetEntry(SetEntriesCompanion set) =>
      into(setEntries).insert(set);
  Stream<List<SetEntryData>> watchSetEntries(int workoutExerciseId) {
    return (select(
      setEntries,
    )..where((t) => t.workoutExerciseId.equals(workoutExerciseId))).watch();
  }

  Future<List<SetEntryData>> getPreviousSetsForExercise(int exerciseId) async {
    final weQuery = select(workoutExercises)
      ..where((t) => t.exerciseId.equals(exerciseId))
      ..orderBy([(t) => OrderingTerm.desc(t.id)]);
    final weList = await weQuery.get();
    if (weList.isEmpty) return [];

    final latestWE = weList.first;
    return (select(setEntries)
          ..where((t) => t.workoutExerciseId.equals(latestWE.id))
          ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
        .get();
  }

  Stream<List<ExerciseProgressPoint>> watchExerciseProgressHistory(
    int exerciseId,
  ) {
    final query = (select(workoutExercises)
      ..where((t) => t.exerciseId.equals(exerciseId)));
    return query.watch().asyncMap((weList) async {
      final List<ExerciseProgressPoint> points = [];
      for (final we in weList) {
        final workout = await (select(
          workouts,
        )..where((t) => t.id.equals(we.workoutId))).getSingleOrNull();
        if (workout == null) continue;

        final sets = await (select(
          setEntries,
        )..where((t) => t.workoutExerciseId.equals(we.id))).get();
        if (sets.isEmpty) continue;

        double maxWeight = 0;
        double max1RM = 0;
        double totalVolume = 0;

        for (final s in sets) {
          if (s.weight > maxWeight) maxWeight = s.weight;
          final e1rm = s.weight * (1 + s.reps / 30.0);
          if (e1rm > max1RM) max1RM = e1rm;
          if (s.type != 'warmup') {
            totalVolume += (s.weight * s.reps);
          }
        }

        points.add(
          ExerciseProgressPoint(
            date: workout.date,
            maxWeight: maxWeight,
            estimated1RM: max1RM,
            totalVolume: totalVolume,
          ),
        );
      }
      points.sort((a, b) => a.date.compareTo(b.date));
      return points;
    });
  }

  Stream<double> watchTotalVolume() {
    return select(setEntries).watch().map((sets) {
      double total = 0;
      for (final s in sets) {
        if (s.type != 'warmup') {
          total += (s.weight * s.reps);
        }
      }
      return total;
    });
  }

  Stream<List<WorkoutExerciseDetail>> watchWorkoutDetails(int workoutId) {
    final query = select(workoutExercises)
      ..where((t) => t.workoutId.equals(workoutId))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);

    return query.watch().asyncMap((workoutExList) async {
      final List<WorkoutExerciseDetail> details = [];
      for (final we in workoutExList) {
        final exercise = await (select(
          exercises,
        )..where((t) => t.id.equals(we.exerciseId))).getSingleOrNull();
        final sets =
            await (select(setEntries)
                  ..where((t) => t.workoutExerciseId.equals(we.id))
                  ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
                .get();

        if (exercise != null) {
          details.add(
            WorkoutExerciseDetail(
              workoutExercise: we,
              exercise: exercise,
              sets: sets,
            ),
          );
        }
      }
      return details;
    });
  }

  // --- Routines Queries ---
  Stream<List<RoutineData>> watchAllRoutines() =>
      (select(routines)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  Future<List<RoutineData>> getAllRoutines() =>
      (select(routines)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<int> insertRoutine(RoutinesCompanion routine) =>
      into(routines).insert(routine);
  Future<bool> updateRoutine(RoutineData routine) =>
      update(routines).replace(routine);
  Future<int> deleteRoutine(int id) =>
      (delete(routines)..where((t) => t.id.equals(id))).go();

  Future<int> insertRoutineExercise(RoutineExercisesCompanion re) =>
      into(routineExercises).insert(re);

  Future<void> updateRoutineWithExercises(
    int routineId,
    String name,
    String? description,
    List<RoutineExercisesCompanion> exercisesList,
  ) async {
    await (update(routines)..where((t) => t.id.equals(routineId))).write(
      RoutinesCompanion(name: Value(name), description: Value(description)),
    );
    await (delete(
      routineExercises,
    )..where((t) => t.routineId.equals(routineId))).go();
    for (final re in exercisesList) {
      await into(routineExercises).insert(re);
    }
  }

  Stream<List<RoutineDetail>> watchRoutineDetails(int routineId) {
    final query = select(routineExercises)
      ..where((t) => t.routineId.equals(routineId))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);

    return query.watch().asyncMap((reList) async {
      final List<RoutineDetail> details = [];
      for (final re in reList) {
        final exercise = await (select(
          exercises,
        )..where((t) => t.id.equals(re.exerciseId))).getSingleOrNull();
        if (exercise != null) {
          details.add(RoutineDetail(routineExercise: re, exercise: exercise));
        }
      }
      return details;
    });
  }
}

class WorkoutExerciseDetail {
  final WorkoutExerciseData workoutExercise;
  final ExerciseData exercise;
  final List<SetEntryData> sets;

  WorkoutExerciseDetail({
    required this.workoutExercise,
    required this.exercise,
    required this.sets,
  });
}

class RoutineDetail {
  final RoutineExerciseData routineExercise;
  final ExerciseData exercise;

  RoutineDetail({required this.routineExercise, required this.exercise});
}

class ExerciseProgressPoint {
  final DateTime date;
  final double maxWeight;
  final double estimated1RM;
  final double totalVolume;

  ExerciseProgressPoint({
    required this.date,
    required this.maxWeight,
    required this.estimated1RM,
    required this.totalVolume,
  });
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'thews_workout.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
