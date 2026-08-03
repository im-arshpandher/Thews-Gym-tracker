import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/app_database.dart';

class BackupExportService {
  final AppDatabase db;

  BackupExportService(this.db);

  /// Generates a complete JSON backup representation of all local database tables.
  Future<String> exportBackupJson() async {
    final exercises = await db.getAllExercises();
    final workouts = await db.getAllWorkouts();
    final routines = await db.getAllRoutines();

    final List<Map<String, dynamic>> workoutDataList = [];
    for (final w in workouts) {
      final details = await db.watchWorkoutDetails(w.id).first;
      workoutDataList.add({
        'id': w.id,
        'date': w.date.toIso8601String(),
        'notes': w.notes,
        'durationSeconds': w.durationSeconds,
        'exercises': details.map((d) {
          return {
            'exerciseId': d.exercise.id,
            'exerciseName': d.exercise.name,
            'muscleGroup': d.exercise.muscleGroup,
            'sets': d.sets.map((s) {
              return {
                'setNumber': s.setNumber,
                'weight': s.weight,
                'reps': s.reps,
                'unit': s.unit,
                'type': s.type,
              };
            }).toList(),
          };
        }).toList(),
      });
    }

    final backupMap = {
      'version': 1,
      'app': 'Thews Gym Tracker',
      'exportedAt': DateTime.now().toIso8601String(),
      'exercises': exercises
          .map(
            (e) => {
              'id': e.id,
              'name': e.name,
              'muscleGroup': e.muscleGroup,
              'isCustom': e.isCustom,
              'videoUrl': e.videoUrl,
            },
          )
          .toList(),
      'routines': routines
          .map(
            (r) => {'id': r.id, 'name': r.name, 'description': r.description},
          )
          .toList(),
      'workouts': workoutDataList,
    };

    return const JsonEncoder.withIndent('  ').convert(backupMap);
  }

  /// Restores data from a backup JSON string.
  Future<int> restoreBackupJson(String jsonString) async {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final workoutsList = data['workouts'] as List? ?? [];

    int restoredWorkouts = 0;
    for (final w in workoutsList) {
      final date = DateTime.tryParse(w['date'] ?? '') ?? DateTime.now();
      final notes = w['notes'] as String?;
      final duration = (w['durationSeconds'] as num?)?.toInt() ?? 0;

      final workoutId = await db.insertWorkout(
        WorkoutsCompanion.insert(
          date: Value(date),
          notes: Value(notes),
          durationSeconds: Value(duration),
        ),
      );

      final exList = w['exercises'] as List? ?? [];
      for (int i = 0; i < exList.length; i++) {
        final ex = exList[i];
        final exerciseId = (ex['exerciseId'] as num?)?.toInt() ?? 1;

        final workoutExId = await db.insertWorkoutExercise(
          WorkoutExercisesCompanion.insert(
            workoutId: workoutId,
            exerciseId: exerciseId,
            sortOrder: Value(i),
          ),
        );

        final setsList = ex['sets'] as List? ?? [];
        for (final s in setsList) {
          await db.insertSetEntry(
            SetEntriesCompanion.insert(
              workoutExerciseId: workoutExId,
              setNumber: (s['setNumber'] as num?)?.toInt() ?? 1,
              weight: (s['weight'] as num?)?.toDouble() ?? 0.0,
              reps: (s['reps'] as num?)?.toInt() ?? 0,
              unit: Value((s['unit'] as String?) ?? 'kg'),
              type: Value((s['type'] as String?) ?? 'normal'),
            ),
          );
        }
      }
      restoredWorkouts++;
    }
    return restoredWorkouts;
  }

  /// Exports past workout history as a CSV formatted string.
  Future<String> exportWorkoutsCsv() async {
    final workouts = await db.getAllWorkouts();
    final StringBuffer csv = StringBuffer();
    csv.writeln(
      'Date,Workout Title,Exercise Name,Muscle Group,Set Number,Set Type,Weight,Reps,Unit',
    );

    for (final w in workouts) {
      final details = await db.watchWorkoutDetails(w.id).first;
      final dateStr = w.date.toIso8601String().split('T').first;
      final title = (w.notes ?? 'Workout').replaceAll(',', ' ');

      for (final d in details) {
        final exName = d.exercise.name.replaceAll(',', ' ');
        for (final s in d.sets) {
          csv.writeln(
            '$dateStr,$title,$exName,${d.exercise.muscleGroup},${s.setNumber},${s.type},${s.weight},${s.reps},${s.unit}',
          );
        }
      }
    }

    return csv.toString();
  }

  /// Shares JSON Backup file via native share sheet.
  Future<void> shareBackupJson() async {
    final jsonStr = await exportBackupJson();
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/thews_backup_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(jsonStr);
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Thews Gym Tracker Database Backup (JSON)');
  }

  /// Shares CSV Workout Log file via native share sheet.
  Future<void> shareWorkoutsCsv() async {
    final csvStr = await exportWorkoutsCsv();
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/thews_workout_history_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csvStr);
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Thews Gym Workout History Export (CSV)');
  }

  /// Restores database by picking a JSON backup file using FilePicker.
  Future<int?> importBackupFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.single.path;
      if (path != null) {
        final file = File(path);
        final content = await file.readAsString();
        return await restoreBackupJson(content);
      }
    }
    return null;
  }
}
