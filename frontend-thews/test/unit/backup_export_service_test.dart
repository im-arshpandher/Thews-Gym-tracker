import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thews/core/database/app_database.dart';
import 'package:thews/core/utils/backup_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late BackupExportService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = BackupExportService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Backup JSON export and restore flow', () async {
    final workoutId = await db.insertWorkout(
      WorkoutsCompanion.insert(
        notes: const Value('Leg Day Session'),
        durationSeconds: const Value(2400),
      ),
    );

    final workoutExId = await db.insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(workoutId: workoutId, exerciseId: 1),
    );

    await db.insertSetEntry(
      SetEntriesCompanion.insert(
        workoutExerciseId: workoutExId,
        setNumber: 1,
        weight: 100.0,
        reps: 10,
        unit: const Value('kg'),
      ),
    );

    final jsonStr = await service.exportBackupJson();
    expect(jsonStr.contains('Leg Day Session'), true);
    expect(jsonStr.contains('100.0'), true);

    // Test restoration into fresh DB
    final newDb = AppDatabase.forTesting(NativeDatabase.memory());
    final newService = BackupExportService(newDb);

    final restoredCount = await newService.restoreBackupJson(jsonStr);
    expect(restoredCount, 1);

    final workouts = await newDb.getAllWorkouts();
    expect(workouts.length, 1);
    expect(workouts.first.notes, 'Leg Day Session');

    await newDb.close();
  });

  test('Workouts CSV export formatting', () async {
    final workoutId = await db.insertWorkout(
      WorkoutsCompanion.insert(notes: const Value('Chest Workout')),
    );

    final workoutExId = await db.insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(workoutId: workoutId, exerciseId: 1),
    );

    await db.insertSetEntry(
      SetEntriesCompanion.insert(
        workoutExerciseId: workoutExId,
        setNumber: 1,
        weight: 80.0,
        reps: 8,
        unit: const Value('kg'),
      ),
    );

    final csvStr = await service.exportWorkoutsCsv();
    expect(csvStr.contains('Date,Workout Title,Exercise Name'), true);
    expect(csvStr.contains('Chest Workout'), true);
    expect(csvStr.contains('80.0'), true);
  });
}
