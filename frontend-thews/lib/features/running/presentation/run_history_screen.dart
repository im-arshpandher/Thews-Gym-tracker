import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/gpx_parser.dart';
import 'widgets/run_share_card.dart';

final runActivitiesStreamProvider = StreamProvider<List<RunActivityData>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllRunActivities();
});

class RunHistoryScreen extends ConsumerWidget {
  const RunHistoryScreen({super.key});

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final hrs = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hrs > 0) {
      return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatPace(double paceSecondsPerKm) {
    if (paceSecondsPerKm <= 0 || paceSecondsPerKm.isInfinite || paceSecondsPerKm.isNaN) {
      return '--:--';
    }
    final mins = paceSecondsPerKm ~/ 60;
    final secs = (paceSecondsPerKm % 60).round();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final runsAsync = ref.watch(runActivitiesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'RUN & OUTDOOR HISTORY',
          style: AppTypography.headlineMd(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_fire_department),
            tooltip: 'Territory Heatmap',
            onPressed: () => context.push('/running/heatmap'),
          ),
        ],
      ),
      body: runsAsync.when(
        data: (runs) {
          if (runs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_run_outlined,
                    size: 64,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No Outdoor Activities Logged Yet',
                    style: AppTypography.headlineSm(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Start an activity from Outdoor Tracker to record runs',
                    style: AppTypography.bodySm(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: runs.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final run = runs[index];
              final distKm = (run.distanceMeters / 1000.0).toStringAsFixed(2);
              final durationStr = _formatDuration(run.durationSeconds);
              final paceStr = _formatPace(run.avgPaceSecondsPerKm);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? AppColors.darkOutline.withValues(alpha: 0.3)
                        : AppColors.lightOutline.withValues(alpha: 0.3),
                  ),
                ),
                color: isDark
                    ? AppColors.darkSurfaceContainerHigh
                    : AppColors.lightSurfaceContainerLow,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    context.push('/running/summary/${run.id}');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isDark
                                        ? AppColors.primaryVolt
                                        : AppColors.lightPrimary)
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.directions_run,
                                color: isDark
                                    ? AppColors.primaryVolt
                                    : AppColors.lightPrimary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    run.activityType.toUpperCase(),
                                    style: AppTypography.bodyLg(
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(run.startTime),
                                    style: AppTypography.bodySm(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                              onSelected: (value) async {
                                final db = ref.read(databaseProvider);
                                if (value == 'flyover') {
                                  context.push('/running/flyover/${run.id}');
                                } else if (value == 'share_card') {
                                  RunShareCardDialog.show(context, run);
                                } else if (value == 'export') {
                                  final gpxContent = run.gpxData ?? '';
                                  if (gpxContent.isNotEmpty) {
                                    try {
                                      final points =
                                          GpxParser.parseGpxXml(gpxContent);
                                      final gpxString = GpxParser.toGpxXml(
                                        points,
                                        activityName: run.activityType,
                                      );
                                      final tempDir =
                                          await getTemporaryDirectory();
                                      final fileName =
                                          'thews_${run.activityType}_${run.id}.gpx';
                                      final filePath =
                                          '${tempDir.path}/$fileName';
                                      final file = File(filePath);
                                      await file.writeAsString(gpxString);
                                      // ignore: deprecated_member_use
                                      await Share.shareXFiles(
                                        [
                                          XFile(
                                            filePath,
                                            mimeType: 'application/gpx+xml',
                                          )
                                        ],
                                        subject:
                                            '${run.activityType} Route GPX File',
                                      );
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to export GPX: ${e.toString()}',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No GPX data available for this activity.',
                                        ),
                                      ),
                                    );
                                  }
                                } else if (value == 'delete') {
                                  await db.deleteRunActivity(run.id);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'flyover',
                                  child: Row(
                                    children: [
                                      Icon(Icons.flight_takeoff_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text('3D Flyover Replay'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'share_card',
                                  child: Row(
                                    children: [
                                      Icon(Icons.camera_alt_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Social Share Studio'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'export',
                                  child: Row(
                                    children: [
                                      Icon(Icons.share, size: 18),
                                      SizedBox(width: 8),
                                      Text('Export GPX'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete,
                                          color: AppColors.error, size: 18),
                                      SizedBox(width: 8),
                                      Text('Delete Activity',
                                          style: TextStyle(
                                              color: AppColors.error)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _RunMetricItem(
                              label: 'DISTANCE',
                              value: '$distKm km',
                              isDark: isDark,
                            ),
                            _RunMetricItem(
                              label: 'DURATION',
                              value: durationStr,
                              isDark: isDark,
                            ),
                            _RunMetricItem(
                              label: 'AVG PACE',
                              value: '$paceStr /km',
                              isDark: isDark,
                            ),
                            _RunMetricItem(
                              label: 'ELEVATION',
                              value:
                                  '${run.elevationGainMeters.toStringAsFixed(0)} m',
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading history: $err')),
      ),
    );
  }
}

class _RunMetricItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _RunMetricItem({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.bodyLg(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 2),
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
    );
  }
}
