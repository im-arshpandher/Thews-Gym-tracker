import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum AnatomicalView { front, back }

class AnatomicalBodyPainterWidget extends StatefulWidget {
  final Map<String, int> muscleSetCounts;
  final String selectedMuscleGroup;
  final ValueChanged<String>? onSelectMuscleGroup;
  final AnatomicalView? initialView;
  final bool hideViewSelector;
  final bool hideChips;
  final double figureHeight;

  const AnatomicalBodyPainterWidget({
    super.key,
    required this.muscleSetCounts,
    required this.selectedMuscleGroup,
    this.onSelectMuscleGroup,
    this.initialView,
    this.hideViewSelector = false,
    this.hideChips = false,
    this.figureHeight = 180.0,
  });

  @override
  State<AnatomicalBodyPainterWidget> createState() =>
      _AnatomicalBodyPainterWidgetState();
}

class _AnatomicalBodyPainterWidgetState
    extends State<AnatomicalBodyPainterWidget> {
  late AnatomicalView _currentView;

  @override
  void initState() {
    super.initState();
    _currentView = widget.initialView ??
        _getBestViewForMuscle(widget.selectedMuscleGroup);
  }

  @override
  void didUpdateWidget(covariant AnatomicalBodyPainterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialView != null &&
        widget.initialView != oldWidget.initialView) {
      _currentView = widget.initialView!;
    } else if (widget.selectedMuscleGroup != oldWidget.selectedMuscleGroup &&
        widget.initialView == null) {
      _currentView = _getBestViewForMuscle(widget.selectedMuscleGroup);
    }
  }

  static AnatomicalView _getBestViewForMuscle(String muscleGroup) {
    final lower = muscleGroup.toLowerCase().trim();
    if (lower.contains('back') ||
        lower.contains('lat') ||
        lower.contains('trap') ||
        lower.contains('tricep') ||
        lower.contains('glute') ||
        lower.contains('hamstring') ||
        lower.contains('calf') ||
        lower.contains('calves') ||
        lower.contains('posterior')) {
      return AnatomicalView.back;
    }
    return AnatomicalView.front;
  }

  Color _getMuscleColor(String muscleName, bool isDark) {
    final sets = widget.muscleSetCounts[muscleName] ?? 0;
    if (sets == 0) {
      return isDark
          ? AppColors.darkSurfaceContainerHigh
          : AppColors.lightSurfaceContainerLow;
    } else if (sets < 6) {
      return Colors.amber.shade700;
    } else if (sets <= 14) {
      return Colors.cyan.shade600;
    } else {
      return AppColors.primaryVolt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final frontMuscles = [
      {'name': 'Chest', 'label': 'CHEST'},
      {'name': 'Shoulders', 'label': 'SHOULDERS'},
      {'name': 'Arms', 'label': 'BICEPS/ARMS'},
      {'name': 'Core', 'label': 'ABS/CORE'},
      {'name': 'Legs', 'label': 'QUADS/LEGS'},
    ];

    final backMuscles = [
      {'name': 'Back', 'label': 'UPPER/LOWER BACK'},
      {'name': 'Shoulders', 'label': 'REAR DELTS'},
      {'name': 'Arms', 'label': 'TRICEPS/ARMS'},
      {'name': 'Legs', 'label': 'GLUTES/CALVES'},
    ];

    final currentMuscles = _currentView == AnatomicalView.front
        ? frontMuscles
        : backMuscles;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.hideViewSelector ? 8 : 16),
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
          // Front vs Back View Switcher (Hidden when hideViewSelector is true)
          if (!widget.hideViewSelector) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ANATOMICAL HEATMAP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                SegmentedButton<AnatomicalView>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<AnatomicalView>(
                      value: AnatomicalView.front,
                      label: Text('FRONT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    ButtonSegment<AnatomicalView>(
                      value: AnatomicalView.back,
                      label: Text('BACK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  selected: {_currentView},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _currentView = newSelection.first;
                    });
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Visual Body Figure Canvas
          SizedBox(
            height: widget.figureHeight,
            child: ClipRect(
              child: CustomPaint(
                size: Size(260, widget.figureHeight),
                painter: _RealisticBodySilhouettePainter(
                  isDark: isDark,
                  view: _currentView,
                  selectedMuscleGroup: widget.selectedMuscleGroup,
                  muscleColors: {
                    for (final m in ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core'])
                      m: _getMuscleColor(m, isDark),
                  },
                ),
              ),
            ),
          ),

          if (!widget.hideChips) ...[
            const SizedBox(height: 16),

            // Interactive Heatmap Chips Selection Row
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: currentMuscles.map((m) {
                final name = m['name']!;
                final label = m['label']!;
                final isSelected =
                    widget.selectedMuscleGroup.toLowerCase() == name.toLowerCase();
                final muscleColor = _getMuscleColor(name, isDark);
                final setNum = widget.muscleSetCounts[name] ?? 0;

                return InkWell(
                  onTap: () => widget.onSelectMuscleGroup?.call(name),
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
        ],
      ),
    );
  }
}

class _RealisticBodySilhouettePainter extends CustomPainter {
  final bool isDark;
  final AnatomicalView view;
  final String selectedMuscleGroup;
  final Map<String, Color> muscleColors;

  _RealisticBodySilhouettePainter({
    required this.isDark,
    required this.view,
    required this.selectedMuscleGroup,
    required this.muscleColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.height / 200.0;
    canvas.save();
    canvas.translate((size.width - (260 * scale)) / 2, 0);
    canvas.scale(scale, scale);

    final double cx = 130.0;

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = isDark ? Colors.white30 : Colors.black26;

    final headCenter = Offset(cx, 24);
    canvas.drawOval(
      Rect.fromCenter(center: headCenter, width: 22, height: 28),
      outlinePaint,
    );

    // Draw Neck & Torso Outline
    final bodyOutline = Path();
    bodyOutline.moveTo(cx - 5, 38);
    bodyOutline.lineTo(cx - 18, 48); // Left shoulder
    bodyOutline.lineTo(cx - 36, 60); // Left arm outer
    bodyOutline.lineTo(cx - 38, 110); // Left arm hand
    bodyOutline.lineTo(cx - 24, 110); // Inner arm
    bodyOutline.lineTo(cx - 22, 64);  // Armpit
    bodyOutline.lineTo(cx - 18, 120); // Left waist/hip
    bodyOutline.lineTo(cx - 20, 185); // Left foot
    bodyOutline.lineTo(cx - 4, 185);  // Crotch inner left
    bodyOutline.lineTo(cx, 125);      // Crotch center
    bodyOutline.lineTo(cx + 4, 185);  // Crotch inner right
    bodyOutline.lineTo(cx + 20, 185); // Right foot
    bodyOutline.lineTo(cx + 18, 120); // Right waist/hip
    bodyOutline.lineTo(cx + 22, 64);  // Armpit right
    bodyOutline.lineTo(cx + 24, 110); // Inner arm right
    bodyOutline.lineTo(cx + 38, 110); // Hand right
    bodyOutline.lineTo(cx + 36, 60);  // Shoulder right
    bodyOutline.lineTo(cx + 5, 38);   // Neck right

    canvas.drawPath(bodyOutline, outlinePaint);

    // Dynamic Muscle Region Highlights
    if (view == AnatomicalView.front) {
      _drawFrontMuscles(canvas, cx);
    } else {
      _drawBackMuscles(canvas, cx);
    }

    canvas.restore();
  }

  void _drawFrontMuscles(Canvas canvas, double cx) {
    // 1. Shoulders / Deltoids (Left & Right)
    _drawMusclePath(
      canvas,
      'Shoulders',
      Path()
        ..moveTo(cx - 18, 48)
        ..lineTo(cx - 34, 58)
        ..lineTo(cx - 28, 72)
        ..lineTo(cx - 18, 60)
        ..close(),
    );
    _drawMusclePath(
      canvas,
      'Shoulders',
      Path()
        ..moveTo(cx + 18, 48)
        ..lineTo(cx + 34, 58)
        ..lineTo(cx + 28, 72)
        ..lineTo(cx + 18, 60)
        ..close(),
    );

    // 2. Chest Pecs (Left & Right)
    _drawMusclePath(
      canvas,
      'Chest',
      Path()
        ..moveTo(cx - 18, 50)
        ..lineTo(cx - 2, 50)
        ..lineTo(cx - 2, 70)
        ..lineTo(cx - 18, 64)
        ..close(),
    );
    _drawMusclePath(
      canvas,
      'Chest',
      Path()
        ..moveTo(cx + 2, 50)
        ..lineTo(cx + 18, 50)
        ..lineTo(cx + 18, 64)
        ..lineTo(cx + 2, 70)
        ..close(),
    );

    // 3. Biceps / Arms
    _drawMusclePath(
      canvas,
      'Arms',
      Path()
        ..moveTo(cx - 32, 66)
        ..lineTo(cx - 36, 92)
        ..lineTo(cx - 24, 92)
        ..lineTo(cx - 22, 66)
        ..close(),
    );
    _drawMusclePath(
      canvas,
      'Arms',
      Path()
        ..moveTo(cx + 22, 66)
        ..lineTo(cx + 24, 92)
        ..lineTo(cx + 36, 92)
        ..lineTo(cx + 32, 66)
        ..close(),
    );

    // 4. Core / Abs Grid
    _drawMusclePath(
      canvas,
      'Core',
      Path()
        ..moveTo(cx - 14, 72)
        ..lineTo(cx + 14, 72)
        ..lineTo(cx + 12, 108)
        ..lineTo(cx - 12, 108)
        ..close(),
    );

    // 5. Quadriceps / Legs
    _drawMusclePath(
      canvas,
      'Legs',
      Path()
        ..moveTo(cx - 18, 114)
        ..lineTo(cx - 3, 122)
        ..lineTo(cx - 5, 160)
        ..lineTo(cx - 18, 155)
        ..close(),
    );
    _drawMusclePath(
      canvas,
      'Legs',
      Path()
        ..moveTo(cx + 3, 122)
        ..lineTo(cx + 18, 114)
        ..lineTo(cx + 18, 155)
        ..lineTo(cx + 5, 160)
        ..close(),
    );
  }

  void _drawBackMuscles(Canvas canvas, double cx) {
    // 1. Upper Back & Traps V-shape
    _drawMusclePath(
      canvas,
      'Back',
      Path()
        ..moveTo(cx - 16, 46)
        ..lineTo(cx + 16, 46)
        ..lineTo(cx + 18, 70)
        ..lineTo(cx, 85)
        ..lineTo(cx - 18, 70)
        ..close(),
    );

    // 2. Lats & Lower Back
    _drawMusclePath(
      canvas,
      'Back',
      Path()
        ..moveTo(cx - 18, 72)
        ..lineTo(cx + 18, 72)
        ..lineTo(cx + 14, 105)
        ..lineTo(cx - 14, 105)
        ..close(),
    );

    // 3. Triceps / Arms
    _drawMusclePath(
      canvas,
      'Arms',
      Path()
        ..moveTo(cx - 33, 62)
        ..lineTo(cx - 36, 90)
        ..lineTo(cx - 25, 90)
        ..lineTo(cx - 23, 62)
        ..close(),
    );
    _drawMusclePath(
      canvas,
      'Arms',
      Path()
        ..moveTo(cx + 23, 62)
        ..lineTo(cx + 25, 90)
        ..lineTo(cx + 36, 90)
        ..lineTo(cx + 33, 62)
        ..close(),
    );

    // 4. Glutes & Calves / Posterior Legs
    _drawMusclePath(
      canvas,
      'Legs',
      Path()
        ..moveTo(cx - 16, 110)
        ..lineTo(cx - 2, 110)
        ..lineTo(cx - 4, 142)
        ..lineTo(cx - 16, 140)
        ..close(),
    );
    _drawMusclePath(
      canvas,
      'Legs',
      Path()
        ..moveTo(cx + 2, 110)
        ..lineTo(cx + 16, 110)
        ..lineTo(cx + 16, 140)
        ..lineTo(cx + 4, 142)
        ..close(),
    );
    _drawMusclePath(
      canvas,
      'Legs',
      Path()
        ..moveTo(cx - 16, 148)
        ..lineTo(cx - 5, 150)
        ..lineTo(cx - 7, 180)
        ..lineTo(cx - 16, 178)
        ..close(),
    );
    _drawMusclePath(
      canvas,
      'Legs',
      Path()
        ..moveTo(cx + 5, 150)
        ..lineTo(cx + 16, 148)
        ..lineTo(cx + 16, 178)
        ..lineTo(cx + 7, 180)
        ..close(),
    );
  }

  void _drawMusclePath(Canvas canvas, String name, Path path) {
    final color = muscleColors[name] ?? Colors.grey;
    final isSelected =
        selectedMuscleGroup.toLowerCase() == name.toLowerCase();

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: isSelected ? 0.90 : 0.50);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.5 : 1.2
      ..color = isSelected
          ? (isDark ? AppColors.primaryVolt : AppColors.lightPrimary)
          : color;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _RealisticBodySilhouettePainter oldDelegate) {
    return oldDelegate.selectedMuscleGroup != selectedMuscleGroup ||
        oldDelegate.muscleColors != muscleColors ||
        oldDelegate.view != view ||
        oldDelegate.isDark != isDark;
  }
}

