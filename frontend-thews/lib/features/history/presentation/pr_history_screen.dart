import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/presentation/widgets/muscle_group_icon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../exercises/presentation/widgets/exercise_details_sheet.dart';

final allPRHistoryProvider = StreamProvider<List<ExercisePRSummary>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllExercises().asyncMap((exercises) async {
    final List<ExercisePRSummary> summaries = [];
    for (final ex in exercises) {
      final points = await db.watchExerciseProgressHistory(ex.id).first;
      if (points.isNotEmpty) {
        double maxWeight = 0;
        double max1RM = 0;
        double maxVolume = 0;
        DateTime? maxWeightDate;
        DateTime? max1RMDate;

        for (final p in points) {
          if (p.maxWeight > maxWeight) {
            maxWeight = p.maxWeight;
            maxWeightDate = p.date;
          }
          if (p.estimated1RM > max1RM) {
            max1RM = p.estimated1RM;
            max1RMDate = p.date;
          }
          if (p.totalVolume > maxVolume) {
            maxVolume = p.totalVolume;
          }
        }

        summaries.add(
          ExercisePRSummary(
            exercise: ex,
            maxWeight: maxWeight,
            max1RM: max1RM,
            maxVolume: maxVolume,
            maxWeightDate: maxWeightDate,
            max1RMDate: max1RMDate,
            sessionCount: points.length,
          ),
        );
      }
    }
    summaries.sort((a, b) => b.max1RM.compareTo(a.max1RM));
    return summaries;
  });
});

class ExercisePRSummary {
  final ExerciseData exercise;
  final double maxWeight;
  final double max1RM;
  final double maxVolume;
  final DateTime? maxWeightDate;
  final DateTime? max1RMDate;
  final int sessionCount;

  const ExercisePRSummary({
    required this.exercise,
    required this.maxWeight,
    required this.max1RM,
    required this.maxVolume,
    this.maxWeightDate,
    this.max1RMDate,
    required this.sessionCount,
  });
}

class PRHistoryScreen extends ConsumerWidget {
  const PRHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prAsync = ref.watch(allPRHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PERSONAL RECORDS',
          style: AppTypography.headlineMd(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: prAsync.when(
        data: (summaries) {
          if (summaries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      size: 64,
                      color: AppColors.primaryVolt,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Personal Records Recorded Yet',
                      style: AppTypography.headlineSm(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete workout sets to automatically detect and track your all-time weight, volume, and 1RM PR milestones!',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: summaries.length,
            itemBuilder: (context, index) {
              final summary = summaries[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () =>
                      ExerciseDetailsSheet.show(context, summary.exercise),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            MuscleGroupIcon(
                              muscleGroup: summary.exercise.muscleGroup,
                              size: 36,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    summary.exercise.name,
                                    style: AppTypography.headlineSm(
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${summary.sessionCount} sessions logged • ${summary.exercise.muscleGroup}',
                                    style: AppTypography.bodySm(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.emoji_events,
                              color: Colors.amber,
                              size: 28,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _PRBadgeTile(
                                label: 'MAX WEIGHT',
                                value:
                                    '${summary.maxWeight % 1 == 0 ? summary.maxWeight.toInt() : summary.maxWeight} kg',
                                icon: Icons.fitness_center,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PRBadgeTile(
                                label: 'EST. 1RM',
                                value:
                                    '${summary.max1RM.toStringAsFixed(1)} kg',
                                icon: Icons.trending_up,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PRBadgeTile(
                                label: 'MAX VOLUME',
                                value:
                                    '${summary.maxVolume % 1 == 0 ? summary.maxVolume.toInt() : summary.maxVolume.toStringAsFixed(0)} kg',
                                icon: Icons.bar_chart,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryVolt),
        ),
        error: (e, s) => Center(child: Text('Error loading PR history: $e')),
      ),
    );
  }
}

class _PRBadgeTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  const _PRBadgeTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerHigh
            : AppColors.lightSurfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.primaryVolt),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelCaps(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ).copyWith(fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyLg(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ).copyWith(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
