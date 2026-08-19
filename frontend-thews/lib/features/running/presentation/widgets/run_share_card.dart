import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/gpx_parser.dart';
import 'gradient_route_painter.dart';

enum ShareCardAspectRatio {
  story9x16,
  square1x1,
  landscape16x9,
}

enum ShareCardThemePreset {
  voltDark,
  terrainGradient,
  biometricsPro,
  routeOnlyOverlay,
}

class RunShareCardDialog extends StatefulWidget {
  final RunActivityData activity;

  const RunShareCardDialog({
    super.key,
    required this.activity,
  });

  static Future<void> show(BuildContext context, RunActivityData activity) {
    return showDialog(
      context: context,
      builder: (context) => RunShareCardDialog(activity: activity),
    );
  }

  @override
  State<RunShareCardDialog> createState() => _RunShareCardDialogState();
}

class _RunShareCardDialogState extends State<RunShareCardDialog> {
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isExporting = false;
  ShareCardAspectRatio _selectedAspect = ShareCardAspectRatio.story9x16;
  ShareCardThemePreset _selectedPreset = ShareCardThemePreset.voltDark;
  bool _transparentOverlay = false;

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    final hrs = seconds ~/ 3600;
    if (hrs > 0) {
      final remMins = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
      return '$hrs:$remMins:$secs';
    }
    return '$mins:$secs';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatPace(double paceSecPerKm) {
    if (paceSecPerKm <= 0 || paceSecPerKm.isInfinite) return '--:-- /km';
    final mins = (paceSecPerKm ~/ 60).toString().padLeft(2, '0');
    final secs = (paceSecPerKm % 60).toInt().toString().padLeft(2, '0');
    return '$mins:$secs /km';
  }

  String _generateTextSummary() {
    final sb = StringBuffer();
    sb.writeln('🏃 THEWS ${widget.activity.activityType.toUpperCase()} ACTIVITY');
    sb.writeln('📅 ${_formatDate(widget.activity.startTime)}');
    sb.writeln('📏 Distance: ${(widget.activity.distanceMeters / 1000.0).toStringAsFixed(2)} km');
    sb.writeln('⏱️ Duration: ${_formatDuration(widget.activity.durationSeconds)}');
    sb.writeln('⚡ Avg Pace: ${_formatPace(widget.activity.avgPaceSecondsPerKm)}');
    sb.writeln('⛰️ Elevation Gain: ${widget.activity.elevationGainMeters.toStringAsFixed(0)} m');
    sb.writeln('');
    sb.writeln('Tracked with Thews Hybrid Fitness ⚡');
    return sb.toString();
  }

  Future<void> _shareImageCard() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final boundary =
          _shareCardKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not capture share card image.');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw Exception('Failed to convert image to bytes.');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final imagePath =
          '${tempDir.path}/thews_run_card_${widget.activity.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(pngBytes);

