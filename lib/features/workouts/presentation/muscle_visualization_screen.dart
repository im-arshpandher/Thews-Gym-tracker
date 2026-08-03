import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/presentation/widgets/anatomical_body_painter.dart';
import '../../../core/presentation/widgets/muscle_group_icon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'muscle_visualization_provider.dart';

class MuscleVisualizationScreen extends ConsumerWidget {
  const MuscleVisualizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final timeframe = ref.watch(muscleTimeframeProvider);
    final selectedMuscle = ref.watch(selectedVisualizationMuscleProvider);
    final statsAsync = ref.watch(muscleVisualizationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MUSCLE VISUALIZER',
          style: AppTypography.headlineMd(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(muscleVisualizationProvider);
        },
        color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeframe Segmented Selector
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<MuscleTimeframe>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<MuscleTimeframe>(
                      value: MuscleTimeframe.week,
                      label: Text('THIS WEEK', maxLines: 1, softWrap: false),
                    ),
                    ButtonSegment<MuscleTimeframe>(
                      value: MuscleTimeframe.month,
                      label: Text('THIS MONTH', maxLines: 1, softWrap: false),
                    ),
                    ButtonSegment<MuscleTimeframe>(
                      value: MuscleTimeframe.all,
                      label: Text('ALL TIME', maxLines: 1, softWrap: false),
                    ),
                  ],
                  selected: {timeframe},
                  onSelectionChanged: (newSelection) {
                    ref.read(muscleTimeframeProvider.notifier).state =
                        newSelection.first;
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return isDark
                            ? AppColors.primaryVolt
                            : AppColors.lightPrimaryContainer;
                      }
                      return isDark
                          ? AppColors.darkSurfaceContainerHigh
                          : AppColors.lightSurfaceContainerLow;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color?>((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return isDark
                            ? AppColors.primaryVoltOn
                            : AppColors.primaryVoltOn;
                      }
                      return isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              statsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(
                      color: AppColors.primaryVolt,
                    ),
                  ),
                ),
                error: (e, s) => Center(
                  child: Text(
                    'Error loading muscle visualizer data: $e',
                    style: AppTypography.bodyMd(color: AppColors.error),
                  ),
                ),
                data: (muscleMap) {
                  final muscleSetCounts = {
                    for (final entry in muscleMap.entries)
                      entry.key: entry.value.totalSets,
                  };

                  final currentStats =
                      muscleMap[selectedMuscle] ??
                      MuscleGroupStats(
                        muscleGroup: selectedMuscle,
                        totalVolume: 0,
                        totalSets: 0,
                        totalWorkouts: 0,
                        topExercises: [],
                      );

                  final totalVolumeAll = muscleMap.values.fold<double>(
                    0,
                    (sum, m) => sum + m.totalVolume,
                  );
                  final volumeSharePercent = totalVolumeAll > 0
                      ? ((currentStats.totalVolume / totalVolumeAll) * 100)
                            .toStringAsFixed(1)
                      : '0.0';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Anatomical Heatmap Figure Card
                      AnatomicalBodyPainterWidget(
                        muscleSetCounts: muscleSetCounts,
                        selectedMuscleGroup: selectedMuscle,
                        onSelectMuscleGroup: (group) {
                          ref
                                  .read(
                                    selectedVisualizationMuscleProvider
                                        .notifier,
                                  )
                                  .state =
                              group;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Selected Muscle Detail Summary Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  MuscleGroupIcon(
                                    muscleGroup: selectedMuscle,
                                    size: 40,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedMuscle.toUpperCase(),
                                          style: AppTypography.headlineSm(
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                        Text(
                                          '${currentStats.statusLabel} • $volumeSharePercent% of total workout volume',
                                          style: AppTypography.bodySm(
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.primaryVolt.withValues(
                                              alpha: 0.2,
                                            )
                                          : AppColors.lightPrimaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      currentStats.statusLabel.toUpperCase(),
                                      style:
                                          AppTypography.labelCaps(
                                            color: isDark
                                                ? AppColors.primaryVolt
                                                : AppColors.lightPrimary,
                                          ).copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),

                              // Metrics Row (Volume, Sets, Sessions)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildMetricTile(
                                    context,
                                    label: 'TOTAL VOLUME',
                                    value: currentStats.totalVolume >= 1000
                                        ? '${(currentStats.totalVolume / 1000).toStringAsFixed(1)}k kg'
                                        : '${currentStats.totalVolume.toStringAsFixed(0)} kg',
                                    isDark: isDark,
                                  ),
                                  _buildMetricTile(
                                    context,
                                    label: 'TOTAL SETS',
                                    value: '${currentStats.totalSets} sets',
                                    isDark: isDark,
                                  ),
                                  _buildMetricTile(
                                    context,
                                    label: 'SESSIONS',
                                    value: '${currentStats.totalWorkouts}',
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Target Weekly Volume Progress Bar
                              Text(
                                'WEEKLY TARGET PROGRESS (16 SETS OPTIMAL)',
                                style: AppTypography.labelCaps(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ).copyWith(fontSize: 10),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: currentStats.targetSetPercentage,
                                  minHeight: 8,
                                  backgroundColor: isDark
                                      ? AppColors.darkSurfaceContainerHigh
                                      : AppColors.lightSurfaceContainerLow,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isDark
                                        ? AppColors.primaryVolt
                                        : AppColors.lightPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Exercises Recorded for Selected Muscle Group
                      Text(
                        'TOP EXERCISES (${selectedMuscle.toUpperCase()})',
                        style: AppTypography.labelCaps(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (currentStats.topExercises.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'No exercises recorded for $selectedMuscle in this timeframe.',
                                style: AppTypography.bodySm(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        ...currentStats.topExercises.map((ex) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: MuscleGroupIcon(
                                muscleGroup: selectedMuscle,
                                size: 32,
                              ),
                              title: Text(
                                ex.name,
                                style: AppTypography.bodyMd(
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${ex.sets} sets • Max: ${ex.maxWeight % 1 == 0 ? ex.maxWeight.toInt() : ex.maxWeight} kg',
                                style: AppTypography.bodySm(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              trailing: Text(
                                ex.totalVolume >= 1000
                                    ? '${(ex.totalVolume / 1000).toStringAsFixed(1)}k kg'
                                    : '${ex.totalVolume.toStringAsFixed(0)} kg',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.primaryVolt
                                      : AppColors.lightPrimary,
                                ),
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/exercises'),
                          icon: const Icon(Icons.fitness_center, size: 18),
                          label: const Text('EXPLORE EXERCISES IN LIBRARY'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.labelCaps(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ).copyWith(fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.cardTitle(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ).copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
