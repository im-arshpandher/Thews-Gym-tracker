import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/ai_coach_models.dart';
import '../ai_coach_provider.dart';

/// Redesigned cybernetic glassmorphic card displaying real-time systemic readiness,
/// recommended workout split, and muscle recovery status.
class AiCoachOverviewCard extends ConsumerWidget {
  const AiCoachOverviewCard({super.key});

  Color _getScoreColor(double score, bool isDark) {
    if (score >= 80.0) {
      return isDark ? AppColors.primaryVolt : AppColors.lightPrimary;
    }
    if (score >= 50.0) return Colors.amber;
    return AppColors.error;
  }

  Color _getTierColor(ReadinessTier tier, bool isDark) {
    switch (tier) {
      case ReadinessTier.optimal:
        return isDark ? AppColors.primaryVolt : AppColors.lightPrimary;
      case ReadinessTier.moderate:
        return Colors.amber;
      case ReadinessTier.fatigued:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final coachStateAsync = ref.watch(systemicCoachStateProvider);

    return coachStateAsync.when(
      data: (state) => _buildContent(context, state, isDark),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildContent(
    BuildContext context,
    SystemicCoachState state,
    bool isDark,
  ) {
    final scoreColor = _getScoreColor(state.overallReadinessScore, isDark);
    final voltColor = isDark ? AppColors.primaryVolt : AppColors.lightPrimary;

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.lightSurfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? AppColors.darkOutline : AppColors.lightOutline)
              .withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cybernetic Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: voltColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: voltColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(Icons.auto_awesome, size: 14, color: voltColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI ADAPTIVE COACH',
                    style: AppTypography.headlineMd(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ).copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              ),
              if (state.deloadAdvised)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 12, color: AppColors.error),
                      const SizedBox(width: 4),
                      Text(
                        'DELOAD ADVISED',
                        style: AppTypography.labelCaps(
                          color: AppColors.error,
                        ).copyWith(fontWeight: FontWeight.bold, fontSize: 10),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    state.overallReadinessScore >= 80 ? 'PEAK READINESS' : 'OPTIMAL',
                    style: AppTypography.labelCaps(color: scoreColor).copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Readiness Ring & Today's Optimal Focus
          Row(
            children: [
              // Radial Gauge
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? AppColors.darkSurfaceContainerLowest
                      : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: scoreColor.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 68,
                      height: 68,
                      child: CircularProgressIndicator(
                        value: state.overallReadinessScore / 100.0,
                        backgroundColor: (isDark
                                ? AppColors.darkSurfaceContainerHighest
                                : AppColors.lightSurfaceContainerHigh)
                            .withValues(alpha: 0.5),
                        color: scoreColor,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${state.overallReadinessScore.toInt()}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: scoreColor,
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                        Text(
                          'READY',
                          style: AppTypography.labelCaps(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ).copyWith(fontSize: 7, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Focus recommendation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECOMMENDED TRAINING FOCUS',
                      style: AppTypography.labelCaps(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ).copyWith(fontSize: 9),
                      maxLines: 1,
                      softWrap: false,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.recommendedSplit,
                      style: AppTypography.headlineMd(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ).copyWith(fontWeight: FontWeight.w900, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      state.splitRationale,
                      style: AppTypography.bodySm(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Muscle Group Recovery Chips
          Text(
            'MUSCLE GROUP READINESS STATUS',
            style: AppTypography.labelCaps(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ).copyWith(fontSize: 9),
            maxLines: 1,
            softWrap: false,
          ),
          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: state.muscleReadiness.map((m) {
                final tierColor = _getTierColor(m.tier, isDark);
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainerLowest
                        : AppColors.lightSurfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: tierColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: tierColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        m.muscleGroup,
                        style: AppTypography.labelCaps(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ).copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        softWrap: false,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${m.recoveryPercentage.toInt()}%',
                        style: AppTypography.labelCaps(color: tierColor)
                            .copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
