import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../challenges/domain/challenge_models.dart';
import '../../challenges/presentation/challenges_provider.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../workouts/presentation/dashboard_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final challengeState = ref.watch(challengesProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final settings = ref.watch(settingsProvider);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ATHLETE PROFILE',
          style: AppTypography.headlineMd(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ).copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.2),
          maxLines: 1,
          softWrap: false,
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: StreamBuilder<List<RunActivityData>>(
        stream: db.watchAllRunActivities(),
        builder: (context, runSnapshot) {
          final runActivities = runSnapshot.data ?? [];

          // Compute running totals
          double totalRunDistanceMeters = 0;
          double totalElevationGainMeters = 0;
          int totalRunDurationSeconds = 0;

          for (final run in runActivities) {
            totalRunDistanceMeters += run.distanceMeters;
            totalElevationGainMeters += run.elevationGainMeters;
            totalRunDurationSeconds += run.durationSeconds;
          }

          final totalRunDistanceKm = totalRunDistanceMeters / 1000.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Athlete Identity & Rank Card
                _buildAthleteIdentityCard(challengeState, isDark),
                const SizedBox(height: 20),

                // 2. Trophy Room & Showcase Section
                _buildTrophyShowcaseSection(
                  context,
                  challengeState.trophies,
                  isDark,
                ),
                const SizedBox(height: 24),

                // 3. Weekly Volume & Performance Charts (Strava-style)
                _buildPerformanceVolumeChart(
                  runActivities,
                  statsAsync.value?.recentWorkouts ?? [],
                  isDark,
                ),
                const SizedBox(height: 24),

                // 4. Lifetime Career Statistics & PRs
                _buildCareerStatsSection(
                  stats: statsAsync.value,
                  totalRunDistanceKm: totalRunDistanceKm,
                  totalElevationMeters: totalElevationGainMeters,
                  totalRunDurationSeconds: totalRunDurationSeconds,
                  weightUnit: settings.weightUnit.label,
                  isDark: isDark,
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAthleteIdentityCard(ChallengesState state, bool isDark) {
    final nextLevelXp = state.athleteLevel * 1000;
    final currentLevelBaseXp = (state.athleteLevel - 1) * 1000;
    final progressInLevel = ((state.totalXp - currentLevelBaseXp) /
            (nextLevelXp - currentLevelBaseXp))
        .clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.lightSurfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? AppColors.darkOutline : AppColors.lightOutline)
              .withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Glowing Avatar
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppColors.primaryVolt, Colors.cyan]
                        : [AppColors.lightPrimary, Colors.amber],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.primaryGlow,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: CircleAvatar(
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceContainerLowest
                        : Colors.white,
                    child: Icon(
                      Icons.fitness_center,
                      size: 32,
                      color: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name & Rank Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'THEWS ATHLETE',
                            style: AppTypography.headlineLg(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ).copyWith(fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryVolt.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.primaryVolt,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'PRO',
                            style: AppTypography.labelCaps(
                              color: AppColors.primaryVolt,
                            ).copyWith(fontWeight: FontWeight.w900, fontSize: 10),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${state.athleteRankTitle.toUpperCase()} • LVL ${state.athleteLevel}',
                      style: AppTypography.labelCaps(
                        color: isDark ? Colors.cyan : AppColors.lightPrimary,
                      ).copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      softWrap: false,
                    ),
                    const SizedBox(height: 6),
                    // Streak Pill
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ACTIVE TRAINING STREAK',
                          style: AppTypography.labelCaps(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // XP Level Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LEVEL ${state.athleteLevel}',
                style: AppTypography.labelCaps(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ).copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                softWrap: false,
              ),
              Text(
                '${state.totalXp} / $nextLevelXp XP',
                style: AppTypography.labelCaps(
                  color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                ).copyWith(fontWeight: FontWeight.w900),
                maxLines: 1,
                softWrap: false,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressInLevel,
              minHeight: 8,
              backgroundColor: isDark
                  ? AppColors.darkSurfaceContainerHighest
                  : AppColors.lightSurfaceContainerHigh,
              color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrophyShowcaseSection(
    BuildContext context,
    List<TrophyBadge> trophies,
    bool isDark,
  ) {
    final unlockedCount = trophies.where((t) => t.isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 22),
                const SizedBox(width: 8),
                Text(
                  'TROPHY CASE',
                  style: AppTypography.headlineMd(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ).copyWith(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  softWrap: false,
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Text(
                '$unlockedCount / ${trophies.length} UNLOCKED',
                style: AppTypography.labelCaps(color: Colors.amber)
                    .copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Grid of Trophies
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: trophies.length,
          itemBuilder: (context, index) {
            final trophy = trophies[index];
            return _buildTrophyItem(context, trophy, isDark);
          },
        ),
      ],
    );
  }

  Widget _buildTrophyItem(
    BuildContext context,
    TrophyBadge trophy,
    bool isDark,
  ) {
    final tierColor = _getTrophyColor(trophy.tier);
    final isUnlocked = trophy.isUnlocked;

    return GestureDetector(
      onTap: () => _showTrophyDetailDialog(context, trophy, isDark),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isUnlocked
              ? (isDark
                  ? AppColors.darkSurfaceContainerLow
                  : AppColors.lightSurfaceContainerLowest)
              : (isDark
                  ? AppColors.darkSurfaceContainerLowest.withValues(alpha: 0.4)
                  : AppColors.lightSurfaceContainerLow.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked
                ? tierColor.withValues(alpha: 0.6)
                : (isDark ? AppColors.darkOutline : AppColors.lightOutline)
                    .withValues(alpha: 0.2),
            width: isUnlocked ? 1.5 : 1.0,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: tierColor.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnlocked
                    ? tierColor.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.1),
                border: Border.all(
                  color: isUnlocked ? tierColor : Colors.grey.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                isUnlocked ? Icons.emoji_events : Icons.lock_outline,
                size: 24,
                color: isUnlocked ? tierColor : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              trophy.title,
              style: AppTypography.labelCaps(
                color: isUnlocked
                    ? (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary)
                    : Colors.grey,
              ).copyWith(
                fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              trophy.tier.label,
              style: AppTypography.labelCaps(
                color: isUnlocked ? tierColor : Colors.grey,
              ).copyWith(fontSize: 8, fontWeight: FontWeight.w800),
              maxLines: 1,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }

  void _showTrophyDetailDialog(
    BuildContext context,
    TrophyBadge trophy,
    bool isDark,
  ) {
    final tierColor = _getTrophyColor(trophy.tier);
    final isUnlocked = trophy.isUnlocked;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.lightSurfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnlocked
                    ? tierColor.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.1),
                border: Border.all(
                  color: isUnlocked ? tierColor : Colors.grey,
                  width: 2,
                ),
                boxShadow: isUnlocked
                    ? [
                        BoxShadow(
                          color: tierColor.withValues(alpha: 0.3),
                          blurRadius: 20,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isUnlocked ? Icons.emoji_events : Icons.lock,
                size: 44,
                color: isUnlocked ? tierColor : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              trophy.title,
              style: AppTypography.headlineLg(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ).copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${trophy.tier.label} TROPHY • +${trophy.xpReward} XP',
                style: AppTypography.labelCaps(color: tierColor)
                    .copyWith(fontWeight: FontWeight.w900),
                maxLines: 1,
                softWrap: false,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              trophy.description,
              style: AppTypography.bodyMd(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (isUnlocked && trophy.unlockedAt != null)
              Text(
                'UNLOCKED ON ${_formatDate(trophy.unlockedAt!)}',
                style: AppTypography.labelCaps(
                  color: isDark
                      ? AppColors.primaryVolt
                      : AppColors.lightPrimary,
                ).copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                softWrap: false,
              )
            else
              Text(
                'COMPLETE THIS CHALLENGE TO UNLOCK',
                style: AppTypography.labelCaps(color: Colors.grey),
                maxLines: 1,
                softWrap: false,
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                  foregroundColor: AppColors.primaryVoltOn,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'CLOSE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceVolumeChart(
    List<RunActivityData> runs,
    List<WorkoutData> workouts,
    bool isDark,
  ) {
    // Generate 7-day volume metrics for Monday through Sunday
    final now = DateTime.now();
    final mondayOfThisWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final dayDistances = List.generate(7, (i) => 0.0);

    for (final run in runs) {
      final diff = run.startTime.difference(mondayOfThisWeek).inDays;
      if (diff >= 0 && diff < 7) {
        dayDistances[diff] += (run.distanceMeters / 1000.0);
      }
    }

    final barGroups = List.generate(7, (i) {
      final runKm = dayDistances[i];

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: runKm > 0 ? runKm : 0.2,
            color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
            width: 14,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.lightSurfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? AppColors.darkOutline : AppColors.lightOutline)
              .withValues(alpha: 0.3),
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
                  'WEEKLY ACTIVITY VOLUME',
                  style: AppTypography.headlineMd(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ).copyWith(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'RUN (KM)',
                    style: AppTypography.labelCaps(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: 15.0,
                barGroups: barGroups,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: (isDark
                            ? AppColors.darkOutline
                            : AppColors.lightOutline)
                        .withValues(alpha: 0.15),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.toInt()}k',
                        style: AppTypography.labelCaps(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ).copyWith(fontSize: 9),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < 7) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              dayLabels[idx],
                              style: AppTypography.labelCaps(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareerStatsSection({
    required DashboardStats? stats,
    required double totalRunDistanceKm,
    required double totalElevationMeters,
    required int totalRunDurationSeconds,
    required String weightUnit,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CAREER TOTALS & RECORDS',
          style: AppTypography.headlineMd(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ).copyWith(fontWeight: FontWeight.w900),
          maxLines: 1,
          softWrap: false,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'TOTAL RUN DISTANCE',
                value: '${totalRunDistanceKm.toStringAsFixed(1)} KM',
                icon: Icons.directions_run,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'ELEVATION CLIMBED',
                value: '${totalElevationMeters.toStringAsFixed(0)} M',
                icon: Icons.landscape,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'IRON TONNAGE LIFTED',
                value: stats != null
                    ? '${(stats.totalVolume / 1000).toStringAsFixed(1)}k $weightUnit'
                    : '0 $weightUnit',
                icon: Icons.fitness_center,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'SESSIONS COMPLETED',
                value: '${(stats?.totalWorkoutsCount ?? 0)} WORKOUTS',
                icon: Icons.check_circle_outline,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.lightSurfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppColors.darkOutline : AppColors.lightOutline)
              .withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.labelCaps(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ).copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.headlineMd(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ).copyWith(fontWeight: FontWeight.w900),
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
    );
  }

  Color _getTrophyColor(TrophyTier tier) {
    switch (tier) {
      case TrophyTier.bronze:
        return const Color(0xFFCD7F32);
      case TrophyTier.silver:
        return const Color(0xFFCBD5E1);
      case TrophyTier.gold:
        return const Color(0xFFFFD700);
      case TrophyTier.diamond:
        return const Color(0xFF38BDF8);
    }
  }

  String _formatDate(DateTime dt) {
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
