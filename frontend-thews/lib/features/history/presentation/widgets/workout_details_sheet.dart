import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'workout_exercise_tile.dart';
import '../../../../core/utils/volume_calculator.dart';

final workoutDetailsStreamProvider =
    StreamProvider.family<List<WorkoutExerciseDetail>, int>((ref, workoutId) {
      final db = ref.watch(databaseProvider);
      return db.watchWorkoutDetails(workoutId);
    });

class WorkoutDetailsSheet extends ConsumerWidget {
  final WorkoutData workout;

  const WorkoutDetailsSheet({super.key, required this.workout});

  static Future<void> show(BuildContext context, WorkoutData workout) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WorkoutDetailsSheet(workout: workout),
    );
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0 min';
    final mins = totalSeconds ~/ 60;
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    return '${hrs}h ${remMins}m';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.day} ${months[date.month - 1]} ${date.year} • $timeStr';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detailsAsync = ref.watch(workoutDetailsStreamProvider(workout.id));

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainerLow
              : AppColors.lightSurfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handlebar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkOutline
                          : AppColors.lightOutline.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title & Action Buttons Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          workout.notes ?? 'Workout Session',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showEditWorkoutDialog(context, ref),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceContainerHigh
                              : AppColors.lightSurfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkOutline
                                : AppColors.lightOutline.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('✏️', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              'EDIT',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Date Subtitle Row
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatDate(workout.date),
                          style: AppTypography.bodySm(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Details Content
                Expanded(
                  child: detailsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryVolt,
                      ),
                    ),
                    error: (err, stack) => Center(
                      child: Text(
                        'Error loading details: $err',
                        style: AppTypography.bodySm(color: AppColors.error),
                      ),
                    ),
                    data: (details) {
                      // Calculate Stats
                      double totalVolume = 0;
                      int totalSets = 0;

                      for (final d in details) {
                        for (final s in d.sets) {
                          totalVolume += VolumeCalculator.calculateSetVolume(
                            weight: s.weight,
                            reps: s.reps,
                            type: s.type,
                            unit: s.unit,
                          );
                          totalSets++;
                        }
                      }

                      return ListView(
                        children: [
                          // Stats Summary Cards Row
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceContainer
                                  : AppColors.lightSurfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkOutline
                                    : AppColors.lightOutline.withValues(
                                        alpha: 0.3,
                                      ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  isDark,
                                  icon: Icons.timer_outlined,
                                  label: 'Duration',
                                  value: _formatDuration(
                                    workout.durationSeconds,
                                  ),
                                ),
                                Container(
                                  height: 36,
                                  width: 1,
                                  color: isDark
                                      ? AppColors.darkOutline
                                      : AppColors.lightOutline.withValues(
                                          alpha: 0.3,
                                        ),
                                ),
                                _buildStatItem(
                                  isDark,
                                  icon: Icons.fitness_center,
                                  label: 'Total Volume',
                                  value:
                                      '${totalVolume % 1 == 0 ? totalVolume.toInt() : totalVolume.toStringAsFixed(1)} kg',
                                ),
                                Container(
                                  height: 36,
                                  width: 1,
                                  color: isDark
                                      ? AppColors.darkOutline
                                      : AppColors.lightOutline.withValues(
                                          alpha: 0.3,
                                        ),
                                ),
                                _buildStatItem(
                                  isDark,
                                  icon: Icons.format_list_bulleted,
                                  label: 'Exercises / Sets',
                                  value: '${details.length} / $totalSets',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (details.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  'No exercise sets recorded for this session.',
                                  style: AppTypography.bodySm(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...details.map(
                              (d) => WorkoutExerciseTile(
                                detail: d,
                                isDark: isDark,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Bottom Action: Delete Workout Button
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: TextButton.icon(
                      onPressed: () => _confirmDeleteWorkout(context, ref),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      label: const Text(
                        'DELETE WORKOUT SESSION',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    bool isDark, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final iconColor = isDark
        ? AppColors.primaryVoltDim
        : const Color(0xFF4C7B00);
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final labelColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _showEditWorkoutDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(
      text: workout.notes ?? 'Workout Session',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Workout Session',
          style: AppTypography.headlineSm(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SESSION TITLE / NOTES',
              style: AppTypography.labelCaps(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              autofocus: true,
              style: AppTypography.bodyLg(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Chest & Triceps Blast',
                prefixIcon: Icon(Icons.edit_note),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                final db = ref.read(databaseProvider);
                final updated = workout.copyWith(notes: Value(newTitle));
                await db.updateWorkout(updated);
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryVolt,
              foregroundColor: AppColors.primaryVoltOn,
            ),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteWorkout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Workout Session?'),
        content: const Text(
          'This workout session record will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              Navigator.of(ctx).pop(); // pop dialog
              if (context.mounted) {
                Navigator.of(context).pop(); // pop bottom sheet
              }
              await db.deleteWorkout(workout.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}
