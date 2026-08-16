import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/models/muscle_group.dart';
import '../../../../core/presentation/widgets/muscle_group_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../exercises/presentation/exercises_provider.dart';

/// Bottom sheet for selecting an exercise to add to the active workout session.
class AddExerciseBottomSheet extends ConsumerStatefulWidget {
  final ValueChanged<ExerciseData> onSelectExercise;

  const AddExerciseBottomSheet({super.key, required this.onSelectExercise});

  @override
  ConsumerState<AddExerciseBottomSheet> createState() =>
      _AddExerciseBottomSheetState();
}

class _AddExerciseBottomSheetState
    extends ConsumerState<AddExerciseBottomSheet> {
  String _selectedGroup = 'All';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exercisesAsync = ref.watch(allExercisesProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.lightSurfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handlebar & Title Bar
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
                  Expanded(
                    child: Text(
                      'Add Exercise to Session',
                      style: AppTypography.headlineMd(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
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
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),

              // Top Muscle Group Selection Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: MuscleGroup.values.map((group) {
                    final isSelected = _selectedGroup == group.label;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(group.label.toUpperCase()),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedGroup = group.label;
                          });
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
              const SizedBox(height: 16),

              // Exercises List
              Expanded(
                child: exercisesAsync.when(
                  data: (allExercises) {
                    // Filter by selected muscle group and search query locally
                    final filtered = allExercises.where((ex) {
                      final matchesGroup =
                          _selectedGroup == 'All' ||
                          ex.muscleGroup.toLowerCase() ==
                              _selectedGroup.toLowerCase();
                      final matchesSearch =
                          _searchQuery.isEmpty ||
                          ex.name.toLowerCase().contains(_searchQuery);
                      return matchesGroup && matchesSearch;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fitness_center_outlined,
                              size: 48,
                              color: isDark
                                  ? AppColors.darkOutlineVariant
                                  : AppColors.lightOutlineVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No exercises found',
                              style: AppTypography.bodyLg(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: isDark
                            ? AppColors.darkOutline.withValues(alpha: 0.15)
                            : AppColors.lightOutline.withValues(alpha: 0.15),
                      ),
                      itemBuilder: (context, index) {
                        final ex = filtered[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          leading: MuscleGroupIcon(
                            muscleGroup: ex.muscleGroup,
                            size: 44,
                          ),
                          title: Text(
                            ex.name,
                            style: AppTypography.bodyLg(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.getMuscleGroupBgColor(
                                    ex.muscleGroup,
                                    isDark,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ex.muscleGroup.toUpperCase(),
                                  style:
                                      AppTypography.labelCaps(
                                        color:
                                            AppColors.getMuscleGroupTextColor(
                                              ex.muscleGroup,
                                              isDark,
                                            ),
                                      ).copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.add_circle,
                              color: isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary,
                              size: 28,
                            ),
                            onPressed: () {
                              widget.onSelectExercise(ex);
                              Navigator.of(context).pop();
                            },
                          ),
                          onTap: () {
                            widget.onSelectExercise(ex);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryVolt,
                    ),
                  ),
                  error: (e, s) =>
                      Center(child: Text('Error loading exercises: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
