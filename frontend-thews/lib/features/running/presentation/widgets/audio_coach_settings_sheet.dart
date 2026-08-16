import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/smartwatch_models.dart';
import '../../../../core/services/audio_coach_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class AudioCoachSettingsSheet extends ConsumerWidget {
  const AudioCoachSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AudioCoachSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final audioState = ref.watch(audioCoachServiceProvider);
    final audioNotifier = ref.read(audioCoachServiceProvider.notifier);
    final config = audioState.config;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Material(
        color: isDark
            ? AppColors.darkSurfaceContainerHighest
            : AppColors.lightSurfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(
            color: isDark
                ? AppColors.darkOutline.withValues(alpha: 0.3)
                : AppColors.lightOutline.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
          // Drag Handle
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkOutline.withValues(alpha: 0.4)
                      : AppColors.lightOutline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.primaryVolt.withValues(alpha: 0.15)
                        : AppColors.lightPrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.record_voice_over,
                    color: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AUDIO COACH & SPLITS',
                        style: AppTypography.sectionTitle(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Hands-free voice telemetry & HR boundary alerts',
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
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable Settings Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.base),
              children: [
                // Master Voice Switch
                Material(
                  color: isDark
                      ? AppColors.darkSurfaceContainer
                      : AppColors.lightSurfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: config.isVoiceEnabled
                          ? (isDark
                              ? AppColors.primaryVolt.withValues(alpha: 0.5)
                              : AppColors.lightPrimary.withValues(alpha: 0.5))
                          : (isDark
                              ? AppColors.darkOutline.withValues(alpha: 0.2)
                              : AppColors.lightOutline.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Voice Coach Audio',
                        style: AppTypography.bodyLg(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ).copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                      ),
                      subtitle: Text(
                        'Spoken splits and real-time coaching via headphones',
                        style: AppTypography.tinyLabel(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                      value: config.isVoiceEnabled,
                      activeThumbColor: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary,
                      onChanged: (val) {
                        audioNotifier.updateConfig(
                          config.copyWith(isVoiceEnabled: val),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Target Heart Rate Zone Audio Alerts Section
                Text(
                  'HEART RATE ZONE AUDIO COACH',
                  style: AppTypography.tinyLabel(
                    color: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  softWrap: false,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Voice cues will alert you whenever your heart rate drifts above or below your target zone.',
                  style: AppTypography.tinyLabel(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.sm),

                DropdownButtonFormField<HeartRateZoneType?>(
                  isExpanded: true,
                  initialValue: config.targetHrZone,
                  decoration: InputDecoration(
                    labelText: 'Target Training Zone',
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSurfaceContainer
                        : AppColors.lightSurfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<HeartRateZoneType?>(
                      value: null,
                      child: Text('None (No Zone Alerts)',
                          maxLines: 1, softWrap: false),
                    ),
                    ...HeartRateZoneType.values.map((zoneType) {
                      final zoneName = switch (zoneType) {
                        HeartRateZoneType.warmup => 'Zone 1: Warmup (50-60%)',
                        HeartRateZoneType.fatBurn =>
                          'Zone 2: Aerobic Base (60-70%)',
                        HeartRateZoneType.cardio =>
                          'Zone 3: Cardio / Tempo (70-80%)',
                        HeartRateZoneType.anaerobic =>
                          'Zone 4: Threshold (80-90%)',
                        HeartRateZoneType.peak =>
                          'Zone 5: VO2 Max Peak (90-100%)',
                      };
                      return DropdownMenuItem<HeartRateZoneType?>(
                        value: zoneType,
                        child: Text(
                          zoneName,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (zone) {
                    if (zone == null) {
                      audioNotifier.updateConfig(
                        config.copyWith(clearTargetHrZone: true),
                      );
                    } else {
                      audioNotifier.updateConfig(
                        config.copyWith(targetHrZone: zone),
                      );
                    }
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                // Voice Split Trigger Interval
                Text(
                  'SPLIT ANNOUNCEMENT INTERVAL',
                  style: AppTypography.tinyLabel(
                    color: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  softWrap: false,
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<double>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: 500.0,
                      label: Text('500m', maxLines: 1, softWrap: false),
                    ),
                    ButtonSegment(
                      value: 1000.0,
                      label: Text('1 km', maxLines: 1, softWrap: false),
                    ),
                    ButtonSegment(
                      value: 1609.34,
                      label: Text('1 Mile', maxLines: 1, softWrap: false),
                    ),
                    ButtonSegment(
                      value: 2000.0,
                      label: Text('2 km', maxLines: 1, softWrap: false),
                    ),
                  ],
                  selected: {config.splitIntervalMeters},
                  onSelectionChanged: (selection) {
                    audioNotifier.updateConfig(
                      config.copyWith(splitIntervalMeters: selection.first),
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                // Target Distance Goal
                Text(
                  'TARGET DISTANCE GOAL (OPTIONAL)',
                  style: AppTypography.tinyLabel(
                    color: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  softWrap: false,
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<double?>(
                  isExpanded: true,
                  initialValue: config.targetDistanceMeters,
                  decoration: InputDecoration(
                    labelText: 'Target Distance',
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSurfaceContainer
                        : AppColors.lightSurfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem<double?>(
                      value: null,
                      child: Text('Open Run (No target)',
                          maxLines: 1, softWrap: false),
                    ),
                    DropdownMenuItem<double?>(
                      value: 3000.0,
                      child: Text('3K Run (3.0 km)',
                          maxLines: 1, softWrap: false),
                    ),
                    DropdownMenuItem<double?>(
                      value: 5000.0,
                      child: Text('5K Race (5.0 km)',
                          maxLines: 1, softWrap: false),
                    ),
                    DropdownMenuItem<double?>(
                      value: 10000.0,
                      child: Text('10K Race (10.0 km)',
                          maxLines: 1, softWrap: false),
                    ),
                    DropdownMenuItem<double?>(
                      value: 21097.5,
                      child: Text('Half Marathon (21.1 km)',
                          maxLines: 1, softWrap: false),
                    ),
                    DropdownMenuItem<double?>(
                      value: 42195.0,
                      child: Text('Full Marathon (42.2 km)',
                          maxLines: 1, softWrap: false),
                    ),
                  ],
                  onChanged: (dist) {
                    if (dist == null) {
                      audioNotifier.updateConfig(
                        config.copyWith(clearTargetDistance: true),
                      );
                    } else {
                      audioNotifier.updateConfig(
                        config.copyWith(targetDistanceMeters: dist),
                      );
                    }
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                // Telemetry Announcements Checklist
                Text(
                  'TELEMETRY ANNOUNCED IN VOICE SPLITS',
                  style: AppTypography.tinyLabel(
                    color: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  softWrap: false,
                ),
                const SizedBox(height: AppSpacing.xs),
                _CheckboxTile(
                  title: 'Split Pace',
                  value: config.announceSplitPace,
                  isDark: isDark,
                  onChanged: (v) => audioNotifier.updateConfig(
                    config.copyWith(announceSplitPace: v),
                  ),
                ),
                _CheckboxTile(
                  title: 'Total Distance',
                  value: config.announceTotalDistance,
                  isDark: isDark,
                  onChanged: (v) => audioNotifier.updateConfig(
                    config.copyWith(announceTotalDistance: v),
                  ),
                ),
                _CheckboxTile(
                  title: 'Elapsed Time',
                  value: config.announceElapsedTime,
                  isDark: isDark,
                  onChanged: (v) => audioNotifier.updateConfig(
                    config.copyWith(announceElapsedTime: v),
                  ),
                ),
                _CheckboxTile(
                  title: 'Current Heart Rate',
                  value: config.announceHeartRate,
                  isDark: isDark,
                  onChanged: (v) => audioNotifier.updateConfig(
                    config.copyWith(announceHeartRate: v),
                  ),
                ),
                _CheckboxTile(
                  title: 'Current Pace',
                  value: config.announceCurrentPace,
                  isDark: isDark,
                  onChanged: (v) => audioNotifier.updateConfig(
                    config.copyWith(announceCurrentPace: v),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Speech Rate & Pitch
                Text(
                  'VOICE SPEED (${(config.speechRate * 2.0).toStringAsFixed(1)}x)',
                  style: AppTypography.tinyLabel(
                    color: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  softWrap: false,
                ),
                Slider(
                  value: config.speechRate,
                  min: 0.3,
                  max: 0.8,
                  divisions: 5,
                  activeColor: isDark
                      ? AppColors.primaryVolt
                      : AppColors.lightPrimary,
                  onChanged: (val) {
                    audioNotifier.updateConfig(
                      config.copyWith(speechRate: val),
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                // Test Voice Cue Button (Single-line constraint adhered)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary,
                    ),
                  ),
                  onPressed: () {
                    audioNotifier.announceSplit(
                      splitIndex: 1,
                      totalDistanceMeters: 1000.0,
                      totalDurationSeconds: 290,
                      splitPaceSecondsPerKm: 290.0,
                      currentPaceSecondsPerKm: 285.0,
                      currentHeartRateBpm: 146,
                    );
                  },
                  icon: const Icon(Icons.volume_up, size: 20),
                  label: const Text(
                    'TEST AUDIO CUE',
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _CheckboxTile extends StatelessWidget {
  final String title;
  final bool value;
  final bool isDark;
  final ValueChanged<bool?> onChanged;

  const _CheckboxTile({
    required this.title,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: AppTypography.bodyMd(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        value: value,
        activeColor: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
        checkColor: isDark ? AppColors.darkBackground : Colors.white,
        onChanged: onChanged,
      ),
    );
  }
}
