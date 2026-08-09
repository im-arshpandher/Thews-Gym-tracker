import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/gpx_parser.dart';

class RouteMapPainter extends CustomPainter {
  final List<GpxPoint> waypoints;
  final bool isDark;

  RouteMapPainter({
    required this.waypoints,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background Map Grid Layer
    final bgPaint = Paint()
      ..color = isDark
          ? AppColors.darkSurfaceContainerLowest
          : AppColors.lightSurfaceContainerLow;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      bgPaint,
    );

    // Map Grid Overlay Lines
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (waypoints.length < 2) {
      _drawWaitingState(canvas, size);
      return;
    }

    // Bounding Box Calculation
    double minLat = waypoints.first.latitude;
    double maxLat = waypoints.first.latitude;
    double minLng = waypoints.first.longitude;
    double maxLng = waypoints.first.longitude;

    for (final p in waypoints) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    final dLat = maxLat - minLat;
    final dLng = maxLng - minLng;
    final padding = 32.0;
    final drawWidth = size.width - (padding * 2);
    final drawHeight = size.height - (padding * 2);

    Offset toCanvasOffset(GpxPoint p) {
      final x = dLng == 0
          ? size.width / 2
          : padding + ((p.longitude - minLng) / dLng) * drawWidth;
      final y = dLat == 0
          ? size.height / 2
          : padding + (1 - (p.latitude - minLat) / dLat) * drawHeight;
      return Offset(x, y);
    }

    final path = Path();
    final points = waypoints.map(toCanvasOffset).toList();

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Glow Effect
    final glowPaint = Paint()
      ..color = (isDark ? AppColors.primaryVolt : AppColors.lightPrimary)
          .withValues(alpha: 0.3)
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    // Primary Track Polyline
    final linePaint = Paint()
      ..color = isDark ? AppColors.primaryVolt : AppColors.lightPrimary
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Start Pin Marker (Green)
    final startOffset = points.first;
    final startPinPaint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startOffset, 7.0, startPinPaint);
    canvas.drawCircle(
      startOffset,
      7.0,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // End/Current Pin Marker (Volt Pulsing Pin)
    final currentOffset = points.last;
    final currentPinPaint = Paint()
      ..color = isDark ? AppColors.primaryVolt : AppColors.lightPrimary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(currentOffset, 8.0, currentPinPaint);
    canvas.drawCircle(
      currentOffset,
      8.0,
      Paint()
        ..color = isDark ? AppColors.darkBackground : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void _drawWaitingState(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Acquiring GPS Satellite Signal...',
        style: TextStyle(
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant RouteMapPainter oldDelegate) {
    return oldDelegate.waypoints.length != waypoints.length ||
        oldDelegate.isDark != isDark;
  }
}
