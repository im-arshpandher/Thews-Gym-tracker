import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/smartwatch_models.dart';
import '../../../../core/services/smartwatch_sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class LiveHeartRateHud extends ConsumerStatefulWidget {
  final bool compact;
  const LiveHeartRateHud({super.key, this.compact = false});

  @override
  ConsumerState<LiveHeartRateHud> createState() => _LiveHeartRateHudState();
}

class _LiveHeartRateHudState extends ConsumerState<LiveHeartRateHud>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.90, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final watchState = ref.watch(smartwatchServiceProvider);
    final isConnected = watchState.status == SmartwatchConnectionStatus.connected;
    final bpm = watchState.currentBpm;
    final zone = watchState.currentZone;
    final calories = watchState.activeCaloriesBurned;

    // Adjust pulse speed according to heart rate
    if (bpm > 0) {
      final pulseMs = (60000 / bpm).round().clamp(350, 1200);
      if (_pulseController.duration?.inMilliseconds != pulseMs) {
        _pulseController.duration = Duration(milliseconds: pulseMs);
      }
    }

    if (!isConnected) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainer
              : AppColors.lightSurfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? AppColors.darkOutline.withValues(alpha: 0.2)
                : AppColors.lightOutline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.watch_outlined,
              size: 20,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Smartwatch Companion Offline',
                style: AppTypography.bodySm(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                ref
                    .read(smartwatchServiceProvider.notifier)
                    .connectSmartwatch(simulated: true);
              },
              icon: const Icon(Icons.link, size: 16),
              label: const Text('Connect', maxLines: 1, softWrap: false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainer
            : AppColors.lightSurfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: zone.color.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: zone.color.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pulsing Heart Icon
          ScaleTransition(
            scale: _pulseAnimation,
            child: Icon(
              Icons.favorite,
              color: bpm > 0 ? zone.color : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),

          // BPM Display
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    bpm > 0 ? '$bpm' : '--',
                    style: AppTypography.cardTitle(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'BPM',
                    style: AppTypography.labelCaps(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ).copyWith(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Zone Badge
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: zone.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: zone.color.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: zone.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      zone.name,
                      style: AppTypography.labelCaps(
                        color: isDark ? zone.color : zone.color,
                      ).copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Active Calories
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department,
                size: 16,
                color: Colors.deepOrangeAccent,
              ),
              const SizedBox(width: 3),
              Text(
                '${calories.toStringAsFixed(0)} kcal',
                style: AppTypography.bodySm(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ).copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                softWrap: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
