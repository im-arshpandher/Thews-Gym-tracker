import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/presentation/widgets/muscle_group_icon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../exercises/presentation/exercises_provider.dart';

final routinesProvider = StreamProvider<List<RoutineData>>((ref) {
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

class RoutinesScreen extends ConsumerWidget {
  final Function(RoutineData)? onLaunchRoutine;

  const RoutinesScreen({super.key, this.onLaunchRoutine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final routinesAsync = ref.watch(routinesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ROUTINE TEMPLATES',
          style: AppTypography.headlineMd(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRoutineSheet(context, ref),
        backgroundColor: AppColors.primaryVolt,
        foregroundColor: AppColors.primaryVoltOn,
        icon: const Icon(Icons.add, size: 18),
        label: const Text(
          'NEW ROUTINE',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
      body: routinesAsync.when(
        data: (routines) {
          if (routines.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 64,
                    color: isDark
                        ? AppColors.darkOutlineVariant
                        : AppColors.lightOutlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Workout Routines Yet',
                    style: AppTypography.headlineSm(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create preset templates to start your workouts with 1 tap!',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateRoutineSheet(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('CREATE YOUR FIRST ROUTINE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryVolt,
                      foregroundColor: AppColors.primaryVoltOn,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: routines.length,
            itemBuilder: (context, index) {
              final routine = routines[index];
              return _RoutineCard(
                routine: routine,
                onLaunch: () {
                  if (onLaunchRoutine != null) {
                    onLaunchRoutine!(routine);
                  } else {
                    context.go('/log');
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryVolt),
        ),
        error: (e, s) => Center(child: Text('Error loading routines: $e')),
      ),
    );
  }

  static void _showCreateRoutineSheet(
    BuildContext context,
    WidgetRef ref, {
    RoutineData? routineToEdit,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _CreateRoutineBottomSheet(routineToEdit: routineToEdit),
    );
  }
}

class _RoutineCard extends ConsumerWidget {
  final RoutineData routine;
  final VoidCallback onLaunch;

  const _RoutineCard({required this.routine, required this.onLaunch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detailsAsync = ref.watch(routineDetailsProvider(routine.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routine.name,
                        style: AppTypography.headlineSm(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      if (routine.description != null &&
                          routine.description!.isNotEmpty)
                        Text(
                          routine.description!,
                          style: AppTypography.bodySm(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      tooltip: 'Edit Routine',
                      onPressed: () {
                        RoutinesScreen._showCreateRoutineSheet(
                          context,
                          ref,
                          routineToEdit: routine,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      tooltip: 'Delete Routine',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Routine?'),
                            content: Text(
                              'Are you sure you want to delete "${routine.name}"?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('CANCEL'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'DELETE',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref
                              .read(databaseProvider)
                              .deleteRoutine(routine.id);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            detailsAsync.when(
              data: (details) {
                if (details.isEmpty) {
                  return Text(
                    'No exercises added',
                    style: AppTypography.bodySm(),
                  );
                }
                return Column(
                  children: details.map((d) {
                    final targetWeight = d.routineExercise.targetWeight;
                    final weightText = targetWeight > 0
                        ? ' @ ${targetWeight % 1 == 0 ? targetWeight.toInt() : targetWeight}kg'
                        : '';
                    final badgeText =
                        '${d.routineExercise.targetSets} sets × ${d.routineExercise.targetReps} reps$weightText';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          MuscleGroupIcon(
                            muscleGroup: d.exercise.muscleGroup,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              d.exercise.name,
                              style: AppTypography.bodyMd(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceContainerHigh
                                  : AppColors.lightSurfaceContainerLow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: AppTypography.labelCaps(
                                color: isDark
                                    ? AppColors.primaryVolt
                                    : AppColors.lightPrimary,
                              ).copyWith(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () =>
                  const CircularProgressIndicator(color: AppColors.primaryVolt),
              error: (e, s) => const Text('Error loading exercises'),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onLaunch,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text(
                  'START WORKOUT ROUTINE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryVolt,
                  foregroundColor: AppColors.primaryVoltOn,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateRoutineBottomSheet extends ConsumerStatefulWidget {
  final RoutineData? routineToEdit;

  const _CreateRoutineBottomSheet({this.routineToEdit});

  @override
  ConsumerState<_CreateRoutineBottomSheet> createState() =>
      _CreateRoutineBottomSheetState();
}

class _CreateRoutineBottomSheetState
    extends ConsumerState<_CreateRoutineBottomSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final List<_SelectedRoutineExercise> _selected = [];
  bool _isLoadingEdit = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.routineToEdit?.name ?? '',
    );
    _descController = TextEditingController(
      text: widget.routineToEdit?.description ?? '',
    );
    if (widget.routineToEdit != null) {
      _loadExistingExercises();
    }
  }

  Future<void> _loadExistingExercises() async {
    setState(() => _isLoadingEdit = true);
    final db = ref.read(databaseProvider);
    final details = await db
        .watchRoutineDetails(widget.routineToEdit!.id)
        .first;
    if (mounted) {
      setState(() {
        _selected.clear();
        for (final d in details) {
          _selected.add(
            _SelectedRoutineExercise(
              exercise: d.exercise,
              targetSets: d.routineExercise.targetSets,
              targetReps: d.routineExercise.targetReps,
              targetWeight: d.routineExercise.targetWeight,
            ),
          );
        }
        _isLoadingEdit = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _configureExerciseMetrics(
    ExerciseData exercise, {
    _SelectedRoutineExercise? existingItem,
  }) async {
    int sets = existingItem?.targetSets ?? 3;
    int reps = existingItem?.targetReps ?? 10;
    double weight = existingItem?.targetWeight ?? 0.0;
    final weightController = TextEditingController(
      text: weight > 0
          ? (weight % 1 == 0 ? weight.toInt().toString() : weight.toString())
          : '',
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<_SelectedRoutineExercise>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark
                  ? AppColors.darkSurfaceContainerLow
                  : AppColors.lightSurfaceContainerLowest,
              title: Row(
                children: [
                  MuscleGroupIcon(muscleGroup: exercise.muscleGroup, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: AppTypography.headlineSm(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TARGET SETS',
                      style: AppTypography.labelCaps(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: sets > 1
                              ? () => setDialogState(() => sets--)
                              : null,
                        ),
                        Text(
                          '$sets Sets',
                          style: AppTypography.headlineSm(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setDialogState(() => sets++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'TARGET REPS PER SET',
                      style: AppTypography.labelCaps(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: reps > 1
                              ? () => setDialogState(() => reps--)
                              : null,
                        ),
                        Text(
                          '$reps Reps',
                          style: AppTypography.headlineSm(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setDialogState(() => reps++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'TARGET WEIGHT (KG / LBS)',
                      style: AppTypography.labelCaps(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: AppTypography.bodyMd(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'e.g. 60.0 (Optional)',
                        suffixText: 'kg',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final parsedWeight =
                        double.tryParse(weightController.text.trim()) ?? 0.0;
                    Navigator.pop(
                      ctx,
                      _SelectedRoutineExercise(
                        exercise: exercise,
                        targetSets: sets,
                        targetReps: reps,
                        targetWeight: parsedWeight,
                      ),
                    );
                  },
                  child: Text(
                    existingItem == null ? 'ADD TO ROUTINE' : 'SAVE METRICS',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        if (existingItem != null) {
          existingItem.targetSets = result.targetSets;
          existingItem.targetReps = result.targetReps;
          existingItem.targetWeight = result.targetWeight;
        } else {
          _selected.add(result);
        }
      });
    }
  }

  Future<void> _saveRoutine() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a routine name'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one exercise to the routine'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final db = ref.read(databaseProvider);
    final isEditing = widget.routineToEdit != null;

    final reCompanions = List.generate(_selected.length, (i) {
      final s = _selected[i];
      return RoutineExercisesCompanion.insert(
        routineId: widget.routineToEdit?.id ?? 0,
        exerciseId: s.exercise.id,
        targetSets: Value(s.targetSets),
        targetReps: Value(s.targetReps),
        targetWeight: Value(s.targetWeight),
        sortOrder: Value(i),
      );
    });

    if (isEditing) {
      await db.updateRoutineWithExercises(
        widget.routineToEdit!.id,
        name,
        _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        reCompanions
            .map(
              (re) => re.copyWith(routineId: Value(widget.routineToEdit!.id)),
            )
            .toList(),
      );
    } else {
      final routineId = await db.insertRoutine(
        RoutinesCompanion.insert(
          name: name,
          description: Value(
            _descController.text.trim().isNotEmpty
                ? _descController.text.trim()
                : null,
          ),
        ),
      );
      for (final re in reCompanions) {
        await db.insertRoutineExercise(
          re.copyWith(routineId: Value(routineId)),
        );
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Routine "$name" Updated!' : 'Routine "$name" Created!',
          ),
          backgroundColor: AppColors.primaryVolt,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exercisesAsync = ref.watch(allExercisesProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.routineToEdit != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainerLow
              : AppColors.lightSurfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkOutline
                            : AppColors.lightOutline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing
                            ? 'Edit Routine Template'
                            : 'Create Routine Template',
                        style: AppTypography.headlineMd(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Routine Name (e.g. Legs Hypertrophy)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'EXERCISES IN ROUTINE',
                    style: AppTypography.labelCaps(),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: _isLoadingEdit
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryVolt,
                            ),
                          )
                        : (_selected.isEmpty
                              ? Center(
                                  child: Text(
                                    'No exercises added yet',
                                    style: AppTypography.bodySm(),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _selected.length,
                                  itemBuilder: (context, index) {
                                    final item = _selected[index];
                                    final weightText = item.targetWeight > 0
                                        ? ' • ${item.targetWeight % 1 == 0 ? item.targetWeight.toInt() : item.targetWeight}kg'
                                        : '';
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        onTap: () => _configureExerciseMetrics(
                                          item.exercise,
                                          existingItem: item,
                                        ),
                                        leading: MuscleGroupIcon(
                                          muscleGroup:
                                              item.exercise.muscleGroup,
                                          size: 32,
                                        ),
                                        title: Text(
                                          item.exercise.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${item.targetSets} sets × ${item.targetReps} reps$weightText',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                              ),
                                              tooltip: 'Edit Metrics',
                                              onPressed: () =>
                                                  _configureExerciseMetrics(
                                                    item.exercise,
                                                    existingItem: item,
                                                  ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.close,
                                                color: AppColors.error,
                                                size: 18,
                                              ),
                                              tooltip: 'Remove',
                                              onPressed: () {
                                                setState(
                                                  () =>
                                                      _selected.removeAt(index),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                )),
                  ),

                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      exercisesAsync.whenData((allEx) {
                        showDialog(
                          context: context,
                          builder: (ctx) => SimpleDialog(
                            title: const Text('Select Exercise to Add'),
                            children: allEx.map((ex) {
                              return SimpleDialogOption(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _configureExerciseMetrics(ex);
                                },
                                child: Row(
                                  children: [
                                    MuscleGroupIcon(
                                      muscleGroup: ex.muscleGroup,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(ex.name)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('ADD EXERCISE TO ROUTINE'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveRoutine,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryVolt,
                        foregroundColor: AppColors.primaryVoltOn,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        isEditing
                            ? 'UPDATE ROUTINE TEMPLATE'
                            : 'SAVE ROUTINE TEMPLATE',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedRoutineExercise {
  final ExerciseData exercise;
  int targetSets;
  int targetReps;
  double targetWeight;

  _SelectedRoutineExercise({
    required this.exercise,
    this.targetSets = 3,
    this.targetReps = 10,
    this.targetWeight = 0.0,
  });
}
