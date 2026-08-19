import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/interference_optimizer.dart';
import '../domain/unified_readiness_engine.dart';
import 'hybrid_readiness_provider.dart';

class HybridReadinessDashboardCard extends ConsumerWidget {
  const HybridReadinessDashboardCard({super.key});

  Color _getTierColor(HybridReadinessTier tier, bool isDark) {
    switch (tier) {
      case HybridReadinessTier.prime:
        return isDark ? AppColors.primaryVolt : const Color(0xFF00C853);
      case HybridReadinessTier.optimal:
        return const Color(0xFF00E5FF); // Electric Cyan
      case HybridReadinessTier.fatigued:
        return const Color(0xFFFFD600); // Amber Yellow
      case HybridReadinessTier.overreached:
        return const Color(0xFFFF1744); // Crimson Red
    }
  }

  String _getTierName(HybridReadinessTier tier) {
    switch (tier) {
      case HybridReadinessTier.prime:
        return 'PRIME';
      case HybridReadinessTier.optimal:
        return 'OPTIMAL';
      case HybridReadinessTier.fatigued:
        return 'FATIGUED';
      case HybridReadinessTier.overreached:
        return 'OVERREACHED';
    }
  }

  void _showBreakdownSheet(BuildContext context, HybridReadinessMetrics metrics, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _HybridBreakdownModalSheet(metrics: metrics, isDark: isDark),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final readinessAsync = ref.watch(hybridReadinessProvider);

    return readinessAsync.when(
      data: (metrics) {
        final tierColor = _getTierColor(metrics.tier, isDark);
        final tierLabel = _getTierName(metrics.tier);

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceContainerHigh
                : AppColors.lightSurfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: tierColor.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _showBreakdownSheet(context, metrics, isDark),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: tierColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.flash_on_rounded,
                                color: tierColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HYBRID ATHLETE ENGINE',
                                  style: AppTypography.labelCaps(
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ).copyWith(fontSize: 12, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  'STRENGTH + CARDIO READINESS',
                                  style: AppTypography.tinyLabel(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ).copyWith(fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Readiness Tier Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            tierLabel,
                            style: AppTypography.tinyLabel(color: tierColor)
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Readiness Score Hero & Daily Focus
                    Row(
                      children: [
                        // Circular Readiness Gauge
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: CircularProgressIndicator(
                                value: metrics.overallScore / 100.0,
                                strokeWidth: 6,
                                backgroundColor: isDark
                                    ? AppColors.darkOutline.withValues(alpha: 0.3)
                                    : AppColors.lightOutline.withValues(alpha: 0.3),
                                valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${metrics.overallScore}',
                                  style: AppTypography.cardTitle(
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ).copyWith(fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  'SCORE',
                                  style: AppTypography.tinyLabel(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ).copyWith(fontSize: 8),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(width: 14),

                        // Prescribed Training Focus
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SUGGESTED FOCUS TODAY',
                                style: AppTypography.tinyLabel(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ).copyWith(fontSize: 9),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                metrics.suggestedTrainingFocus,
                                style: AppTypography.cardTitle(
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ).copyWith(fontSize: 13, fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                metrics.primaryRecommendation,
                                style: AppTypography.bodySm(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ).copyWith(fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // 7-Day Hybrid Volume Matrix Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.darkSurfaceContainerHighest
                                : AppColors.lightSurfaceContainerLow)
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkOutline.withValues(alpha: 0.25)
                              : AppColors.lightOutline.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _volumeMetric(
                            label: '7D STRENGTH',
                            value: metrics.weeklyLiftingTonnageKg >= 1000
                                ? '${(metrics.weeklyLiftingTonnageKg / 1000).toStringAsFixed(1)}k kg'
                                : '${metrics.weeklyLiftingTonnageKg.toInt()} kg',
                            subValue: '${metrics.weeklyLiftingWorkoutsCount} sessions',
                            color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                            isDark: isDark,
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
                          ),
                          _volumeMetric(
                            label: '7D RUNNING',
                            value: '${metrics.weeklyRunningDistanceKm.toStringAsFixed(1)} km',
                            subValue: '${metrics.weeklyRunningActivitiesCount} runs',
                            color: const Color(0xFF00E5FF),
                            isDark: isDark,
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
                          ),
                          _volumeMetric(
                            label: 'FATIGUE LOAD',
                            value: '${metrics.neuromuscularFatiguePct.toInt()}%',
                            subValue: 'Decay 24h',
                            color: metrics.neuromuscularFatiguePct > 40
                                ? const Color(0xFFFFD600)
                                : const Color(0xFF00E676),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // mTOR vs. AMPK Signaling Window Indicator Pill
                    _buildInterferencePill(metrics.interferenceResult, isDark),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }

  Widget _volumeMetric({
    required String label,
    required String value,
    required String subValue,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.tinyLabel(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ).copyWith(fontSize: 8),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.cardTitle(color: color)
              .copyWith(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Text(
          subValue,
          style: AppTypography.tinyLabel(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ).copyWith(fontSize: 8),
        ),
      ],
    );
  }

  Widget _buildInterferencePill(InterferenceAdvisorResult result, bool isDark) {
    Color bg;
    Color border;
    IconData icon;

    switch (result.riskLevel) {
      case InterferenceRiskLevel.minimal:
        bg = const Color(0xFF00E676).withValues(alpha: 0.12);
        border = const Color(0xFF00E676).withValues(alpha: 0.35);
        icon = Icons.verified_user_rounded;
        break;
      case InterferenceRiskLevel.moderate:
        bg = const Color(0xFFFFD600).withValues(alpha: 0.12);
        border = const Color(0xFFFFD600).withValues(alpha: 0.35);
        icon = Icons.info_outline_rounded;
        break;
      case InterferenceRiskLevel.high:
        bg = const Color(0xFFFF1744).withValues(alpha: 0.15);
        border = const Color(0xFFFF1744).withValues(alpha: 0.4);
        icon = Icons.warning_amber_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: border.withValues(alpha: 1.0)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${result.title} • Tap for biological breakdown',
              style: AppTypography.tinyLabel(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ).copyWith(fontSize: 10, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 14,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ],
      ),
    );
  }
}

/// Detailed Biological Modal Breakdown Sheet
class _HybridBreakdownModalSheet extends StatelessWidget {
  final HybridReadinessMetrics metrics;
  final bool isDark;

  const _HybridBreakdownModalSheet({
    required this.metrics,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final interference = metrics.interferenceResult;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerHighest
            : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sheet Title
            Row(
              children: [
                const Icon(Icons.biotech_rounded, color: AppColors.primaryVolt, size: 22),
                const SizedBox(width: 8),
                Text(
                  'HYBRID BIO-MECHANICS & READINESS',
                  style: AppTypography.sectionTitle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ).copyWith(fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Biochemical Interference Analysis Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkSurfaceContainerLow : AppColors.lightSurfaceContainerLow),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        interference.riskLevel == InterferenceRiskLevel.high
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        color: interference.riskLevel == InterferenceRiskLevel.high
                            ? const Color(0xFFFF1744)
                            : (isDark ? AppColors.primaryVolt : AppColors.lightPrimary),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          interference.title,
                          style: AppTypography.cardTitle(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ).copyWith(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    interference.summary,
                    style: AppTypography.bodySm(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ).copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'MOLECULAR MECHANISM (mTOR vs AMPK):',
                    style: AppTypography.tinyLabel(color: AppColors.primaryVolt)
                        .copyWith(fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    interference.biochemicalExplanation,
                    style: AppTypography.bodySm(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ).copyWith(fontSize: 11),
                  ),
                  if (interference.recommendedRunDelay.inMinutes > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryVolt.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '⏱️ Cooldown Remaining: ${interference.recommendedRunDelay.inHours}h ${interference.recommendedRunDelay.inMinutes % 60}m',
                        style: AppTypography.tinyLabel(
                          color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Systemic Strain Breakdown
            Text(
              'RECOVERY BREAKDOWN',
              style: AppTypography.labelCaps(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),

            _breakdownRow(
              'Neuromuscular Fatigue',
              '${metrics.neuromuscularFatiguePct.toInt()}%',
              (100.0 - metrics.neuromuscularFatiguePct) / 100.0,
              isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
            ),
            const SizedBox(height: 8),
            _breakdownRow(
              'Cardiovascular Strain',
              '${metrics.cardiovascularStrainPct.toInt()}%',
              (100.0 - metrics.cardiovascularStrainPct) / 100.0,
              const Color(0xFF00E5FF),
            ),

            const SizedBox(height: 20),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                  foregroundColor: isDark ? AppColors.primaryVoltOn : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('GOT IT', maxLines: 1, softWrap: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, String value, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.tinyLabel(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            Text(
              value,
              style: AppTypography.tinyLabel(color: color)
                  .copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: isDark ? AppColors.darkOutline : AppColors.lightOutline,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
