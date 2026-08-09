import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../utils/volume_calculator.dart';
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
    RunActivities,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await seedDefaultExercises();
        await seedDefaultRoutines();
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
        if (from < 6) {
          await m.createTable(runActivities);
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
        try {
          await customStatement(
            "ALTER TABLE exercises ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0;",
          );
        } catch (_) {}
        try {
          await customStatement(
            "CREATE TABLE IF NOT EXISTS run_activities (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, workout_id INTEGER REFERENCES workouts (id) ON DELETE CASCADE, activity_type TEXT NOT NULL DEFAULT 'run', start_time INTEGER NOT NULL DEFAULT (UNIXEPOCH()), distance_meters REAL NOT NULL DEFAULT 0.0, duration_seconds INTEGER NOT NULL DEFAULT 0, avg_pace_seconds_per_km REAL NOT NULL DEFAULT 0.0, elevation_gain_meters REAL NOT NULL DEFAULT 0.0, gpx_data TEXT);",
          );
        } catch (_) {}
      },
    );
  }

  // --- Exercises Queries ---
  Future<List<ExerciseData>> getAllExercises() =>
      (select(exercises)..where((t) => t.isDeleted.equals(false))).get();

  Stream<List<ExerciseData>> watchAllExercises() =>
      (select(exercises)..where((t) => t.isDeleted.equals(false))).watch();

  Stream<List<ExerciseData>> watchExercisesByMuscleGroup(String muscleGroup) {
    if (muscleGroup.toLowerCase() == 'all') {
      return watchAllExercises();
    }
    return (select(
      exercises,
    )..where(
      (t) => t.muscleGroup.equals(muscleGroup) & t.isDeleted.equals(false),
    )).watch();
  }

  Future<int> insertExercise(ExercisesCompanion exercise) =>
      into(exercises).insert(exercise);
  Future<bool> updateExercise(ExerciseData exercise) =>
      update(exercises).replace(exercise);
  Future<int> deleteExercise(int id) =>
      (update(exercises)..where((t) => t.id.equals(id))).write(
        const ExercisesCompanion(isDeleted: Value(true)),
      );

  // --- Workouts Queries ---
  Future<List<WorkoutData>> getAllWorkouts() =>
      (select(workouts)..orderBy([(t) => OrderingTerm.desc(t.date)])).get();
  Stream<List<WorkoutData>> watchAllWorkouts() =>
      (select(workouts)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
  Stream<WorkoutData?> watchWorkoutById(int id) =>
      (select(workouts)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<int> insertWorkout(WorkoutsCompanion workout) =>
      into(workouts).insert(workout);
  Future<bool> updateWorkout(WorkoutData workout) =>
      update(workouts).replace(workout);
  Future<int> updateWorkoutNotes(int id, String notes) =>
      (update(workouts)..where((t) => t.id.equals(id))).write(
        WorkoutsCompanion(notes: Value(notes)),
      );
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
          totalVolume += VolumeCalculator.calculateSetVolume(
            weight: s.weight,
            reps: s.reps,
            type: s.type,
            unit: s.unit,
          );
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
      try {
        return VolumeCalculator.calculateTotalVolume(sets);
      } catch (_) {
        return 0.0;
      }
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

  // --- Run Activities Queries ---
  Future<int> insertRunActivity(RunActivitiesCompanion entry) =>
      into(runActivities).insert(entry);

  Future<List<RunActivityData>> getAllRunActivities() =>
      (select(runActivities)..orderBy([(t) => OrderingTerm.desc(t.startTime)])).get();

  Stream<List<RunActivityData>> watchAllRunActivities() =>
      (select(runActivities)..orderBy([(t) => OrderingTerm.desc(t.startTime)])).watch();

  Stream<RunActivityData?> watchRunActivityById(int id) =>
      (select(runActivities)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<int> deleteRunActivity(int id) =>
      (delete(runActivities)..where((t) => t.id.equals(id))).go();

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

  /// Deletes all existing workout history and populates fresh tuned sessions for this week.
  Future<void> clearAndSeedThisWeekWorkouts() async {
    await delete(setEntries).go();
    await delete(workoutExercises).go();
    await delete(workouts).go();

    final allEx = await getAllExercises();
    if (allEx.isEmpty) return;

    ExerciseData findEx(String name) {
      return allEx.firstWhere(
        (e) => e.name.toLowerCase() == name.toLowerCase(),
        orElse: () => allEx.first,
      );
    }

    final now = DateTime.now();

    // 1. Heavy Push Session (2 days ago)
    final pushWorkoutId = await insertWorkout(
      WorkoutsCompanion.insert(
        date: Value(now.subtract(const Duration(days: 2))),
        notes: const Value('Heavy Push Hypertrophy Session - Great bench press progress'),
        durationSeconds: const Value(3600),
      ),
    );

    final benchEx = findEx('Barbell Bench Press');
    final benchWeId = await insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(
        workoutId: pushWorkoutId,
        exerciseId: benchEx.id,
        sortOrder: const Value(0),
      ),
    );
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: benchWeId, setNumber: 1, weight: 60, reps: 12, type: const Value('warmup')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: benchWeId, setNumber: 2, weight: 85, reps: 10, type: const Value('normal')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: benchWeId, setNumber: 3, weight: 95, reps: 8, type: const Value('normal')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: benchWeId, setNumber: 4, weight: 105, reps: 6, type: const Value('normal')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: benchWeId, setNumber: 5, weight: 75, reps: 12, type: const Value('drop')));

    final ohpEx = findEx('Overhead Shoulder Press');
    final ohpWeId = await insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(
        workoutId: pushWorkoutId,
        exerciseId: ohpEx.id,
        sortOrder: const Value(1),
      ),
    );
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: ohpWeId, setNumber: 1, weight: 50, reps: 10, type: const Value('normal')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: ohpWeId, setNumber: 2, weight: 60, reps: 8, type: const Value('normal')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: ohpWeId, setNumber: 3, weight: 65, reps: 6, type: const Value('normal')));

    final tricepEx = findEx('Tricep Rope Pushdown');
    final tricepWeId = await insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(
        workoutId: pushWorkoutId,
        exerciseId: tricepEx.id,
        sortOrder: const Value(2),
      ),
    );
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: tricepWeId, setNumber: 1, weight: 30, reps: 12, type: const Value('normal')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: tricepWeId, setNumber: 2, weight: 35, reps: 10, type: const Value('normal')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: tricepWeId, setNumber: 3, weight: 40, reps: 8, type: const Value('failure')));

    // 2. Pull & Back Power Session (1 day ago)
    final pullWorkoutId = await insertWorkout(
      WorkoutsCompanion.insert(
        date: Value(now.subtract(const Duration(days: 1))),
        notes: const Value('Pull & Back Power Session - Deadlift volume'),
        durationSeconds: const Value(3300),
      ),
    );

    final deadliftEx = findEx('Conventional Deadlift');
    final deadliftWeId = await insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(
        workoutId: pullWorkoutId,
        exerciseId: deadliftEx.id,
        sortOrder: const Value(0),
      ),
    );
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: deadliftWeId, setNumber: 1, weight: 70, reps: 10, type: const Value('warmup')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: deadliftWeId, setNumber: 2, weight: 120, reps: 8, type: const Value('normal')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: deadliftWeId, setNumber: 3, weight: 140, reps: 5, type: const Value('normal')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: deadliftWeId, setNumber: 4, weight: 160, reps: 3, type: const Value('normal')));

    final latEx = findEx('Lat Pulldown');
    final latWeId = await insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(
        workoutId: pullWorkoutId,
        exerciseId: latEx.id,
        sortOrder: const Value(1),
      ),
    );
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: latWeId, setNumber: 1, weight: 65, reps: 12, type: const Value('normal')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: latWeId, setNumber: 2, weight: 75, reps: 10, type: const Value('normal')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: latWeId, setNumber: 3, weight: 85, reps: 8, type: const Value('normal')));

    final curlEx = findEx('Bicep Barbell Curl');
    final curlWeId = await insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(
        workoutId: pullWorkoutId,
        exerciseId: curlEx.id,
        sortOrder: const Value(2),
      ),
    );
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: curlWeId, setNumber: 1, weight: 30, reps: 12, type: const Value('normal')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: curlWeId, setNumber: 2, weight: 35, reps: 10, type: const Value('normal')));

    // 3. Legs & Lower Body (Today)
    final legWorkoutId = await insertWorkout(
      WorkoutsCompanion.insert(
        date: Value(now.subtract(const Duration(hours: 4))),
        notes: const Value('Legs & Quads Session - Squat volume PR'),
        durationSeconds: const Value(3900),
      ),
    );

    final squatEx = findEx('Barbell Squat');
    final squatWeId = await insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(
        workoutId: legWorkoutId,
        exerciseId: squatEx.id,
        sortOrder: const Value(0),
      ),
    );
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: squatWeId, setNumber: 1, weight: 60, reps: 10, type: const Value('warmup')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: squatWeId, setNumber: 2, weight: 100, reps: 10, type: const Value('normal')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: squatWeId, setNumber: 3, weight: 120, reps: 8, type: const Value('normal')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: squatWeId, setNumber: 4, weight: 130, reps: 6, type: const Value('normal')));

    final rdlEx = findEx('Romanian Deadlift');
    final rdlWeId = await insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(
        workoutId: legWorkoutId,
        exerciseId: rdlEx.id,
        sortOrder: const Value(1),
      ),
    );
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: rdlWeId, setNumber: 1, weight: 80, reps: 10, type: const Value('normal')));
    await insertSetEntry(SetEntriesCompanion.insert(workoutExerciseId: rdlWeId, setNumber: 2, weight: 100, reps: 8, type: const Value('normal')));

    // 4. Treadmill Run (Today)
    final cardioWorkoutId = await insertWorkout(
      WorkoutsCompanion.insert(
        date: Value(now.subtract(const Duration(hours: 1))),
        notes: const Value('Endurance & Speed Interval Treadmill Run'),
        durationSeconds: const Value(1800),
      ),
    );

    final runEx = findEx('Treadmill Run');
    final runWeId = await insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(
        workoutId: cardioWorkoutId,
        exerciseId: runEx.id,
        sortOrder: const Value(0),
      ),
    );
    await insertSetEntry(SetEntriesCompanion.insert(
      workoutExerciseId: runWeId,
      setNumber: 1,
      weight: 0,
      reps: 0,
      distance: const Value(2.5),
      durationSeconds: const Value(720),
      incline: const Value(1.0),
      speed: const Value(11.5),
    ));
    await insertSetEntry(SetEntriesCompanion.insert(
      workoutExerciseId: runWeId,
      setNumber: 2,
      weight: 0,
      reps: 0,
      distance: const Value(2.5),
      durationSeconds: const Value(690),
      incline: const Value(2.0),
      speed: const Value(13.0),
    ));
  }

  /// Clears all existing exercises, routines, and workout logs, and re-seeds the fresh exercise library.
  Future<void> resetAndSeedExerciseLibrary() async {
    await transaction(() async {
      await delete(setEntries).go();
      await delete(workoutExercises).go();
      await delete(routineExercises).go();
      await delete(routines).go();
      await delete(workouts).go();
      await delete(exercises).go();

      await seedDefaultExercises();
      await seedDefaultRoutines();
    });
  }

  /// Seeds default exercises with updated configs across all muscle groups and metric types.
  Future<void> seedDefaultExercises() async {
    await batch((b) {
      b.insertAll(exercises, [
        // CHEST
        ExercisesCompanion.insert(
          name: 'Barbell Bench Press',
          muscleGroup: 'Chest',
          secondaryMuscleGroups: const Value('Shoulders, Arms'),
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Incline Dumbbell Press',
          muscleGroup: 'Chest',
          secondaryMuscleGroups: const Value('Shoulders, Arms'),
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Chest Fly',
          muscleGroup: 'Chest',
          secondaryMuscleGroups: const Value('Shoulders'),
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Push-ups',
          muscleGroup: 'Chest',
          secondaryMuscleGroups: const Value('Arms, Core'),
          category: const Value('reps_only'),
          enabledMetrics: const Value('reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Bodyweight Dips',
          muscleGroup: 'Chest',
          secondaryMuscleGroups: const Value('Arms, Shoulders'),
          category: const Value('reps_only'),
          enabledMetrics: const Value('reps'),
        ),

        // BACK
        ExercisesCompanion.insert(
          name: 'Conventional Deadlift',
          muscleGroup: 'Back',
          secondaryMuscleGroups: const Value('Legs, Core'),
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Lat Pulldown',
          muscleGroup: 'Back',
          secondaryMuscleGroups: const Value('Arms'),
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Bent Over Barbell Row',
          muscleGroup: 'Back',
          secondaryMuscleGroups: const Value('Arms'),
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Single-Arm Dumbbell Row',
          muscleGroup: 'Back',
          secondaryMuscleGroups: const Value('Arms'),
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Pull-ups',
          muscleGroup: 'Back',
          secondaryMuscleGroups: const Value('Arms'),
          category: const Value('reps_only'),
          enabledMetrics: const Value('reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Chin-ups',
          muscleGroup: 'Back',
          secondaryMuscleGroups: const Value('Arms'),
          category: const Value('reps_only'),
          enabledMetrics: const Value('reps'),
        ),

        // SHOULDERS
        ExercisesCompanion.insert(
          name: 'Overhead Shoulder Press',
          muscleGroup: 'Shoulders',
          secondaryMuscleGroups: const Value('Arms, Core'),
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Dumbbell Lateral Raise',
          muscleGroup: 'Shoulders',
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Face Pull',
          muscleGroup: 'Shoulders',
          secondaryMuscleGroups: const Value('Back'),
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Rear Delt Fly',
          muscleGroup: 'Shoulders',
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),

        // LEGS
        ExercisesCompanion.insert(
          name: 'Barbell Back Squat',
          muscleGroup: 'Legs',
          secondaryMuscleGroups: const Value('Core'),
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Leg Press',
          muscleGroup: 'Legs',
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Romanian Deadlift',
          muscleGroup: 'Legs',
          secondaryMuscleGroups: const Value('Back'),
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Leg Extension',
          muscleGroup: 'Legs',
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Seated Leg Curl',
          muscleGroup: 'Legs',
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Standing Calf Raise',
          muscleGroup: 'Legs',
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),

        // ARMS
        ExercisesCompanion.insert(
          name: 'Bicep Barbell Curl',
          muscleGroup: 'Arms',
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Hammer Curls',
          muscleGroup: 'Arms',
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Tricep Rope Pushdown',
          muscleGroup: 'Arms',
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Skull Crushers',
          muscleGroup: 'Arms',
          category: const Value('weight_reps'),
          enabledMetrics: const Value('weight,reps'),
        ),

        // CORE
        ExercisesCompanion.insert(
          name: 'Hanging Leg Raise',
          muscleGroup: 'Core',
          category: const Value('reps_only'),
          enabledMetrics: const Value('reps'),
        ),
        ExercisesCompanion.insert(
          name: 'Ab Wheel Rollout',
          muscleGroup: 'Core',
          secondaryMuscleGroups: const Value('Arms'),
          category: const Value('duration_time'),
          enabledMetrics: const Value('time'),
        ),
        ExercisesCompanion.insert(
          name: 'Plank',
          muscleGroup: 'Core',
          category: const Value('duration_time'),
          enabledMetrics: const Value('time'),
        ),
        ExercisesCompanion.insert(
          name: 'Side Plank',
          muscleGroup: 'Core',
          category: const Value('duration_time'),
          enabledMetrics: const Value('time'),
        ),

        // CARDIO & ENDURANCE
        ExercisesCompanion.insert(
          name: 'Treadmill Run',
          muscleGroup: 'Cardio',
          secondaryMuscleGroups: const Value('Legs'),
          category: const Value('cardio_distance'),
          enabledMetrics: const Value('distance,time,incline,speed'),
        ),
        ExercisesCompanion.insert(
          name: 'Outdoor Running',
          muscleGroup: 'Cardio',
          secondaryMuscleGroups: const Value('Legs'),
          category: const Value('cardio_distance'),
          enabledMetrics: const Value('distance,time'),
        ),
        ExercisesCompanion.insert(
          name: 'Rowing Machine',
          muscleGroup: 'Cardio',
          secondaryMuscleGroups: const Value('Back, Arms'),
          category: const Value('cardio_distance'),
          enabledMetrics: const Value('distance,time'),
        ),
        ExercisesCompanion.insert(
          name: 'Stationary Cycling',
          muscleGroup: 'Cardio',
          secondaryMuscleGroups: const Value('Legs'),
          category: const Value('cardio_distance'),
          enabledMetrics: const Value('distance,time,speed'),
        ),
      ]);
    });
  }

  /// Seeds default starter routine templates matching the newly configured exercise library.
  Future<void> seedDefaultRoutines() async {
    final allEx = await getAllExercises();
    if (allEx.isEmpty) return;

    ExerciseData findEx(String name) {
      return allEx.firstWhere(
        (e) => e.name.toLowerCase() == name.toLowerCase(),
        orElse: () => allEx.first,
      );
    }

    final pushId = await into(routines).insert(
      RoutinesCompanion.insert(
        name: 'Push Hypertrophy',
        description: const Value('Chest, Shoulders & Triceps focus routine'),
      ),
    );
    await into(routineExercises).insert(
      RoutineExercisesCompanion.insert(
        routineId: pushId,
        exerciseId: findEx('Barbell Bench Press').id,
        targetSets: const Value(3),
        targetReps: const Value(10),
        sortOrder: const Value(0),
      ),
    );
    await into(routineExercises).insert(
      RoutineExercisesCompanion.insert(
        routineId: pushId,
        exerciseId: findEx('Incline Dumbbell Press').id,
        targetSets: const Value(3),
        targetReps: const Value(12),
        sortOrder: const Value(1),
      ),
    );
    await into(routineExercises).insert(
      RoutineExercisesCompanion.insert(
        routineId: pushId,
        exerciseId: findEx('Overhead Shoulder Press').id,
        targetSets: const Value(3),
        targetReps: const Value(10),
        sortOrder: const Value(2),
      ),
    );
    await into(routineExercises).insert(
      RoutineExercisesCompanion.insert(
        routineId: pushId,
        exerciseId: findEx('Tricep Rope Pushdown').id,
        targetSets: const Value(3),
        targetReps: const Value(12),
        sortOrder: const Value(3),
      ),
    );

    final pullId = await into(routines).insert(
      RoutinesCompanion.insert(
        name: 'Pull Power',
        description: const Value('Back & Biceps workout routine'),
      ),
    );
    await into(routineExercises).insert(
      RoutineExercisesCompanion.insert(
        routineId: pullId,
        exerciseId: findEx('Conventional Deadlift').id,
        targetSets: const Value(3),
        targetReps: const Value(8),
        sortOrder: const Value(0),
      ),
    );
    await into(routineExercises).insert(
      RoutineExercisesCompanion.insert(
        routineId: pullId,
        exerciseId: findEx('Lat Pulldown').id,
        targetSets: const Value(3),
        targetReps: const Value(10),
        sortOrder: const Value(1),
      ),
    );
    await into(routineExercises).insert(
      RoutineExercisesCompanion.insert(
        routineId: pullId,
        exerciseId: findEx('Bicep Barbell Curl').id,
        targetSets: const Value(3),
        targetReps: const Value(12),
        sortOrder: const Value(2),
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'thews_workout.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
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

