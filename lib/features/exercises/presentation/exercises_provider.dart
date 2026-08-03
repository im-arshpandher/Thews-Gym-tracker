import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// ponytail: yagni - Direct AppDatabase access; upgrade path: restore repository if backend sync added.
final selectedMuscleGroupFilterProvider = StateProvider<String>((ref) => 'All');

final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredExercisesProvider = StreamProvider<List<ExerciseData>>((ref) {
  final db = ref.watch(databaseProvider);
  final selectedGroup = ref.watch(selectedMuscleGroupFilterProvider);
  final searchQuery = ref.watch(searchQueryProvider).trim().toLowerCase();

  return db.watchExercisesByMuscleGroup(selectedGroup).map((list) {
    if (searchQuery.isEmpty) return list;
    return list
        .where((item) => item.name.toLowerCase().contains(searchQuery))
        .toList();
  });
});

final allExercisesProvider = StreamProvider<List<ExerciseData>>((ref) {
  return ref.watch(databaseProvider).watchExercisesByMuscleGroup('All');
});

final exerciseProgressProvider =
    StreamProvider.family<List<ExerciseProgressPoint>, int>((ref, exerciseId) {
      return ref
          .watch(databaseProvider)
          .watchExerciseProgressHistory(exerciseId);
    });
