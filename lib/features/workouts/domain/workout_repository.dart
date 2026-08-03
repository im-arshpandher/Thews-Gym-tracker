import '../../../core/database/app_database.dart';

abstract class WorkoutRepository {
  Stream<List<WorkoutData>> watchAllWorkouts();
  Future<List<WorkoutData>> getAllWorkouts();
  Future<int> saveWorkout({
    required String title,
    required int durationSeconds,
    required List<WorkoutExerciseDetail> details,
  });
  Future<int> deleteWorkout(int id);
  Future<String> exportBackup();
  Future<int> importBackup(String jsonContent);
}

class LocalWorkoutRepositoryImpl implements WorkoutRepository {
  final AppDatabase db;

  LocalWorkoutRepositoryImpl(this.db);

  @override
  Stream<List<WorkoutData>> watchAllWorkouts() => db.watchAllWorkouts();

  @override
  Future<List<WorkoutData>> getAllWorkouts() => db.getAllWorkouts();

  @override
  Future<int> saveWorkout({
    required String title,
    required int durationSeconds,
    required List<WorkoutExerciseDetail> details,
  }) async {
    // Local SQLite database insertion logic
    return 0;
  }

  @override
  Future<int> deleteWorkout(int id) => db.deleteWorkout(id);

  @override
  Future<String> exportBackup() async {
    return '';
  }

  @override
  Future<int> importBackup(String jsonContent) async {
    return 0;
  }
}
