import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/muscle_group.dart';
import '../../../core/presentation/widgets/muscle_group_icon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'exercises_provider.dart';
import 'widgets/exercise_details_sheet.dart';
import 'widgets/exercise_form_dialog.dart';

class ExerciseListScreen extends ConsumerWidget {
  const ExerciseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedGroup = ref.watch(selectedMuscleGroupFilterProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final exercisesAsync = ref.watch(filteredExercisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'EXERCISES',
          style: AppTypography.headlineMd(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle,
              color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
              size: 28,
            ),
            tooltip: 'Add Custom Exercise',
            onPressed: () => ExerciseFormDialog.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              onChanged: (val) =>
                  ref.read(searchQueryProvider.notifier).state = val,
              style: AppTypography.bodyMd(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark
                      ? AppColors.darkOutlineVariant
                      : AppColors.lightOutline,
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            ref.read(searchQueryProvider.notifier).state = '',
                      )
                    : null,
              ),
            ),
          ),

          // Muscle Group Category Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: MuscleGroup.values.map((group) {
                final isSelected = selectedGroup == group.label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: group == MuscleGroup.all
                        ? null
                        : MuscleGroupIcon(
                            muscleGroup: group.label,
                            size: 18,
                          ),
                    label: Text(
                      group.label.toUpperCase(),
                      maxLines: 1,
                      softWrap: false,
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      ref
                              .read(selectedMuscleGroupFilterProvider.notifier)
                              .state =
                          group.label;
                    },
                    selectedColor: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimaryContainer,
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceContainer
                        : AppColors.lightSurfaceContainerLow,
                    checkmarkColor: isDark
                        ? AppColors.primaryVoltOn
                        : AppColors.lightPrimaryDark,
                    labelStyle: AppTypography.labelCaps(
                      color: isSelected
                          ? (isDark
                                ? AppColors.primaryVoltOn
                                : AppColors.lightPrimaryDark)
                          : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                    ),
                    shape: const StadiumBorder(),
                    side: BorderSide(
                      color: isSelected
                          ? (isDark
                                ? AppColors.primaryVolt
                                : AppColors.lightPrimary)
                          : Colors.transparent,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Exercises List
          Expanded(
            child: exercisesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryVolt),
              ),
              error: (err, stack) => Center(
                child: Text(
                  'Error loading exercises: $err',
                  style: AppTypography.bodyMd(color: AppColors.error),
                ),
              ),
              data: (exercises) {
                if (exercises.isEmpty) {
                  return _buildEmptyState(context, ref);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    return _ExerciseCard(exercise: exercise);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Icon(
            Icons.fitness_center_outlined,
            size: 64,
            color: isDark
                ? AppColors.darkOutlineVariant
                : AppColors.lightOutlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No exercises found',
            style: AppTypography.headlineSm(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different muscle group or search term, or create your own custom exercise.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ExerciseFormDialog.show(context),
            icon: const Icon(Icons.add),
            label: const Text(
              'CREATE EXERCISE',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  final ExerciseData exercise;

  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMedia =
        exercise.videoUrl != null && exercise.videoUrl!.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => ExerciseDetailsSheet.show(context, exercise),
        leading: MuscleGroupIcon(muscleGroup: exercise.muscleGroup, size: 44),
        title: Text(
          exercise.name,
          style: AppTypography.bodyLg(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.getMuscleGroupBgColor(
                    exercise.muscleGroup,
                    isDark,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  exercise.muscleGroup.toUpperCase(),
                  style: AppTypography.labelCaps(
                    color: AppColors.getMuscleGroupTextColor(
                      exercise.muscleGroup,
                      isDark,
                    ),
                  ).copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  softWrap: false,
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
                  _getCategoryLabel(exercise.category).toUpperCase(),
                  style: AppTypography.labelCaps(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ).copyWith(fontSize: 10),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasMedia)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 20,
                  color: AppColors.primaryVolt,
                ),
              ),
            Icon(
              Icons.chevron_right,
              color: isDark
                  ? AppColors.darkOutlineVariant
                  : AppColors.lightOutlineVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryLabel(String? category) {
    switch (category?.toLowerCase().trim()) {
      case 'weight_reps':
        return 'Weight • Reps';
      case 'reps_only':
        return 'Reps Only';
      case 'duration_time':
        return 'Duration';
      case 'cardio_distance':
        return 'Cardio';
      default:
        return 'Weight • Reps';
    }
  }
}
