import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class AnatomicalBodyPainterWidget extends StatelessWidget {
  final Map<String, int> muscleSetCounts;
  final String selectedMuscleGroup;
  final ValueChanged<String> onSelectMuscleGroup;

  const AnatomicalBodyPainterWidget({
    super.key,
    required this.muscleSetCounts,
    required this.selectedMuscleGroup,
    required this.onSelectMuscleGroup,
  });

  Color _getMuscleColor(String muscleName, bool isDark) {
    final sets = muscleSetCounts[muscleName] ?? 0;
    if (sets == 0) {
      return isDark
          ? AppColors.darkSurfaceContainerHigh
          : AppColors.lightSurfaceContainerLow;
    } else if (sets < 6) {
      return Colors.amber.shade700.withValues(alpha: 0.7);
    } else if (sets <= 14) {
      return Colors.cyan.shade600;
    } else {
      return AppColors.primaryVolt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final muscleList = [
      {'name': 'Chest', 'label': 'CHEST'},
      {'name': 'Back', 'label': 'BACK'},
      {'name': 'Legs', 'label': 'LEGS'},
      {'name': 'Shoulders', 'label': 'SHOULDERS'},
      {'name': 'Arms', 'label': 'ARMS'},
      {'name': 'Core', 'label': 'CORE'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
        children: [
          // Visual Figure Canvas Container
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Anatomical Silhouette Graphic Background
                CustomPaint(
                  size: const Size(260, 180),
                  painter: _AnatomicalSilhouettePainter(
                    isDark: isDark,
                    selectedMuscleGroup: selectedMuscleGroup,
                    muscleColors: {
                      for (final m in muscleList)
                        m['name']!: _getMuscleColor(m['name']!, isDark),
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Interactive Heatmap Chips Selection Row
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: muscleList.map((m) {
              final name = m['name']!;
              final label = m['label']!;
              final isSelected =
                  selectedMuscleGroup.toLowerCase() == name.toLowerCase();
              final muscleColor = _getMuscleColor(name, isDark);
              final setNum = muscleSetCounts[name] ?? 0;

              return InkWell(
                onTap: () => onSelectMuscleGroup(name),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? muscleColor.withValues(alpha: isDark ? 0.35 : 0.25)
                        : (isDark
                              ? AppColors.darkSurfaceContainerHigh
                              : AppColors.lightSurfaceContainerLow),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? muscleColor : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: muscleColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? (isDark
                                    ? Colors.white
                                    : AppColors.lightTextPrimary)
                              : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($setNum sets)',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
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

class _AnatomicalSilhouettePainter extends CustomPainter {
  final bool isDark;
  final String selectedMuscleGroup;
  final Map<String, Color> muscleColors;

  _AnatomicalSilhouettePainter({
    required this.isDark,
    required this.selectedMuscleGroup,
    required this.muscleColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = isDark ? Colors.white24 : Colors.black12;

    // Body Outline (Head, Neck, Torso, Arms, Legs)
    final path = Path();
    // Head
    path.addOval(Rect.fromCircle(center: Offset(centerX, 25), radius: 14));
    // Neck
    path.moveTo(centerX - 4, 39);
    path.lineTo(centerX - 4, 46);
    path.moveTo(centerX + 4, 39);
    path.lineTo(centerX + 4, 46);

    // Torso & Legs Silhouette
    canvas.drawPath(path, basePaint);

    // Muscle Zone Rectangles with Dynamic Heatmap Fill
    final musclesToDraw = [
      {'name': 'Shoulders', 'rect': Rect.fromLTWH(centerX - 45, 46, 20, 18)},
      {'name': 'Shoulders', 'rect': Rect.fromLTWH(centerX + 25, 46, 20, 18)},
      {'name': 'Chest', 'rect': Rect.fromLTWH(centerX - 24, 48, 48, 22)},
      {'name': 'Arms', 'rect': Rect.fromLTWH(centerX - 50, 66, 18, 35)},
      {'name': 'Arms', 'rect': Rect.fromLTWH(centerX + 32, 66, 18, 35)},
      {'name': 'Core', 'rect': Rect.fromLTWH(centerX - 22, 73, 44, 34)},
      {'name': 'Back', 'rect': Rect.fromLTWH(centerX - 35, 48, 70, 50)},
      {'name': 'Legs', 'rect': Rect.fromLTWH(centerX - 32, 110, 28, 60)},
      {'name': 'Legs', 'rect': Rect.fromLTWH(centerX + 4, 110, 28, 60)},
    ];

    for (final m in musclesToDraw) {
      final name = m['name'] as String;
      final rect = m['rect'] as Rect;
      final color = muscleColors[name] ?? Colors.grey;
      final isSelected =
          selectedMuscleGroup.toLowerCase() == name.toLowerCase();

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: isSelected ? 0.85 : 0.45);

      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : 1.0
        ..color = isSelected
            ? (isDark ? AppColors.primaryVolt : AppColors.lightPrimary)
            : color;

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnatomicalSilhouettePainter oldDelegate) {
    return oldDelegate.selectedMuscleGroup != selectedMuscleGroup ||
        oldDelegate.muscleColors != muscleColors ||
        oldDelegate.isDark != isDark;
  }
}
