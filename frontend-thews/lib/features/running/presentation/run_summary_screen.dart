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
import 'widgets/leaflet_route_map.dart';
import 'widgets/run_share_card.dart';

final singleRunActivityStreamProvider =
    StreamProvider.family<RunActivityData?, int>((ref, activityId) {
  final db = ref.watch(databaseProvider);
  return db.watchRunActivityById(activityId);
});

class RunSummaryScreen extends ConsumerWidget {
  final int activityId;

  const RunSummaryScreen({
    super.key,
    required this.activityId,
  });

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
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.day} ${months[date.month - 1]} ${date.year} • $timeStr';
  }

  String _formatPace(double paceSecPerKm) {
    if (paceSecPerKm <= 0 || paceSecPerKm.isInfinite) return '--:-- /km';
    final mins = (paceSecPerKm ~/ 60).toString().padLeft(2, '0');
    final secs = (paceSecPerKm % 60).toInt().toString().padLeft(2, '0');
    return '$mins:$secs /km';
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context, WidgetRef ref, RunActivityData activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity Session?'),
        content: const Text(
          'Are you sure you want to delete this outdoor activity entry? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', maxLines: 1, softWrap: false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DELETE', maxLines: 1, softWrap: false),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final db = ref.read(databaseProvider);
      await db.deleteRunActivity(activity.id);
      if (context.mounted) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activityAsync = ref.watch(singleRunActivityStreamProvider(activityId));

    return activityAsync.when(
      data: (activity) {
        if (activity == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Activity Details')),
            body: const Center(child: Text('Activity session not found.')),
          );
        }

        final points = activity.gpxData != null
            ? GpxParser.parseGpxXml(activity.gpxData!)
            : <GpxPoint>[];

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/running');
                }
              },
            ),
            title: Text(
              '${activity.activityType.toUpperCase()} SUMMARY',
              style: AppTypography.sectionTitle(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share Activity',
                onPressed: () => RunShareCardDialog.show(context, activity),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'Delete Activity',
                onPressed: () => _showDeleteConfirmation(context, ref, activity),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: AppSpacing.base,
              right: AppSpacing.base,
              top: AppSpacing.base,
              bottom: MediaQuery.of(context).padding.bottom + 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route Map Preview Canvas
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkOutline.withValues(alpha: 0.3)
                          : AppColors.lightOutline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: LeafletRouteMap(
                      waypoints: points,
                      isDark: isDark,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Hero Telemetry Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainerHigh
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
                          Text(
                            _formatDate(activity.startTime),
                            style: AppTypography.cardTitle(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ).copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                              activity.activityType.toUpperCase(),
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
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryMetricTile(
                              icon: Icons.straighten,
                              label: 'DISTANCE',
                              value:
                                  '${(activity.distanceMeters / 1000.0).toStringAsFixed(2)} km',
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SummaryMetricTile(
                              icon: Icons.speed,
                              label: 'AVG PACE',
                              value: _formatPace(activity.avgPaceSecondsPerKm),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryMetricTile(
                              icon: Icons.timer_outlined,
                              label: 'DURATION',
                              value: _formatDuration(activity.durationSeconds),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SummaryMetricTile(
                              icon: Icons.filter_hdr_outlined,
                              label: 'ELEVATION GAIN',
                              value:
                                  '${activity.elevationGainMeters.toStringAsFixed(0)} m',
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Export & Share Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (activity.gpxData != null &&
                              activity.gpxData!.isNotEmpty) {
                            try {
                              final tempDir = await getTemporaryDirectory();
                              final fileName =
                                  'thews_${activity.activityType}_${activity.id}.gpx';
                              final filePath = '${tempDir.path}/$fileName';
                              final file = File(filePath);
                              await file.writeAsString(activity.gpxData!);
                              await Share.shareXFiles(
                                [XFile(filePath, mimeType: 'application/gpx+xml')],
                                subject: '${activity.activityType}_track.gpx',
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Failed to export GPX: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No GPX track data available for this activity.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text(
                          'EXPORT GPX',
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
                        onPressed: () => RunShareCardDialog.show(context, activity),
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text(
                          'SHARE RUN CARD',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Scaffold(
        body: Center(child: Text('Error loading activity: $e')),
      ),
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _SummaryMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
