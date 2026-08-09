import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/presentation/widgets/anatomical_body_painter.dart';
import '../../../../core/presentation/widgets/muscle_group_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../exercises_provider.dart';
import 'exercise_form_dialog.dart';
import 'gif_player_widget.dart';
import 'progress_analytics_card.dart';
import 'youtube_inline_player.dart';

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
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
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
                                        .isNotEmpty)
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
                                if (widget.exercise.isCustom)
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
                  const SizedBox(height: 16),

                  // 1. Targeted Muscle Visualization Card (Top)
                  _buildTargetedMuscleCard(context, isDark),
                  const SizedBox(height: 16),

                  // 2. Muted Auto-Looping YouTube Player / GIF / Image
                  if (isYoutube) ...[
                    YouTubeInlinePlayer(videoId: youtubeId),
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
                              child: GifPlayerWidget(
                                url: url,
                                isPaused: _isGifPaused,
                                isDark: isDark,
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
                            label: const Text(
                              'OPEN LINK',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryVolt,
                              foregroundColor: AppColors.primaryVoltOn,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
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
                            label: const Text(
                              'COPY LINK',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. Workout History & Progress Analytics Chart Section (Bottom)
                  progressAsync.when(
                    data: (points) => ProgressAnalyticsCard(points: points),
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

  Widget _buildTargetedMuscleCard(BuildContext context, bool isDark) {
    final Map<String, int> targetCounts = {
      widget.exercise.muscleGroup: 16,
    };

    if (widget.exercise.secondaryMuscleGroups != null &&
        widget.exercise.secondaryMuscleGroups!.trim().isNotEmpty) {
      final secList = widget.exercise.secondaryMuscleGroups!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      for (final sec in secList) {
        targetCounts[sec] = 8;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.accessibility_new_rounded,
                size: 16,
                color: AppColors.primaryVolt,
              ),
              const SizedBox(width: 6),
              Text(
                'TARGETED MUSCLES',
                style: AppTypography.labelCaps(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ).copyWith(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AnatomicalBodyPainterWidget(
            muscleSetCounts: targetCounts,
            selectedMuscleGroup: widget.exercise.muscleGroup,
            hideViewSelector: true,
            hideChips: true,
            figureHeight: 85.0,
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
