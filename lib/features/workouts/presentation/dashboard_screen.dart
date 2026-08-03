import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/presentation/widgets/interactive_body_map.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../settings/presentation/settings_provider.dart';
import 'dashboard_provider.dart';
import 'muscle_visualization_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _formatDate(DateTime dt) {
    final months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final weekdays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    final dayName = weekdays[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    return '$dayName, $monthName ${dt.day}';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0m';
    final mins = seconds ~/ 60;
    if (mins < 60) return '${mins}m';
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    return '${hrs}h ${remMins}m';
  }

  String _formatVolume(double totalVolume, String unit) {
    if (totalVolume >= 1000) {
      return '${(totalVolume / 1000).toStringAsFixed(1)}k $unit';
    }
    return '${totalVolume.toStringAsFixed(0)} $unit';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statsAsync = ref.watch(dashboardStatsProvider);
    final settings = ref.watch(settingsProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                isDark
                    ? 'assets/images/thews_app_icon_dark.png'
                    : 'assets/images/thews_app_icon_light.png',
                width: 32,
                height: 32,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'THEWS',
              style: AppTypography.headlineMd(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ).copyWith(letterSpacing: 1.2),
            ),
          ],
        ),
        // Req 2: Remove the theme change icon on top (theme change only through settings)
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
        },
        color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Text(
                'Welcome Back',
                style: AppTypography.headlineLg(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(now),
                style: AppTypography.labelCaps(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Start Workout Primary Action Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.primaryGlow,
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => context.go('/log'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryVolt,
                    foregroundColor: AppColors.primaryVoltOn,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.bolt,
                        size: 20,
                        color: AppColors.primaryVoltOn,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LOG WORKOUT',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryVoltOn,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Routine Templates Shortcut (Phase 2 & 3)
              OutlinedButton.icon(
                onPressed: () => context.push('/routines'),
                icon: Icon(
                  Icons.assignment_outlined,
                  color: isDark
                      ? AppColors.primaryVolt
                      : AppColors.lightPrimary,
                ),
                label: Text(
                  'VIEW WORKOUT ROUTINES & TEMPLATES',
                  style: AppTypography.labelCaps(
                    color: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 44),
                  side: BorderSide(
                    color:
                        (isDark
                                ? AppColors.primaryVolt
                                : AppColors.lightPrimary)
                            .withValues(alpha: 0.5),
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Live Quick Stats Bento Grid (Req 5, Req 6, Req 7)
              statsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(
                      color: AppColors.primaryVolt,
                    ),
                  ),
                ),
                error: (err, stack) => Center(
                  child: Text(
                    'Error loading stats: $err',
                    style: AppTypography.bodyMd(color: AppColors.error),
                  ),
                ),
                data: (stats) {
                  final progress = (stats.workoutsThisWeek / stats.weeklyGoal)
                      .clamp(0.0, 1.0);

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildBentoCard(
                              context,
                              title: 'WORKOUTS THIS WEEK',
                              icon: Icons.fitness_center,
                              valueWidget: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${stats.workoutsThisWeek}',
                                    style: AppTypography.displayMetrics(
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '/ ${stats.weeklyGoal}',
                                    style: AppTypography.headlineMd(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              bottomWidget: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 8,
                                      backgroundColor: isDark
                                          ? AppColors
                                                .darkSurfaceContainerHighest
                                          : AppColors.lightSurfaceContainerHigh,
                                      color: isDark
                                          ? AppColors.primaryVolt
                                          : AppColors.lightPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${(progress * 100).toInt()}% of weekly target (${settings.weeklyGoal} workouts)',
                                    style:
                                        AppTypography.bodySm(
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ).copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildBentoCard(
                              context,
                              title: 'TOTAL VOLUME',
                              icon: Icons.bar_chart,
                              valueWidget: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatVolume(
                                      stats.totalVolume,
                                      settings.weightUnit.label,
                                    ),
                                    style: AppTypography.headlineLg(
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildBentoCard(
                              context,
                              title: 'STREAK',
                              icon: Icons.local_fire_department,
                              valueWidget: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${stats.streakDays}',
                                    style: AppTypography.headlineLg(
                                      color: isDark
                                          ? AppColors.primaryVoltDim
                                          : AppColors.lightPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Days',
                                    style: AppTypography.bodyMd(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Interactive Muscle Target Visualizer (Phase 3.4)
                      InteractiveBodyMap(
                        onSelectMuscleGroup: (group) {
                          ref
                                  .read(
                                    selectedVisualizationMuscleProvider
                                        .notifier,
                                  )
                                  .state =
                              group;
                          context.push('/visualizer');
                        },
                      ),

                      const SizedBox(height: 28),

                      // Recent Activity Section with Live Local Workouts
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Activity',
                            style: AppTypography.headlineMd(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/history'),
                            child: Text(
                              'VIEW ALL',
                              style: AppTypography.labelCaps(
                                color: isDark
                                    ? AppColors.primaryVoltDim
                                    : AppColors.lightPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (stats.recentWorkouts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceContainer
                                : AppColors.lightSurfaceContainerLowest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.history_toggle_off,
                                  size: 36,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No workouts logged yet',
                                  style: AppTypography.bodyLg(
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap Log Workout above to start your first session!',
                                  style: AppTypography.bodySm(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...stats.recentWorkouts.map(
                          (workout) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildActivityItem(
                              context,
                              workout: workout,
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

  Widget _buildBentoCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget valueWidget,
    Widget? bottomWidget,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainer
            : AppColors.lightSurfaceContainerLowest,
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
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelCaps(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ).copyWith(fontSize: 11),
                ),
              ),
              Icon(
                icon,
                color: isDark
                    ? AppColors.primaryVoltDim
                    : AppColors.lightPrimary,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 14),
          valueWidget,
          if (bottomWidget != null) ...[
            const SizedBox(height: 14),
            bottomWidget,
          ],
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context, {
    required WorkoutData workout,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = _formatDate(workout.date);
    final durationStr = _formatDuration(workout.durationSeconds);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceContainerHighest
                : AppColors.lightSurfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.fitness_center,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        title: Text(
          workout.notes ?? 'Workout Session',
          style: AppTypography.bodyLg(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        subtitle: Text(
          '$formattedDate • $durationStr',
          style: AppTypography.bodySm(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.darkOutlineVariant,
        ),
        onTap: () => context.go('/history'),
      ),
    );
  }
}
