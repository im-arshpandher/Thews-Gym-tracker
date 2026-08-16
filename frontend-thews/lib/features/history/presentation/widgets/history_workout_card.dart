import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Card displaying a logged workout entry in the history list.
class HistoryWorkoutCard extends ConsumerWidget {
  final WorkoutData workout;
  final bool isDark;
  final String formattedDate;
  final String formattedDuration;

  const HistoryWorkoutCard({
    super.key,
    required this.workout,
    required this.isDark,
    required this.formattedDate,
    required this.formattedDuration,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/history/workout/${workout.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primaryVolt.withValues(alpha: 0.15)
                      : AppColors.lightPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: isDark
                      ? AppColors.primaryVoltDim
                      : AppColors.lightPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.notes ?? 'Workout Session',
                      style: AppTypography.bodyLg(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$formattedDate • $formattedDuration',
                      style: AppTypography.bodySm(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'Delete Workout',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Workout?'),
                      content: const Text(
                        'This workout entry will be permanently removed.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('CANCEL', maxLines: 1, softWrap: false),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'DELETE',
                            style: TextStyle(color: AppColors.error),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final db = ref.read(databaseProvider);
                    await db.deleteWorkout(workout.id);
                  }
                },
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
      ),
    );
  }
}
