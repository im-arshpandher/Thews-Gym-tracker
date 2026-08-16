import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

final allRoutinesProvider = StreamProvider<List<RoutineData>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllRoutines();
});

final routineDetailsProvider = StreamProvider.family<List<RoutineDetail>, int>((
  ref,
  routineId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchRoutineDetails(routineId);
});
