import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/presentation/widgets/anatomical_body_painter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/volume_calculator.dart';
import 'widgets/workout_exercise_tile.dart';
import 'widgets/workout_share_card.dart';

final singleWorkoutStreamProvider =
    StreamProvider.family<WorkoutData?, int>((ref, workoutId) {
  final db = ref.watch(databaseProvider);
  return db.watchWorkoutById(workoutId);
});

final workoutSessionDetailsStreamProvider =
    StreamProvider.family<List<WorkoutExerciseDetail>, int>((ref, workoutId) {
  final db = ref.watch(databaseProvider);
  return db.watchWorkoutDetails(workoutId);
});

class WorkoutSessionDetailScreen extends ConsumerStatefulWidget {
  final int workoutId;

  const WorkoutSessionDetailScreen({
    super.key,
    required this.workoutId,
  });

  @override
  ConsumerState<WorkoutSessionDetailScreen> createState() =>
      _WorkoutSessionDetailScreenState();
}

class _WorkoutSessionDetailScreenState
    extends ConsumerState<WorkoutSessionDetailScreen> {
  bool _isEditingNotes = false;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 min';
    final mins = seconds ~/ 60;
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    return '${hrs}h ${remMins}m';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.day} ${months[date.month - 1]} ${date.year} • $timeStr';
  }

  Map<String, int> _calculateSessionMuscleSetCounts(
    List<WorkoutExerciseDetail> details,
  ) {
    final Map<String, int> counts = {};
    for (final detail in details) {
      final primary = detail.exercise.muscleGroup.toLowerCase().trim();
      final setCount = detail.sets.isNotEmpty ? detail.sets.length : 1;
      counts[primary] = (counts[primary] ?? 0) + setCount;

      if (detail.exercise.secondaryMuscleGroups != null &&
          detail.exercise.secondaryMuscleGroups!.trim().isNotEmpty) {
        final secondaries = detail.exercise.secondaryMuscleGroups!
            .split(',')
            .map((s) => s.trim().toLowerCase());
        for (final sec in secondaries) {
          if (sec.isNotEmpty) {
            counts[sec] =
                (counts[sec] ?? 0) + (setCount ~/ 2 > 0 ? setCount ~/ 2 : 1);
          }
        }
      }
    }
    return counts;
  }

  Future<void> _showDeleteConfirmation(BuildContext context, WorkoutData workout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Workout Session?'),
        content: const Text(
          'Are you sure you want to permanently delete this workout session and all associated set data? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', maxLines: 1, softWrap: false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DELETE', maxLines: 1, softWrap: false),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final db = ref.read(databaseProvider);
      await db.deleteWorkout(workout.id);
      if (context.mounted) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final workoutAsync = ref.watch(singleWorkoutStreamProvider(widget.workoutId));
    final detailsAsync = ref.watch(workoutSessionDetailsStreamProvider(widget.workoutId));

    return workoutAsync.when(
      data: (workout) {
        if (workout == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Workout Details')),
            body: const Center(child: Text('Workout session not found.')),
          );
        }

        return detailsAsync.when(
          data: (details) {
            final totalVolume = details.fold<double>(
              0.0,
              (sum, d) => sum + VolumeCalculator.calculateTotalVolume(d.sets),
            );
            final totalSets = details.fold<int>(0, (sum, d) => sum + d.sets.length);
            final muscleGroups = details
                .map((d) => d.exercise.muscleGroup)
                .toSet()
                .toList();

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  'WORKOUT SESSION',
                  style: AppTypography.sectionTitle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Share Workout Summary',
                    onPressed: () {
                      WorkoutShareCardDialog.show(
                        context,
                        workout: workout,
                        details: details,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    tooltip: 'Delete Workout Session',
                    onPressed: () => _showDeleteConfirmation(context, workout),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: AppSpacing.base,
                  right: AppSpacing.base,
                  top: AppSpacing.base,
                  bottom: MediaQuery.of(context).padding.bottom + 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Session Metrics Banner
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  AppColors.darkSurfaceContainerHighest,
                                  AppColors.darkSurfaceContainer,
                                ]
                              : [
                                  AppColors.lightPrimaryContainer,
                                  AppColors.lightSurfaceContainerLow,
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkOutline.withValues(alpha: 0.3)
                              : AppColors.lightOutline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDate(workout.date),
                                style: AppTypography.cardTitle(
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ).copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.primaryVolt.withValues(alpha: 0.15)
                                      : AppColors.lightPrimary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'COMPLETED',
                                  style: AppTypography.tinyLabel(
                                    color: isDark
                                        ? AppColors.primaryVolt
                                        : AppColors.lightPrimary,
                                  ),
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: _DetailSummaryTile(
                                  icon: Icons.timer_outlined,
                                  label: 'DURATION',
                                  value: _formatDuration(workout.durationSeconds),
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _DetailSummaryTile(
                                  icon: Icons.fitness_center_outlined,
                                  label: 'TOTAL VOLUME',
                                  value: '${totalVolume.toStringAsFixed(0)} kg',
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _DetailSummaryTile(
                                  icon: Icons.format_list_bulleted,
                                  label: 'TOTAL SETS',
                                  value: '$totalSets',
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Target Muscle Groups Section
                    Text(
                      'TARGET MUSCLE GROUPS',
                      style: AppTypography.labelCaps(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: muscleGroups.map((mg) {
                        return Chip(
                          backgroundColor: isDark
                              ? AppColors.darkSurfaceContainerHigh
                              : AppColors.lightSurfaceContainerHigh,
                          side: BorderSide(
                            color: isDark
                                ? AppColors.darkOutline.withValues(alpha: 0.2)
                                : AppColors.lightOutline.withValues(alpha: 0.2),
                          ),
                          label: Text(
                            mg.toUpperCase(),
                            style: AppTypography.bodySm(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Muscle Heatmap Visualizer Card
                    Builder(
                      builder: (context) {
                        final muscleSetCounts = _calculateSessionMuscleSetCounts(details);
                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceContainerHigh
                                : AppColors.lightSurfaceContainerLowest,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkOutline.withValues(alpha: 0.2)
                                  : AppColors.lightOutline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'MUSCLE HEATMAP VISUALIZER',
                                    style: AppTypography.labelCaps(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.primaryVolt.withValues(
                                              alpha: 0.15,
                                            )
                                          : AppColors.lightPrimary.withValues(
                                              alpha: 0.15,
                                            ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${muscleSetCounts.length} TARGETED',
                                      style: AppTypography.tinyLabel(
                                        color: isDark
                                            ? AppColors.primaryVolt
                                            : AppColors.lightPrimary,
                                      ).copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              AnatomicalBodyPainterWidget(
                                muscleSetCounts: muscleSetCounts,
                                selectedMuscleGroup: 'All',
                                transparentBg: true,
                                figureHeight: 200.0,
                                hideChips: true,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Notes Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SESSION NOTES',
                          style: AppTypography.labelCaps(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            if (_isEditingNotes) {
                              final db = ref.read(databaseProvider);
                              db.updateWorkoutNotes(
                                workout.id,
                                _notesController.text.trim(),
                              );
                              setState(() {
                                _isEditingNotes = false;
                              });
                            } else {
                              _notesController.text = workout.notes ?? '';
                              setState(() {
                                _isEditingNotes = true;
                              });
                            }
                          },
                          icon: Icon(
                            _isEditingNotes ? Icons.check : Icons.edit_outlined,
                            size: 16,
                          ),
                          label: Text(
                            _isEditingNotes ? 'SAVE' : 'EDIT',
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_isEditingNotes)
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Add workout notes or reflection...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceContainer
                              : AppColors.lightSurfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (workout.notes != null && workout.notes!.isNotEmpty)
                              ? workout.notes!
                              : 'No session notes recorded.',
                          style: AppTypography.bodyMd(
                            color: (workout.notes != null && workout.notes!.isNotEmpty)
                                ? (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary)
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                          ),
                        ),
                      ),

                    const SizedBox(height: AppSpacing.lg),

                    // Exercise Breakdown List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'EXERCISE BREAKDOWN (${details.length})',
                          style: AppTypography.labelCaps(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (details.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No exercise sets were logged for this session.'),
                        ),
                      )
                    else
                      ...details.map(
                        (detail) => WorkoutExerciseTile(
                          detail: detail,
                          isDark: isDark,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, s) => Scaffold(
            body: Center(child: Text('Error loading session details: $e')),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Scaffold(
        body: Center(child: Text('Error loading workout: $e')),
      ),
    );
  }
}

class _DetailSummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _DetailSummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.lightSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.cardTitle(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ).copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: AppTypography.tinyLabel(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
    );
  }
}
