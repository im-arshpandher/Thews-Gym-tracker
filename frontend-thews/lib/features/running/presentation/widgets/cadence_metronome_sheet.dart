import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/cadence_metronome_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class CadenceMetronomeSheet extends ConsumerWidget {
  const CadenceMetronomeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CadenceMetronomeSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final metronomeState = ref.watch(cadenceMetronomeProvider);
    final metronomeNotifier = ref.read(cadenceMetronomeProvider.notifier);

    final presets = [160, 165, 170, 175, 180, 185, 190];

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerHighest
            : AppColors.lightSurfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutline.withValues(alpha: 0.3)
              : AppColors.lightOutline.withValues(alpha: 0.3),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.base,
        right: AppSpacing.base,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Drag Handle
          Center(
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
          const SizedBox(height: AppSpacing.md),

          // Header
          Row(
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
                  Icons.timelapse,
                  color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CADENCE METRONOME',
                      style: AppTypography.sectionTitle(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Rhythmic stride pacing for knee & joint protection',
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

          const SizedBox(height: AppSpacing.lg),

          // SPM Visual Pulse Display
          Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? AppColors.darkSurfaceContainer
                    : Colors.white,
                border: Border.all(
                  color: metronomeState.isPlaying
                      ? (isDark ? AppColors.primaryVolt : AppColors.lightPrimary)
                      : (isDark
                          ? AppColors.darkOutline.withValues(alpha: 0.2)
                          : AppColors.lightOutline.withValues(alpha: 0.2)),
                  width: metronomeState.isPlaying ? 3 : 1,
                ),
                boxShadow: metronomeState.isPlaying
                    ? [
                        BoxShadow(
                          color: (isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary)
                              .withValues(alpha: 0.25),
                          blurRadius: 20,
                          spreadRadius: 4,
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Beat Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isActive = metronomeState.isPlaying &&
                          metronomeState.currentTickIndex == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 12 : 8,
                        height: isActive ? 12 : 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? (isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary)
                              : (isDark
                                  ? AppColors.darkOutline.withValues(alpha: 0.3)
                                  : AppColors.lightOutline.withValues(alpha: 0.3)),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${metronomeState.targetBpm}',
                    style: AppTypography.displayHero(
                      color: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary,
                    ).copyWith(fontSize: 44, height: 1.0),
                    maxLines: 1,
                  ),
                  Text(
                    'SPM (STEPS / MIN)',
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
          ),

          const SizedBox(height: AppSpacing.md),

          // SPM Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: isDark
                  ? AppColors.primaryVolt
                  : AppColors.lightPrimary,
              thumbColor: isDark
                  ? AppColors.primaryVolt
                  : AppColors.lightPrimary,
              overlayColor: (isDark
                      ? AppColors.primaryVolt
                      : AppColors.lightPrimary)
                  .withValues(alpha: 0.2),
            ),
            child: Slider(
              value: metronomeState.targetBpm.toDouble(),
              min: 120,
              max: 220,
              divisions: 100,
              label: '${metronomeState.targetBpm} SPM',
              onChanged: (val) {
                metronomeNotifier.setBpm(val.round());
              },
            ),
          ),

          // Preset Quick Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets.map((bpm) {
                final isSelected = metronomeState.targetBpm == bpm;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('$bpm SPM', maxLines: 1, softWrap: false),
                    selected: isSelected,
                    selectedColor: isDark
                        ? AppColors.primaryVolt.withValues(alpha: 0.25)
                        : AppColors.lightPrimary.withValues(alpha: 0.2),
                    checkmarkColor: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? (isDark
                              ? AppColors.primaryVolt
                              : AppColors.lightPrimary)
                          : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (_) => metronomeNotifier.setBpm(bpm),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Feedback Mode Segment
          SegmentedButton<MetronomeFeedbackMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: MetronomeFeedbackMode.audioOnly,
                icon: Icon(Icons.volume_up, size: 16),
                label: Text('AUDIO', maxLines: 1, softWrap: false),
              ),
              ButtonSegment(
                value: MetronomeFeedbackMode.hapticOnly,
                icon: Icon(Icons.vibration, size: 16),
                label: Text('HAPTIC', maxLines: 1, softWrap: false),
              ),
              ButtonSegment(
                value: MetronomeFeedbackMode.audioAndHaptic,
                icon: Icon(Icons.graphic_eq, size: 16),
                label: Text('BOTH', maxLines: 1, softWrap: false),
              ),
            ],
            selected: {metronomeState.feedbackMode},
            onSelectionChanged: (selection) {
              metronomeNotifier.setFeedbackMode(selection.first);
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // Subdivision Selector
          SegmentedButton<MetronomeSubdivision>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: MetronomeSubdivision.everyStep,
                label: Text('1:1 (ALL)', maxLines: 1, softWrap: false),
              ),
              ButtonSegment(
                value: MetronomeSubdivision.everySecondStep,
                label: Text('1:2 (STRIDE)', maxLines: 1, softWrap: false),
              ),
              ButtonSegment(
                value: MetronomeSubdivision.everyFourthStep,
                label: Text('1:4 (ACCENT)', maxLines: 1, softWrap: false),
              ),
            ],
            selected: {metronomeState.subdivision},
            onSelectionChanged: (selection) {
              metronomeNotifier.setSubdivision(selection.first);
            },
          ),

          if (metronomeState.feedbackMode != MetronomeFeedbackMode.hapticOnly) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CLICK VOLUME',
                  style: AppTypography.tinyLabel(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  softWrap: false,
                ),
                Text(
                  '${(metronomeState.volume * 100).round()}%',
                  style: AppTypography.tinyLabel(
                    color: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  softWrap: false,
                ),
              ],
            ),
            Slider(
              value: metronomeState.volume,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              activeColor: isDark
                  ? AppColors.primaryVolt
                  : AppColors.lightPrimary,
              onChanged: (val) => metronomeNotifier.setVolume(val),
            ),
          ] else
            const SizedBox(height: AppSpacing.md),

          // Biomechanics Pro Tip Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceContainer
                  : AppColors.lightSurfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? AppColors.darkOutline.withValues(alpha: 0.2)
                    : AppColors.lightOutline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cadence between 170–185 SPM shortens ground contact time and significantly reduces knee impact forces.',
                    style: AppTypography.tinyLabel(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Master Start / Stop Button (Single-line constraint adhered)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: metronomeState.isPlaying
                  ? AppColors.error
                  : (isDark
                      ? AppColors.primaryVolt
                      : AppColors.lightPrimary),
              foregroundColor: metronomeState.isPlaying
                  ? Colors.white
                  : (isDark ? AppColors.darkBackground : Colors.white),
            ),
            onPressed: () {
              metronomeNotifier.toggle();
            },
            icon: Icon(
              metronomeState.isPlaying ? Icons.stop : Icons.play_arrow,
              size: 24,
            ),
            label: Text(
              metronomeState.isPlaying
                  ? 'STOP METRONOME'
                  : 'START METRONOME',
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
      ),
    ),
  );
}
}
