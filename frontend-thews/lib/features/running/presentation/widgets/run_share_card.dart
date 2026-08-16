import 'dart:io';
import 'dart:ui' as ui;

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
import 'leaflet_route_map.dart';

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
    sb.writeln('Tracked with Thews Gym Tracker ⚡');
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainerHigh
              : AppColors.lightSurfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? AppColors.primaryVolt.withValues(alpha: 0.3)
                : AppColors.lightPrimary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RepaintBoundary(
                key: _shareCardKey,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    AppColors.darkSurfaceContainerHighest,
                                    AppColors.darkSurfaceContainer,
                                  ]
                                : [
                                    AppColors.lightPrimaryContainer,
                                    AppColors.lightSurfaceContainerLow,
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      widget.activity.activityType == 'cycle'
                                          ? Icons.directions_bike
                                          : Icons.directions_run,
                                      color: isDark
                                          ? AppColors.primaryVolt
                                          : AppColors.lightPrimary,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'THEWS ${widget.activity.activityType.toUpperCase()}',
                                      style: AppTypography.sectionTitle(
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary,
                                      ).copyWith(fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.primaryVolt.withValues(alpha: 0.15)
                                        : AppColors.lightPrimary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatDate(widget.activity.startTime),
                                    style: AppTypography.tinyLabel(
                                      color: isDark
                                          ? AppColors.primaryVolt
                                          : AppColors.lightPrimary,
                                    ),
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              height: 180,
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: LeafletRouteMap(
                                  waypoints: points,
                                  isDark: isDark,
                                  interactive: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _RunMetricTile(
                                    icon: Icons.straighten,
                                    label: 'DISTANCE',
                                    value:
                                        '${(widget.activity.distanceMeters / 1000.0).toStringAsFixed(2)} km',
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _RunMetricTile(
                                    icon: Icons.speed,
                                    label: 'AVG PACE',
                                    value: _formatPace(widget.activity.avgPaceSecondsPerKm),
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _RunMetricTile(
                                    icon: Icons.timer_outlined,
                                    label: 'DURATION',
                                    value: _formatDuration(widget.activity.durationSeconds),
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _RunMetricTile(
                                    icon: Icons.filter_hdr_outlined,
                                    label: 'ELEVATION GAIN',
                                    value:
                                        '${widget.activity.elevationGainMeters.toStringAsFixed(0)} m',
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: _generateTextSummary()),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Activity summary copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text(
                          'COPY TEXT',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? AppColors.primaryVolt
                              : AppColors.lightPrimary,
                          foregroundColor: isDark
                              ? AppColors.darkBackground
                              : Colors.white,
                        ),
                        onPressed: _isExporting ? null : _shareImageCard,
                        icon: _isExporting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDark
                                      ? AppColors.darkBackground
                                      : Colors.white,
                                ),
                              )
                            : const Icon(Icons.image_outlined, size: 18),
                        label: const Text(
                          'SHARE IMG',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _RunMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.lightSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.cardTitle(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ).copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: AppTypography.tinyLabel(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
    );
  }
}
