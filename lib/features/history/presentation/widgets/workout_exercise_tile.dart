import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/models/exercise_metric.dart';
import '../../../../core/presentation/widgets/muscle_group_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/metric_formatter.dart';

/// Card widget displaying the set entries for a single exercise within a completed workout session.
/// Dynamically renders headers and columns matching the exercise's enabled metrics.
class WorkoutExerciseTile extends StatelessWidget {
  final WorkoutExerciseDetail detail;
  final bool isDark;

  const WorkoutExerciseTile({
    super.key,
    required this.detail,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? AppColors.darkSurfaceContainer
        : AppColors.lightSurfaceContainerLowest;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final volumeGreen = isDark
        ? const Color(0xFF66BB6A)
        : const Color(0xFF2E7D32);

    final enabledMetrics = ExerciseMetric.parseMetrics(
      detail.exercise.enabledMetrics,
    );
    final bool showVolumeColumn =
        enabledMetrics.contains(ExerciseMetric.weight) &&
        enabledMetrics.contains(ExerciseMetric.reps);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutline.withValues(alpha: 0.5)
              : AppColors.lightOutline.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise Header
          Row(
            children: [
              MuscleGroupIcon(
                muscleGroup: detail.exercise.muscleGroup,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.exercise.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.getMuscleGroupBgColor(
                          detail.exercise.muscleGroup,
                          isDark,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        detail.exercise.muscleGroup.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.getMuscleGroupTextColor(
                            detail.exercise.muscleGroup,
                            isDark,
                          ),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark
                ? AppColors.darkOutline.withValues(alpha: 0.4)
                : AppColors.lightOutline.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),

          // Dynamic Sets Table Header
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    'SET',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ...enabledMetrics.map(
                  (m) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '${m.shortLabel} (${m.defaultUnit.toUpperCase()})',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                if (showVolumeColumn)
                  SizedBox(
                    width: 75,
                    child: Text(
                      'VOLUME',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Dynamic Sets List Rows
          ...detail.sets.map((set) {
            final vol = set.weight * set.reps;
            final typePrefix = MetricFormatter.getSetTypePrefix(set.type);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _getSetTypeColor(set.type, isDark),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getSetTypeTextColor(
                            set.type,
                            isDark,
                          ).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '$typePrefix${set.setNumber}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: _getSetTypeTextColor(set.type, isDark),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...enabledMetrics.map(
                    (m) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          MetricFormatter.getMetricValueString(set, m),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showVolumeColumn)
                    SizedBox(
                      width: 75,
                      child: Text(
                        '${vol % 1 == 0 ? vol.toInt() : vol.toStringAsFixed(1)} kg',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: volumeGreen,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getSetTypeColor(String type, bool isDark) {
    switch (type) {
      case 'warmup':
        return isDark
            ? Colors.amber.shade900.withValues(alpha: 0.5)
            : Colors.amber.shade100;
      case 'drop':
        return isDark
            ? Colors.purple.shade900.withValues(alpha: 0.5)
            : Colors.purple.shade100;
      case 'failure':
        return isDark
            ? Colors.red.shade900.withValues(alpha: 0.5)
            : Colors.red.shade100;
      case 'normal':
      default:
        return isDark
            ? AppColors.darkSurfaceContainerHigh
            : AppColors.lightSurfaceContainerHigh;
    }
  }

  Color _getSetTypeTextColor(String type, bool isDark) {
    switch (type) {
      case 'warmup':
        return isDark ? Colors.amber.shade300 : Colors.amber.shade900;
      case 'drop':
        return isDark ? Colors.purple.shade300 : Colors.purple.shade900;
      case 'failure':
        return isDark ? Colors.red.shade300 : Colors.red.shade900;
      case 'normal':
      default:
        return isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    }
  }
}
