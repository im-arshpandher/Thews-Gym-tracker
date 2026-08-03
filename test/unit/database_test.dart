import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thews/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Exercise insertion and retrieval', () async {
    await db.insertExercise(
      ExercisesCompanion.insert(
        name: 'Barbell Bench Press',
        muscleGroup: 'Chest',
      ),
    );
    final exercises = await db.getAllExercises();
    expect(exercises.isNotEmpty, true);
    expect(exercises.any((e) => e.name == 'Barbell Bench Press'), true);
  });

  test('Workout and Set Entries logging with Set Types', () async {
    final workoutId = await db.insertWorkout(
      WorkoutsCompanion.insert(
        date: Value(DateTime.now()),
        notes: const Value('Test Bench Session'),
        durationSeconds: const Value(3600),
      ),
    );

    final workoutExId = await db.insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(workoutId: workoutId, exerciseId: 1),
    );

    // Warmup set
    await db.insertSetEntry(
      SetEntriesCompanion.insert(
        workoutExerciseId: workoutExId,
        setNumber: 1,
        weight: 40.0,
        reps: 10,
        unit: const Value('kg'),
        type: const Value('warmup'),
      ),
    );

    // Working set 1
    await db.insertSetEntry(
      SetEntriesCompanion.insert(
        workoutExerciseId: workoutExId,
        setNumber: 2,
        weight: 80.0,
        reps: 8,
        unit: const Value('kg'),
        type: const Value('normal'),
      ),
    );

    // Working set 2
    await db.insertSetEntry(
      SetEntriesCompanion.insert(
        workoutExerciseId: workoutExId,
        setNumber: 3,
        weight: 80.0,
        reps: 8,
        unit: const Value('kg'),
        type: const Value('normal'),
      ),
    );

    final details = await db.watchWorkoutDetails(workoutId).first;
    expect(details.length, 1);
    expect(details.first.sets.length, 3);

    // Verify watchTotalVolume excludes warmup sets: (80*8) + (80*8) = 1280 (ignoring 40*10 = 400 warmup)
    final totalVol = await db.watchTotalVolume().first;
    expect(totalVol, 1280.0);
  });

  test('Previous session sets retrieval', () async {
    final workoutId = await db.insertWorkout(
      WorkoutsCompanion.insert(
        date: Value(DateTime.now().subtract(const Duration(days: 1))),
        notes: const Value('Yesterday Session'),
      ),
    );

    final workoutExId = await db.insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(workoutId: workoutId, exerciseId: 4),
    );

    await db.insertSetEntry(
      SetEntriesCompanion.insert(
        workoutExerciseId: workoutExId,
        setNumber: 1,
        weight: 100.0,
        reps: 5,
      ),
    );

    final previousSets = await db.getPreviousSetsForExercise(4);
    expect(previousSets.length, 1);
    expect(previousSets.first.weight, 100.0);
    expect(previousSets.first.reps, 5);
  });

  test('Routines creation and details stream', () async {
    await db.insertExercise(
      ExercisesCompanion.insert(
        name: 'Barbell Bench Press',
        muscleGroup: 'Chest',
      ),
    );

    final routineId = await db.insertRoutine(
      RoutinesCompanion.insert(
        name: 'Custom Upper Body',
        description: const Value('Custom upper split'),
      ),
    );

    await db.insertRoutineExercise(
      RoutineExercisesCompanion.insert(
        routineId: routineId,
        exerciseId: 1,
        targetSets: const Value(4),
        targetReps: const Value(8),
      ),
    );

    final details = await db.watchRoutineDetails(routineId).first;
    expect(details.length, 1);
    expect(details.first.exercise.name, 'Barbell Bench Press');
    expect(details.first.routineExercise.targetSets, 4);
  });
}
