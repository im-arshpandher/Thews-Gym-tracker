import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class InteractiveBodyMap extends StatelessWidget {
  final String selectedMuscleGroup;
  final ValueChanged<String>? onSelectMuscleGroup;

  const InteractiveBodyMap({
    super.key,
    this.selectedMuscleGroup = 'All',
    this.onSelectMuscleGroup,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final muscles = [
      {'name': 'Chest', 'icon': Icons.shield_outlined},
      {'name': 'Back', 'icon': Icons.waves_outlined},
      {'name': 'Legs', 'icon': Icons.directions_run_outlined},
      {'name': 'Shoulders', 'icon': Icons.accessibility_new_outlined},
      {'name': 'Biceps', 'icon': Icons.fitness_center_outlined},
      {'name': 'Triceps', 'icon': Icons.hardware_outlined},
      {'name': 'Forearms', 'icon': Icons.pan_tool_outlined},
      {'name': 'Core / Abs', 'icon': Icons.crop_portrait_outlined},
      {'name': 'Neck', 'icon': Icons.person_outline},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainer
            : AppColors.lightSurfaceContainerLow,
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
              Row(
                children: [
                  Icon(
                    Icons.accessibility_new,
                    color: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'MUSCLE TARGET HEATMAP',
                    maxLines: 1,
                    softWrap: false,
                    style: AppTypography.labelCaps(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              InkWell(
                onTap: () => context.push('/visualizer'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'FULL PAGE',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.primaryVolt
                              : AppColors.lightPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: isDark
                            ? AppColors.primaryVolt
                            : AppColors.lightPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: muscles.map((m) {
              final String name = m['name'] as String;
              final IconData icon = m['icon'] as IconData;
              final Color accentColor = AppColors.getMuscleGroupColor(name);
              final isSelected =
                  selectedMuscleGroup.toLowerCase() == name.toLowerCase();

              return InkWell(
                onTap: () => onSelectMuscleGroup?.call(name),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: isDark ? 0.35 : 0.2)
                        : (isDark
                              ? AppColors.darkSurfaceContainerHigh
                              : AppColors.lightSurfaceContainerHighest),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? accentColor : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: accentColor),
                      const SizedBox(width: 6),
                      Text(
                        name.toUpperCase(),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? (isDark ? Colors.white : accentColor)
                              : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
