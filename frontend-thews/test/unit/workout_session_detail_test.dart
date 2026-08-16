import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thews/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('watchWorkoutById and updateWorkoutNotes flow', () async {
    final workoutId = await database.insertWorkout(
      WorkoutsCompanion(
        date: Value(DateTime.now()),
        notes: const Value('Initial session notes'),
        durationSeconds: const Value(1800),
      ),
    );

    final workout = await database.watchWorkoutById(workoutId).first;
    expect(workout, isNotNull);
    expect(workout!.notes, 'Initial session notes');
    expect(workout.durationSeconds, 1800);

    // Update notes
    await database.updateWorkoutNotes(workoutId, 'Updated leg day notes');

    final updatedWorkout = await database.watchWorkoutById(workoutId).first;
    expect(updatedWorkout, isNotNull);
    expect(updatedWorkout!.notes, 'Updated leg day notes');
  });

  test('watchWorkoutDetails queries joined workout exercises and set entries', () async {
    final exerciseId = await database.insertExercise(
      const ExercisesCompanion(
        name: Value('Incline Bench Press'),
        muscleGroup: Value('Chest'),
      ),
    );

    final workoutId = await database.insertWorkout(
      WorkoutsCompanion(
        date: Value(DateTime.now()),
        notes: const Value('Chest Workout'),
        durationSeconds: const Value(2700),
      ),
    );

    final weId = await database.insertWorkoutExercise(
      WorkoutExercisesCompanion(
        workoutId: Value(workoutId),
        exerciseId: Value(exerciseId),
        sortOrder: const Value(0),
      ),
    );

    await database.insertSetEntry(
      SetEntriesCompanion(
        workoutExerciseId: Value(weId),
        setNumber: const Value(1),
        weight: const Value(80.0),
        reps: const Value(10),
        unit: const Value('kg'),
        type: const Value('normal'),
      ),
    );

    final details = await database.watchWorkoutDetails(workoutId).first;
    expect(details.length, 1);
    expect(details.first.exercise.name, 'Incline Bench Press');
    expect(details.first.sets.length, 1);
    expect(details.first.sets.first.weight, 80.0);
  });
}