      final summary = _generateTextSummary();
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(imagePath)],
        text: summary,
        subject: 'My Outdoor Activity on Thews',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share image card: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final points = widget.activity.gpxData != null
        ? GpxParser.parseGpxXml(widget.activity.gpxData!)
        : <GpxPoint>[];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainerHighest
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? AppColors.primaryVolt.withValues(alpha: 0.3)
                : AppColors.lightPrimary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SOCIAL SHARE STUDIO',
                          style: AppTypography.sectionTitle(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ).copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Aspect Ratio Selector Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _aspectChoiceChip('9:16 Story', ShareCardAspectRatio.story9x16, isDark),
                      const SizedBox(width: 6),
                      _aspectChoiceChip('1:1 Square', ShareCardAspectRatio.square1x1, isDark),
                      const SizedBox(width: 6),
                      _aspectChoiceChip('16:9 Wide', ShareCardAspectRatio.landscape16x9, isDark),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Theme Presets Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _presetChoiceChip('Volt Dark', ShareCardThemePreset.voltDark, isDark),
                      const SizedBox(width: 6),
                      _presetChoiceChip('Terrain', ShareCardThemePreset.terrainGradient, isDark),
                      const SizedBox(width: 6),
                      _presetChoiceChip('Pace Zones', ShareCardThemePreset.biometricsPro, isDark),
                      const SizedBox(width: 6),
                      _presetChoiceChip('Route-Only', ShareCardThemePreset.routeOnlyOverlay, isDark),
                    ],
                  ),
                ),

                if (_selectedPreset == ShareCardThemePreset.routeOnlyOverlay) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Transparent Canvas',
                        style: AppTypography.tinyLabel(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Switch.adaptive(
                        value: _transparentOverlay,
                        activeTrackColor: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                        onChanged: (v) => setState(() => _transparentOverlay = v),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: AppSpacing.sm),

                // Captured Share Card Container with RepaintBoundary
                Center(
                  child: RepaintBoundary(
                    key: _shareCardKey,
                    child: _buildShareCardCanvas(points, isDark),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _generateTextSummary()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Activity summary copied! 📋'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text(
                          'COPY TEXT',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                          foregroundColor: isDark ? AppColors.primaryVoltOn : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isExporting ? null : _shareImageCard,
                        icon: _isExporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(Icons.share_rounded, size: 18),
                        label: Text(
                          _isExporting ? 'EXPORTING...' : 'SHARE CARD',
                          maxLines: 1,
                          softWrap: false,
                          style: AppTypography.labelCaps().copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.primaryVoltOn : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _aspectChoiceChip(String label, ShareCardAspectRatio aspect, bool isDark) {
    final isSelected = _selectedAspect == aspect;
    return ChoiceChip(
      label: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? (isDark ? AppColors.primaryVoltOn : Colors.white)
              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
      ),
      selected: isSelected,
      selectedColor: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
      backgroundColor: isDark ? AppColors.darkSurfaceContainerLow : AppColors.lightSurfaceContainerLow,
      onSelected: (val) {
        if (val) setState(() => _selectedAspect = aspect);
      },
    );
  }

  Widget _presetChoiceChip(String label, ShareCardThemePreset preset, bool isDark) {
    final isSelected = _selectedPreset == preset;
    return ChoiceChip(
      label: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? (isDark ? AppColors.primaryVoltOn : Colors.white)
              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
      ),
      selected: isSelected,
      selectedColor: isDark ? AppColors.neonCyan : Colors.teal,
      backgroundColor: isDark ? AppColors.darkSurfaceContainerLow : AppColors.lightSurfaceContainerLow,
      onSelected: (val) {
        if (val) setState(() => _selectedPreset = preset);
      },
    );
  }

  Widget _buildShareCardCanvas(List<GpxPoint> points, bool isDark) {
    double width = 300;
    double height = 480;

    switch (_selectedAspect) {
      case ShareCardAspectRatio.story9x16:
        width = 280;
        height = 498; // 9:16
        break;
      case ShareCardAspectRatio.square1x1:
        width = 300;
        height = 300; // 1:1
        break;
      case ShareCardAspectRatio.landscape16x9:
        width = 340;
        height = 191; // 16:9
        break;
    }

    final distanceKm = widget.activity.distanceMeters / 1000.0;
    final isLandscape = _selectedAspect == ShareCardAspectRatio.landscape16x9;
    final isRouteOnly = _selectedPreset == ShareCardThemePreset.routeOnlyOverlay;

    final bgColor = isRouteOnly
        ? (_transparentOverlay ? Colors.transparent : const Color(0xE60A0E10))
        : const Color(0xFF0F1416);

    final borderColor = isRouteOnly && _transparentOverlay
        ? Colors.transparent
        : (_selectedPreset == ShareCardThemePreset.voltDark
            ? AppColors.primaryVolt.withValues(alpha: 0.4)
            : (_selectedPreset == ShareCardThemePreset.terrainGradient
                ? AppColors.neonCyan.withValues(alpha: 0.4)
                : (_selectedPreset == ShareCardThemePreset.biometricsPro
                    ? const Color(0xFFFF1744).withValues(alpha: 0.4)
                    : AppColors.primaryVolt.withValues(alpha: 0.5))));

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Stack(
        children: [
          // Background Vector Route Outline / Glow Canvas
          if (points.length >= 2)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: CustomPaint(
                  painter: _VectorRoutePainter(
                    waypoints: points,
                    colorMode: _selectedPreset == ShareCardThemePreset.terrainGradient
                        ? RouteColorMode.slopeGradient
                        : (_selectedPreset == ShareCardThemePreset.biometricsPro
                            ? RouteColorMode.heartRateZone
                            : RouteColorMode.solidVolt),
                    isRouteOnly: isRouteOnly,
                  ),
                ),
              ),
            ),

          // If Route-Only mode, render sleek minimal floating badges
          if (isRouteOnly)
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Minimal Watermark Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, color: AppColors.primaryVolt, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'THEWS',
                          style: AppTypography.labelCaps(color: Colors.white)
                              .copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Minimal Stat Pill
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primaryVolt.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '${distanceKm.toStringAsFixed(2)} KM • ${_formatPace(widget.activity.avgPaceSecondsPerKm)}',
                        style: AppTypography.labelCaps(color: AppColors.primaryVolt)
                            .copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // Full Stat Card Content Layer
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryVolt.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              color: AppColors.primaryVolt,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'THEWS',
                            style: AppTypography.labelCaps(color: Colors.white)
                                .copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 10),
                          ),
                        ],
                      ),
                      Text(
                        _formatDate(widget.activity.startTime),
                        style: AppTypography.tinyLabel(color: Colors.white70).copyWith(fontSize: 9),
                      ),
                    ],
                  ),

                  // Center Primary Distance & Pace Hero
                  if (!isLandscape) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${distanceKm.toStringAsFixed(2)} KM',
                          style: AppTypography.displayHero(color: AppColors.primaryVolt)
                              .copyWith(
                                fontSize: _selectedAspect == ShareCardAspectRatio.story9x16 ? 34 : 28,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.activity.activityType.toUpperCase()} • ${_formatDuration(widget.activity.durationSeconds)}',
                          style: AppTypography.bodySm(color: Colors.white)
                              .copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                        ),
                      ],
                    ),
                  ],

                  // Bottom Telemetry Grid & Elevation Mini-Bar
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Elevation silhouette if available
                      if (points.length >= 3 && _selectedAspect == ShareCardAspectRatio.story9x16) ...[
                        SizedBox(
                          height: 30,
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              lineTouchData: const LineTouchData(enabled: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: points.asMap().entries.map((e) {
                                    return FlSpot(e.key.toDouble(), e.value.elevation);
                                  }).toList(),
                                  isCurved: true,
                                  color: AppColors.neonCyan,
                                  barWidth: 2.0,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppColors.neonCyan.withValues(alpha: 0.15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Stats Grid
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(child: _cardStat('PACE', _formatPace(widget.activity.avgPaceSecondsPerKm))),
                            _statDivider(),
                            Expanded(child: _cardStat('GAIN', '${widget.activity.elevationGainMeters.toInt()}m')),
                            _statDivider(),
                            Expanded(child: _cardStat('TIME', _formatDuration(widget.activity.durationSeconds))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.tinyLabel(color: Colors.white60).copyWith(fontSize: 8),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.cardTitle(color: Colors.white).copyWith(
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 18, color: Colors.white24);
  }
}

/// Custom Canvas Painter rendering smooth normalized route vectors on share cards.
class _VectorRoutePainter extends CustomPainter {
  final List<GpxPoint> waypoints;
  final RouteColorMode colorMode;
  final bool isRouteOnly;

  _VectorRoutePainter({
    required this.waypoints,
    required this.colorMode,
    this.isRouteOnly = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waypoints.length < 2) return;

    double minLat = waypoints.first.latitude;
    double maxLat = waypoints.first.latitude;
    double minLng = waypoints.first.longitude;
    double maxLng = waypoints.first.longitude;

    for (final p in waypoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    if (latSpan == 0 || lngSpan == 0) return;

    final padding = isRouteOnly ? 24.0 : 36.0;
    final drawWidth = size.width - (padding * 2);
    final drawHeight = size.height - (padding * 2);

    Offset toCanvas(GpxPoint p) {
      final x = padding + ((p.longitude - minLng) / lngSpan) * drawWidth;
      final y = size.height - (padding + ((p.latitude - minLat) / latSpan) * drawHeight);
      return Offset(x, y);
    }

    // Glow background path
    final glowPaint = Paint()
      ..color = AppColors.primaryVolt.withValues(alpha: isRouteOnly ? 0.35 : 0.18)
      ..strokeWidth = isRouteOnly ? 14.0 : 10.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPath = ui.Path();
    glowPath.moveTo(toCanvas(waypoints.first).dx, toCanvas(waypoints.first).dy);
    for (int i = 1; i < waypoints.length; i++) {
      final pt = toCanvas(waypoints[i]);
      glowPath.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(glowPath, glowPaint);

    // Segmented Core Stroke
    for (int i = 0; i < waypoints.length - 1; i++) {
      final p1 = waypoints[i];
      final p2 = waypoints[i + 1];

      Color segColor = AppColors.primaryVolt;
      if (colorMode == RouteColorMode.slopeGradient) {
        final grade = SlopeGradientUtils.calculateGradePercent(p1, p2);
        segColor = SlopeGradientUtils.getSlopeColor(grade, isDark: true);
      }

      final segPaint = Paint()
        ..color = segColor
        ..strokeWidth = isRouteOnly ? 4.5 : 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(toCanvas(p1), toCanvas(p2), segPaint);
    }

    // Start Marker (Green circle) & End Marker (Red circle)
    final startPt = toCanvas(waypoints.first);
    final endPt = toCanvas(waypoints.last);

    final startPaint = Paint()..color = const Color(0xFF00E676);
    canvas.drawCircle(startPt, 4.5, startPaint);

    final endPaint = Paint()..color = const Color(0xFFFF1744);
    canvas.drawCircle(endPt, 4.5, endPaint);
  }

  @override
  bool shouldRepaint(covariant _VectorRoutePainter oldDelegate) => true;
}
