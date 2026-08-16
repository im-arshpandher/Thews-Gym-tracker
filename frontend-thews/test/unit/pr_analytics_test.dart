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

  test(
    'Exercise progress history calculates Max Weight, 1RM, and Volume PRs correctly',
    () async {
      final workoutId1 = await db.insertWorkout(
        WorkoutsCompanion.insert(
          date: Value(DateTime.now().subtract(const Duration(days: 2))),
          notes: const Value('Session 1'),
        ),
      );

      final we1 = await db.insertWorkoutExercise(
        WorkoutExercisesCompanion.insert(workoutId: workoutId1, exerciseId: 1),
      );

      await db.insertSetEntry(
        SetEntriesCompanion.insert(
          workoutExerciseId: we1,
          setNumber: 1,
          weight: 80.0,
          reps: 10,
          type: const Value('normal'),
        ),
      );

      final workoutId2 = await db.insertWorkout(
        WorkoutsCompanion.insert(
          date: Value(DateTime.now()),
          notes: const Value('Session 2 PR'),
        ),
      );

      final we2 = await db.insertWorkoutExercise(
        WorkoutExercisesCompanion.insert(workoutId: workoutId2, exerciseId: 1),
      );

      await db.insertSetEntry(
        SetEntriesCompanion.insert(
          workoutExerciseId: we2,
          setNumber: 1,
          weight: 100.0,
          reps: 5,
          type: const Value('normal'),
        ),
      );

      final points = await db.watchExerciseProgressHistory(1).first;
      expect(points.length, 2);

      final firstPoint = points[0];
      expect(firstPoint.maxWeight, 80.0);
      // Epley: 80 * (1 + 10/30) = 80 * 1.3333 = 106.666
      expect(firstPoint.estimated1RM, closeTo(106.66, 0.1));
      expect(firstPoint.totalVolume, 800.0);

      final secondPoint = points[1];
      expect(secondPoint.maxWeight, 100.0);
      // Epley: 100 * (1 + 5/30) = 100 * 1.1666 = 116.666
      expect(secondPoint.estimated1RM, closeTo(116.66, 0.1));
      expect(secondPoint.totalVolume, 500.0);
    },
  );
}
