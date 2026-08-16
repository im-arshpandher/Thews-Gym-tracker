import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/presentation/widgets/interactive_body_map.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../ai_coach/presentation/widgets/ai_coach_overview_card.dart';
import '../../settings/domain/app_settings.dart';
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
        titleSpacing: 20,
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
            const SizedBox(width: 12),
            Text(
              'THEWS',
              style: AppTypography.headlineMd(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ).copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Athlete Profile & Trophies',
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? AppColors.primaryVolt
                      : AppColors.lightPrimary,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.person_outline,
                size: 20,
                color: isDark
                    ? AppColors.primaryVolt
                    : AppColors.lightPrimary,
              ),
            ),
            onPressed: () => context.push('/profile'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
        },
        color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header & Unique Streak Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome Back',
                          style: AppTypography.headlineLg(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(now),
                          style: AppTypography.labelCaps(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  statsAsync.maybeWhen(
                    data: (stats) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.primaryVolt
                                : AppColors.lightPrimary)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FireGradientIcon(size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${stats.streakDays} STREAK',
                            style: AppTypography.labelCaps(
                              color: isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary,
                            ).copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ],
                      ),
                    ),
                    orElse: () => const SizedBox(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Hero Primary Action Button: START WORKOUT LOG
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.primaryGlow,
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => context.go('/log'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryVolt,
                    foregroundColor: AppColors.primaryVoltOn,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.bolt,
                        size: 24,
                        color: AppColors.primaryVoltOn,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'START WORKOUT LOG',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryVoltOn,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Access Grid (2x2 Unique Shortcuts)
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      context,
                      icon: Icons.assignment_outlined,
                      title: 'ROUTINES',
                      subtitle: 'Workout Templates',
                      onTap: () => context.push('/routines'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickActionCard(
                      context,
                      icon: Icons.fitness_center_outlined,
                      title: 'EXERCISES',
                      subtitle: 'Library & Custom',
                      onTap: () => context.push('/exercises'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      context,
                      icon: Icons.directions_run_outlined,
                      title: 'GPS RUN',
                      subtitle: 'Outdoor Tracking',
                      onTap: () => context.go('/running'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickActionCard(
                      context,
                      icon: Icons.emoji_events_outlined,
                      title: 'CHALLENGES',
                      subtitle: 'Loop Routes & Trophies',
                      onTap: () => context.push('/challenges'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Distinct Live Stats Bento Grid
              statsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Weekly Target Bento Card
                      _buildBentoCard(
                        context,
                        title: 'WEEKLY WORKOUT TARGET',
                        icon: Icons.flag_outlined,
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
                              '/ ${stats.weeklyGoal} workouts',
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
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 10,
                                backgroundColor: isDark
                                    ? AppColors.darkSurfaceContainerHighest
                                    : AppColors.lightSurfaceContainerHigh,
                                color: isDark
                                    ? AppColors.primaryVolt
                                    : AppColors.lightPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(progress * 100).toInt()}% completed',
                                  style: AppTypography.bodySm(
                                    color: isDark
                                        ? AppColors.primaryVolt
                                        : AppColors.lightPrimary,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  settings.dailyCountingMode ==
                                          DailyWorkoutCountingMode.groupedByDay
                                      ? 'Mode: 1 per day'
                                      : 'Mode: Individual',
                                  style: AppTypography.bodySm(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ).copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Volume & Workout Time Bento Cards (Distinct non-redundant metrics)
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
                                  const SizedBox(height: 2),
                                  Text(
                                    'Lifetime lifted',
                                    style: AppTypography.bodySm(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
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
                              title: 'WORKOUT TIME',
                              icon: Icons.timer_outlined,
                              valueWidget: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatDuration(stats.totalTimeSeconds),
                                    style: AppTypography.headlineLg(
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${stats.totalWorkoutsCount} sessions logged',
                                    style: AppTypography.bodySm(
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
                      const SizedBox(height: 24),

                      // Single Muscle Target Heatmap Card
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
                      const SizedBox(height: 16),

                      // Redesigned AI Adaptive Coach Card (Relocated beneath Heatmap)
                      const AiCoachOverviewCard(),
                      const SizedBox(height: 28),

                      // Recent Activity Section
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
                              maxLines: 1,
                              softWrap: false,
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
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkOutline.withValues(alpha: 0.2)
                                  : AppColors.lightOutline
                                      .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.history_toggle_off,
                                  size: 40,
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
                                  'Tap START WORKOUT LOG above to log your first session!',
                                  style: AppTypography.bodySm(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                  textAlign: TextAlign.center,
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

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isDark
                      ? AppColors.primaryVolt
                      : AppColors.lightPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelCaps(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ).copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      softWrap: false,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySm(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ).copyWith(fontSize: 10),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
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
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              icon == Icons.local_fire_department
                  ? const FireGradientIcon(size: 20)
                  : Icon(
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
    final durationStr =
        _formatDuration((workout.durationSeconds as int?) ?? 0);

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                ? AppColors.primaryVolt
                : AppColors.lightPrimary,
          ),
        ),
        title: Text(
          workout.notes ?? 'Workout Session',
          style: AppTypography.bodyLg(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          maxLines: 1,
          softWrap: false,
        ),
        subtitle: Text(
          '$formattedDate • $durationStr',
          style: AppTypography.bodySm(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          maxLines: 1,
          softWrap: false,
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

class FireGradientIcon extends StatelessWidget {
  final double size;

  const FireGradientIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color(0xFFFF3D00), // Deep Fire Orange / Red
            Color(0xFFFF9100), // Fiery Orange
            Color(0xFFFFD600), // Glowing Yellow Flame Top
          ],
        ).createShader(bounds);
      },
      child: Icon(
        Icons.local_fire_department,
        size: size,
        color: Colors.white,
      ),
    );
  }
}
