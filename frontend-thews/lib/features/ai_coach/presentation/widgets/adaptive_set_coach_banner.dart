import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/ai_coach_models.dart';
import '../ai_coach_provider.dart';

/// In-session adaptive target coach banner displayed inside ExerciseCardWidget.
class AdaptiveSetCoachBanner extends ConsumerWidget {
  final int exerciseId;
  final String weightUnit;
  final void Function(double weight, int reps) onApplyTarget;

  const AdaptiveSetCoachBanner({
    super.key,
    required this.exerciseId,
    required this.weightUnit,
    required this.onApplyTarget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final overloadAsync = ref.watch(exerciseOverloadProvider(exerciseId));

    return overloadAsync.when(
      data: (rec) => _buildBanner(context, rec, isDark),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildBanner(
    BuildContext context,
    OverloadRecommendation rec,
    bool isDark,
  ) {
    final isDeload = rec.isDeload;
    final accentColor = isDeload
        ? AppColors.error
        : (isDark ? AppColors.primaryVolt : AppColors.lightPrimary);
    final secondaryText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon & Target Label
          Icon(
            isDeload ? Icons.battery_charging_full : Icons.auto_awesome,
            size: 16,
            color: accentColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'AI COACH TARGET: ',
                      maxLines: 1,
                      softWrap: false,
                      style: AppTypography.labelCaps(color: accentColor).copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rec.formattedTarget(weightUnit),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: AppTypography.labelCaps(
                          color: isDark ? Colors.white : Colors.black87,
                        ).copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  rec.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: AppTypography.bodySm(color: secondaryText).copyWith(
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // One-tap Apply Button
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              HapticFeedback.lightImpact();
              onApplyTarget(rec.recommendedWeight, rec.recommendedReps);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.4),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Apply Target',
                  maxLines: 1,
                  softWrap: false,
                  style: AppTypography.labelCaps(color: accentColor).copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
