import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/presentation/widgets/muscle_group_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../routines_provider.dart';

/// Card widget for a saved routine template.
class RoutineCard extends ConsumerWidget {
  final RoutineData routine;
  final VoidCallback onLaunch;
  final VoidCallback onEdit;

  const RoutineCard({
    super.key,
    required this.routine,
    required this.onLaunch,
    required this.onEdit,
  });

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
                      onPressed: onEdit,
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
                                child: const Text(
                                  'CANCEL',
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'DELETE',
                                  maxLines: 1,
                                  softWrap: false,
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
                  maxLines: 1,
                  softWrap: false,
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
