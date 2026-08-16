import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/ai_coach_models.dart';
import '../ai_coach_provider.dart';

/// Dashboard card displaying real-time systemic readiness score,
/// daily workout split recommendation, and muscle group recovery status.
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
    final cardBg = isDark
        ? AppColors.darkSurfaceContainerLow
        : AppColors.lightSurfaceContainerLow;
    final borderColor = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final secondaryText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: voltColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: voltColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AI ADAPTIVE COACH',
                      maxLines: 1,
                      softWrap: false,
                      style: AppTypography.labelCaps(color: voltColor).copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (state.deloadAdvised)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'DELOAD ADVISED',
                    maxLines: 1,
                    softWrap: false,
                    style: AppTypography.labelCaps(color: AppColors.error).copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Readiness Ring & Daily Split Suggestion
          Row(
            children: [
              // Circular Readiness Gauge
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: CircularProgressIndicator(
                      value: state.overallReadinessScore / 100.0,
                      backgroundColor: isDark
                          ? AppColors.darkSurfaceContainerHighest
                          : Colors.grey.shade200,
                      color: scoreColor,
                      strokeWidth: 5.5,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${state.overallReadinessScore.toInt()}%',
                          maxLines: 1,
                          softWrap: false,
                          style: AppTypography.cardTitle(color: scoreColor).copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        'READINESS',
                        maxLines: 1,
                        softWrap: false,
                        style: AppTypography.labelCaps(color: secondaryText).copyWith(
                          fontSize: 7,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Recommended Daily Split Focus
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY\'S OPTIMAL FOCUS',
                      maxLines: 1,
                      softWrap: false,
                      style: AppTypography.labelCaps(color: secondaryText).copyWith(
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.recommendedSplit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: AppTypography.cardTitle().copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.splitRationale,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm(color: secondaryText).copyWith(
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(height: 1, color: borderColor.withValues(alpha: 0.2)),
          const SizedBox(height: 10),

          // Muscle Group Recovery Chips
          Text(
            'MUSCLE GROUP READINESS',
            maxLines: 1,
            softWrap: false,
            style: AppTypography.labelCaps(color: secondaryText).copyWith(
              fontSize: 10,
            ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainer
                        : AppColors.lightSurfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tierColor.withValues(alpha: 0.3),
                      width: 1,
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
                        maxLines: 1,
                        softWrap: false,
                        style: AppTypography.labelCaps().copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${m.recoveryPercentage.toInt()}%',
                        maxLines: 1,
                        softWrap: false,
                        style: AppTypography.labelCaps(color: tierColor).copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Alert banner if any
          if (state.alerts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.alerts.first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: AppTypography.bodySm(color: Colors.amber).copyWith(
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
