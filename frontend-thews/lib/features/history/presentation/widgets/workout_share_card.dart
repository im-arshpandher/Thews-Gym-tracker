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
import '../../../../core/utils/volume_calculator.dart';

class WorkoutShareCardDialog extends StatefulWidget {
  final WorkoutData workout;
  final List<WorkoutExerciseDetail> details;

  const WorkoutShareCardDialog({
    super.key,
    required this.workout,
    required this.details,
  });

  static Future<void> show(
    BuildContext context, {
    required WorkoutData workout,
    required List<WorkoutExerciseDetail> details,
  }) {
    return showDialog(
      context: context,
      builder: (context) => WorkoutShareCardDialog(
        workout: workout,
        details: details,
      ),
    );
  }

  @override
  State<WorkoutShareCardDialog> createState() => _WorkoutShareCardDialogState();
}

class _WorkoutShareCardDialogState extends State<WorkoutShareCardDialog> {
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isExporting = false;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 min';
    final mins = seconds ~/ 60;
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    return '${hrs}h ${remMins}m';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _generateTextSummary() {
    final totalVolume = widget.details.fold<double>(
      0.0,
      (sum, d) => sum + VolumeCalculator.calculateTotalVolume(d.sets),
    );
    final totalSets = widget.details.fold<int>(
      0,
      (sum, d) => sum + d.sets.length,
    );

    final sb = StringBuffer();
    sb.writeln('💪 THEWS WORKOUT SUMMARY');
    sb.writeln('📅 ${_formatDate(widget.workout.date)}');
    sb.writeln(
      '⏱️ Duration: ${_formatDuration(widget.workout.durationSeconds)}',
    );
    sb.writeln('🏋️ Total Volume: ${totalVolume.toStringAsFixed(0)} kg');
    sb.writeln(
      '📊 Total Sets: $totalSets across ${widget.details.length} exercises',
    );
    sb.writeln('');
    sb.writeln('Exercises Logged:');

    for (final detail in widget.details) {
      final bestWeight = detail.sets.fold<double>(
        0.0,
        (maxW, s) => s.weight > maxW ? s.weight : maxW,
      );
      sb.writeln(
        '• ${detail.exercise.name}: ${detail.sets.length} sets (Max: ${bestWeight % 1 == 0 ? bestWeight.toInt() : bestWeight} ${detail.sets.isNotEmpty ? detail.sets.first.unit : 'kg'})',
      );
    }

    if (widget.workout.notes != null && widget.workout.notes!.isNotEmpty) {
      sb.writeln('');
      sb.writeln('📝 Notes: ${widget.workout.notes}');
    }

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
          '${tempDir.path}/thews_workout_${widget.workout.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = await File(imagePath).create();
      await file.writeAsBytes(pngBytes);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Tracked & logged with Thews Gym Tracker ⚡',
        subject: 'My Workout on Thews',
      );
    } catch (e) {
      if (mounted) {
        final summary = _generateTextSummary();
        // ignore: deprecated_member_use
        await Share.share(summary, subject: 'My Workout on Thews');
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

    final totalVolume = widget.details.fold<double>(
      0.0,
      (sum, d) => sum + VolumeCalculator.calculateTotalVolume(d.sets),
    );
    final totalSets = widget.details.fold<int>(
      0,
      (sum, d) => sum + d.sets.length,
    );
    final muscleGroups =
        widget.details.map((d) => d.exercise.muscleGroup).toSet().toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
                // RepaintBoundary wrapping visual share card image
                RepaintBoundary(
                  key: _shareCardKey,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      color: isDark
                          ? AppColors.darkSurfaceContainerHigh
                          : AppColors.lightSurfaceContainerLowest,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Branded Share Header
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
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                            child: Column(
                              children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.bolt,
                                        color: isDark
                                            ? AppColors.primaryVolt
                                            : AppColors.lightPrimary,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'THEWS WORKOUT',
                                          style: AppTypography.sectionTitle(
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                          ).copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.primaryVolt.withValues(
                                            alpha: 0.15,
                                          )
                                        : AppColors.lightPrimary.withValues(
                                            alpha: 0.15,
                                          ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatDate(widget.workout.date),
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
                            // High Metrics Grid
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricTile(
                                    icon: Icons.timer_outlined,
                                    label: 'DURATION',
                                    value: _formatDuration(
                                      widget.workout.durationSeconds,
                                    ),
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _MetricTile(
                                    icon: Icons.fitness_center_outlined,
                                    label: 'VOLUME',
                                    value:
                                        '${totalVolume.toStringAsFixed(0)} kg',
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _MetricTile(
                                    icon: Icons.format_list_bulleted,
                                    label: 'SETS',
                                    value: '$totalSets',
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Exercises List Preview
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TARGET MUSCLE GROUPS',
                              style: AppTypography.labelCaps(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: muscleGroups.map((mg) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkSurfaceContainer
                                        : AppColors.lightSurfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.darkOutline.withValues(
                                              alpha: 0.2,
                                            )
                                          : AppColors.lightOutline.withValues(
                                              alpha: 0.2,
                                            ),
                                    ),
                                  ),
                                  child: Text(
                                    mg.toUpperCase(),
                                    style: AppTypography.tinyLabel(
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: AppSpacing.md),

                            Text(
                              'EXERCISES PERFORMED',
                              style: AppTypography.labelCaps(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...widget.details.take(5).map((detail) {
                              final bestW = detail.sets.fold<double>(
                                0.0,
                                (maxW, s) => s.weight > maxW ? s.weight : maxW,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        detail.exercise.name,
                                        style: AppTypography.bodyMd(
                                          color: isDark
                                              ? AppColors.darkTextPrimary
                                              : AppColors.lightTextPrimary,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${detail.sets.length} sets • Max ${bestW % 1 == 0 ? bestW.toInt() : bestW} kg',
                                      style: AppTypography.tinyLabel(
                                        color: isDark
                                            ? AppColors.primaryVolt
                                            : AppColors.lightPrimary,
                                      ),
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (widget.details.length > 5)
                              Text(
                                '+ ${widget.details.length - 5} more exercises',
                                style: AppTypography.tinyLabel(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Branded App Caption Footer on Image
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceContainerHighest
                                  .withValues(alpha: 0.5)
                              : AppColors.lightSurfaceContainerLow,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(22),
                            bottomRight: Radius.circular(22),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.bolt,
                              size: 14,
                              color: AppColors.primaryVolt,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tracked & Logged with Thews Gym Tracker',
                              style: AppTypography.tinyLabel(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ).copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

              // Action Buttons Row (Copy Text & Share Image)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
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
                              content: Text(
                                'Workout summary copied to clipboard!',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'COPY TEXT',
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.share, size: 16),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isExporting ? 'EXPORTING...' : 'SHARE IMAGE',
                            maxLines: 1,
                            softWrap: false,
                          ),
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
    ),
  );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
            size: 16,
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
