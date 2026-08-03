import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/presentation/widgets/muscle_group_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../exercises_provider.dart';
import 'exercise_form_dialog.dart';

class ExerciseDetailsSheet extends ConsumerStatefulWidget {
  final ExerciseData exercise;

  const ExerciseDetailsSheet({super.key, required this.exercise});

  static Future<void> show(BuildContext context, ExerciseData exercise) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExerciseDetailsSheet(exercise: exercise),
    );
  }

  @override
  ConsumerState<ExerciseDetailsSheet> createState() =>
      _ExerciseDetailsSheetState();
}

class _ExerciseDetailsSheetState extends ConsumerState<ExerciseDetailsSheet> {
  bool _isGifPaused = false;
  String _selectedMetric = '1RM'; // '1RM' | 'Max Weight' | 'Volume'

  String? _extractYouTubeId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    if (uri.host.contains('youtube.com')) {
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      }
      final segments = uri.pathSegments;
      if (segments.length >= 2 &&
          (segments[0] == 'embed' ||
              segments[0] == 'shorts' ||
              segments[0] == 'v')) {
        return segments[1];
      }
    } else if (uri.host.contains('youtu.be')) {
      if (uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
    }
    return null;
  }

  String _normalizeMediaUrl(String rawUrl) {
    var clean = rawUrl.trim();
    if (clean.isEmpty) return '';

    if (clean.toLowerCase().startsWith('http://')) {
      clean = 'https://${clean.substring(7)}';
    }

    if (clean.contains('giphy.com/gifs/')) {
      final parts = clean.split('/');
      final lastPart = parts.isNotEmpty ? parts.last : '';
      final id = lastPart.contains('-') ? lastPart.split('-').last : lastPart;
      if (id.isNotEmpty) {
        return 'https://media.giphy.com/media/$id/giphy.gif';
      }
    }
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rawUrl = widget.exercise.videoUrl?.trim() ?? '';
    final url = _normalizeMediaUrl(rawUrl);
    final youtubeId = _extractYouTubeId(rawUrl);
    final hasMedia = url.isNotEmpty;

    final lowerUrl = url.toLowerCase();
    final isGifOrImage =
        hasMedia &&
        (lowerUrl.contains('.gif') ||
            lowerUrl.contains('.png') ||
            lowerUrl.contains('.jpg') ||
            lowerUrl.contains('.jpeg') ||
            lowerUrl.contains('.webp') ||
            lowerUrl.contains('giphy.com') ||
            lowerUrl.contains('tenor.com') ||
            lowerUrl.contains('imgur.com') ||
            lowerUrl.contains('gfycat.com'));

    final isYoutube = hasMedia && youtubeId != null;
    final progressAsync = ref.watch(
      exerciseProgressProvider(widget.exercise.id),
    );

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainerLow
              : AppColors.lightSurfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handlebar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkOutline
                            : AppColors.lightOutline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header Title & Badges
                  Row(
                    children: [
                      MuscleGroupIcon(
                        muscleGroup: widget.exercise.muscleGroup,
                        size: 48,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.exercise.name,
                                style: AppTypography.headlineSm(
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.getMuscleGroupBgColor(
                                      widget.exercise.muscleGroup,
                                      isDark,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'PRIMARY: ${widget.exercise.muscleGroup.toUpperCase()}',
                                    style:
                                        AppTypography.labelCaps(
                                          color:
                                              AppColors.getMuscleGroupTextColor(
                                                widget.exercise.muscleGroup,
                                                isDark,
                                              ),
                                        ).copyWith(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                                if (widget.exercise.secondaryMuscleGroups !=
                                        null &&
                                    widget
                                        .exercise
                                        .secondaryMuscleGroups!
                                        .isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkSurfaceContainerHigh
                                          : AppColors.lightSurfaceContainerLow,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'MINOR: ${widget.exercise.secondaryMuscleGroups!.toUpperCase()}',
                                      style:
                                          AppTypography.labelCaps(
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary,
                                          ).copyWith(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                                if (widget.exercise.isCustom) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.getMuscleGroupBgColor(
                                        'custom',
                                        isDark,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'CUSTOM',
                                      style:
                                          AppTypography.labelCaps(
                                            color:
                                                AppColors.getMuscleGroupTextColor(
                                                  'custom',
                                                  isDark,
                                                ),
                                          ).copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          ExerciseFormDialog.show(
                            context,
                            exercise: widget.exercise,
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceContainerHigh
                                : AppColors.lightSurfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkOutline
                                  : AppColors.lightOutline.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('✏️', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                'EDIT',
                                style:
                                    AppTypography.labelCaps(
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ).copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Progress & Analytics Section (Phase 3.1 fl_chart Integration)
                  progressAsync.when(
                    data: (points) {
                      return _buildProgressAnalyticsCard(
                        context,
                        points,
                        isDark,
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          color: AppColors.primaryVolt,
                        ),
                      ),
                    ),
                    error: (e, s) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 20),

                  // Muted Auto-Looping YouTube Player / GIF
                  if (isYoutube) ...[
                    _YouTubeInlinePlayer(videoId: youtubeId),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '⚡ Playing muted on loop • Tap video to pause/play',
                        style: AppTypography.bodySm(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ).copyWith(fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (isGifOrImage) ...[
                    GestureDetector(
                      onTap: () => setState(() => _isGifPaused = !_isGifPaused),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              constraints: const BoxConstraints(maxHeight: 260),
                              width: double.infinity,
                              color: isDark
                                  ? AppColors.darkSurfaceContainer
                                  : AppColors.lightSurfaceContainerLow,
                              child: _isGifPaused
                                  ? Image.network(
                                      url,
                                      fit: BoxFit.contain,
                                      gaplessPlayback: true,
                                    )
                                  : Image.network(
                                      url,
                                      fit: BoxFit.contain,
                                      loadingBuilder:
                                          (context, child, progress) {
                                            if (progress == null) return child;
                                            return SizedBox(
                                              height: 180,
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      color: isDark
                                                          ? AppColors
                                                                .primaryVolt
                                                          : AppColors
                                                                .lightPrimary,
                                                    ),
                                              ),
                                            );
                                          },
                                      errorBuilder:
                                          (
                                            context,
                                            error,
                                            stackTrace,
                                          ) => Container(
                                            padding: const EdgeInsets.all(24),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.broken_image,
                                                  size: 48,
                                                  color: AppColors.error,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Unable to load demo GIF',
                                                  style: AppTypography.bodySm(
                                                    color: AppColors.error,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                    ),
                            ),

                            if (_isGifPaused)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.7,
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: Colors.white38,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'PAUSED (Tap to Play)',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '⚡ Playing muted GIF on loop • Tap to pause/play',
                        style: AppTypography.bodySm(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ).copyWith(fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (hasMedia) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceContainer
                            : AppColors.lightSurfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkOutline
                              : AppColors.lightOutline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: isDark
                                  ? AppColors.primaryVoltOn
                                  : Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Demo Video Link Attached',
                                  style: AppTypography.bodyLg(
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySm(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Buttons for Media Links
                  if (hasMedia) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(url);
                              try {
                                final launched = await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                                if (!launched) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.platformDefault,
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Could not launch URL: $url',
                                      ),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('OPEN LINK'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryVolt,
                              foregroundColor: AppColors.primaryVoltOn,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: url));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Demo link copied to clipboard!',
                                ),
                                duration: const Duration(seconds: 2),
                                backgroundColor: isDark
                                    ? AppColors.darkSurfaceContainerHigh
                                    : AppColors.lightPrimary,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('COPY LINK'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (widget.exercise.isCustom)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => _confirmDelete(context),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        label: const Text(
                          'DELETE EXERCISE',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressAnalyticsCard(
    BuildContext context,
    List<ExerciseProgressPoint> points,
    bool isDark,
  ) {
    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainer
              : AppColors.lightSurfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.show_chart,
                size: 36,
                color: isDark
                    ? AppColors.darkOutlineVariant
                    : AppColors.lightOutlineVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'No workout history recorded yet for this exercise.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final max1RM = points.fold<double>(
      0,
      (prev, p) => p.estimated1RM > prev ? p.estimated1RM : prev,
    );
    final maxWeight = points.fold<double>(
      0,
      (prev, p) => p.maxWeight > prev ? p.maxWeight : prev,
    );

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
                    Icons.insights,
                    color: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PROGRESS TRENDS',
                    style: AppTypography.labelCaps(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildMetricChip('1RM', _selectedMetric == '1RM', isDark),
                  const SizedBox(width: 4),
                  _buildMetricChip(
                    'Max Weight',
                    _selectedMetric == 'Max Weight',
                    isDark,
                  ),
                  const SizedBox(width: 4),
                  _buildMetricChip(
                    'Volume',
                    _selectedMetric == 'Volume',
                    isDark,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // High Level PR Summary Banner
          Row(
            children: [
              Expanded(
                child: _buildSummaryBox(
                  'EST. 1RM PR',
                  '${max1RM.toStringAsFixed(1)} kg',
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryBox(
                  'MAX WEIGHT',
                  '${maxWeight.toStringAsFixed(1)} kg',
                  isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Interactive fl_chart LineChart
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < points.length) {
                          final dt = points[idx].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${dt.month}/${dt.day}',
                              style: TextStyle(
                                fontSize: 9,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: isDark
                              ? AppColors.primaryVolt
                              : AppColors.lightPrimary,
                          strokeWidth: 2,
                          strokeColor: isDark ? Colors.black : Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color:
                          (isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary)
                              .withValues(alpha: 0.18),
                    ),
                    spots: points.asMap().entries.map((e) {
                      final idx = e.key.toDouble();
                      final p = e.value;
                      double val = p.estimated1RM;
                      if (_selectedMetric == 'Max Weight') val = p.maxWeight;
                      if (_selectedMetric == 'Volume') val = p.totalVolume;
                      return FlSpot(idx, val);
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, bool isSelected, bool isDark) {
    return InkWell(
      onTap: () => setState(() => _selectedMetric = label),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primaryVolt : AppColors.lightPrimary)
              : (isDark
                    ? AppColors.darkSurfaceContainerHigh
                    : AppColors.lightSurfaceContainerHigh),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? (isDark ? AppColors.primaryVoltOn : Colors.white)
                : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBox(String title, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerHigh
            : AppColors.lightSurfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.labelCaps(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ).copyWith(fontSize: 9),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.headlineSm(
              color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Exercise?'),
        content: Text(
          'Are you sure you want to delete "${widget.exercise.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              Navigator.of(ctx).pop();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
              await db.deleteExercise(widget.exercise.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}

class _YouTubeInlinePlayer extends StatefulWidget {
  final String videoId;

  const _YouTubeInlinePlayer({required this.videoId});

  @override
  State<_YouTubeInlinePlayer> createState() => _YouTubeInlinePlayerState();
}

class _YouTubeInlinePlayerState extends State<_YouTubeInlinePlayer> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(
        Uri.parse(
          'https://www.youtube.com/embed/${widget.videoId}?autoplay=1&mute=1&loop=1&playlist=${widget.videoId}&controls=0',
        ),
      );
  }

  @override
  void didUpdateWidget(covariant _YouTubeInlinePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _controller.loadRequest(
        Uri.parse(
          'https://www.youtube.com/embed/${widget.videoId}?autoplay=1&mute=1&loop=1&playlist=${widget.videoId}&controls=0',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
