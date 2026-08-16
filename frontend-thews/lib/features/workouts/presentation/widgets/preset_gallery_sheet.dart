import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/presentation/widgets/muscle_group_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/preset_routines.dart';

/// Bottom sheet displaying starter template gallery routines that can be imported.
class PresetGallerySheet extends ConsumerWidget {
  const PresetGallerySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final db = ref.read(databaseProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.lightSurfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
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
                    'STARTER TEMPLATE GALLERY',
                    style: AppTypography.headlineMd(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Import pre-configured workout splits directly into your custom routines',
                style: AppTypography.bodySm(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: PresetRoutine.starterTemplates.length,
                  itemBuilder: (context, index) {
                    final preset = PresetRoutine.starterTemplates[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        preset.name,
                                        style: AppTypography.headlineSm(
                                          color: isDark
                                              ? AppColors.darkTextPrimary
                                              : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        preset.description,
                                        style: AppTypography.bodySm(
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final allExercises = await db
                                        .getAllExercises();
                                    final routineId = await db.insertRoutine(
                                      RoutinesCompanion.insert(
                                        name: preset.name,
                                        description: Value(preset.description),
                                      ),
                                    );

                                    for (
                                      int i = 0;
                                      i < preset.exercises.length;
                                      i++
                                    ) {
                                      final pe = preset.exercises[i];
                                      final match = allExercises.firstWhere(
                                        (e) =>
                                            e.name.toLowerCase() ==
                                            pe.exerciseName.toLowerCase(),
                                        orElse: () => allExercises.first,
                                      );
                                      await db.insertRoutineExercise(
                                        RoutineExercisesCompanion.insert(
                                          routineId: routineId,
                                          exerciseId: match.id,
                                          targetSets: Value(pe.targetSets),
                                          targetReps: Value(pe.targetReps),
                                          sortOrder: Value(i),
                                        ),
                                      );
                                    }

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Imported "${preset.name}" into routines!',
                                          ),
                                          backgroundColor:
                                              AppColors.primaryVolt,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.download, size: 16),
                                  label: const Text(
                                    'IMPORT',
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryVolt,
                                    foregroundColor: AppColors.primaryVoltOn,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: preset.exercises.map((e) {
                                return Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(
                                    '${e.exerciseName} (${e.targetSets}×${e.targetReps})',
                                    maxLines: 1,
                                    softWrap: false,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  avatar: MuscleGroupIcon(
                                    muscleGroup: e.muscleGroup,
                                    size: 16,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
