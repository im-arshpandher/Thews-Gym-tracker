import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/models/exercise_metric.dart';
import '../../../../core/presentation/widgets/muscle_group_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/metric_formatter.dart';
import '../../../ai_coach/presentation/widgets/adaptive_set_coach_banner.dart';
import '../../../settings/presentation/settings_provider.dart';
import '../rest_timer_provider.dart';
import '../../domain/workout_draft_models.dart';

/// Card widget for an exercise within the active workout session.
/// Displays exercise header, previous session data, and editable set rows.
class ExerciseCardWidget extends ConsumerStatefulWidget {
  final WorkoutExerciseDraft draft;
  final VoidCallback onRemoveExercise;
  final VoidCallback onOpenPlateCalculator;
  final VoidCallback onStateChanged;

  const ExerciseCardWidget({
    super.key,
    required this.draft,
    required this.onRemoveExercise,
    required this.onOpenPlateCalculator,
    required this.onStateChanged,
  });

  @override
  ConsumerState<ExerciseCardWidget> createState() => _ExerciseCardWidgetState();
}

class _ExerciseCardWidgetState extends ConsumerState<ExerciseCardWidget> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final draft = widget.draft;
    final settings = ref.watch(settingsProvider);
    final enabledMetrics = ExerciseMetric.parseMetrics(
      draft.exercise.enabledMetrics,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      MuscleGroupIcon(
                        muscleGroup: draft.exercise.muscleGroup,
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          draft.exercise.name,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headlineSm(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.getMuscleGroupBgColor(
                            draft.exercise.muscleGroup,
                            isDark,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          draft.exercise.muscleGroup.toUpperCase(),
                          style: AppTypography.labelCaps(
                            color: AppColors.getMuscleGroupTextColor(
                              draft.exercise.muscleGroup,
                              isDark,
                            ),
                          ).copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Plate Calculator Helper Button
                    IconButton(
                      icon: const Icon(Icons.calculate_outlined, size: 20),
                      tooltip: 'Plate Calculator',
                      onPressed: widget.onOpenPlateCalculator,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: widget.onRemoveExercise,
                    ),
                  ],
                ),
              ],
            ),

            // Previous Session Ghost Performance Target Guidance
            if (draft.previousSets != null && draft.previousSets!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainerLow.withValues(alpha: 0.6)
                      : AppColors.lightSurfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkOutline
                        : AppColors.lightOutline,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 14,
                      color: isDark
                          ? AppColors.primaryVoltDim
                          : AppColors.lightPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LAST SESSION: ',
                      style: AppTypography.labelCaps(
                        color: isDark
                            ? AppColors.primaryVoltDim
                            : AppColors.lightPrimary,
                      ).copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(
                        draft.previousSets!
                            .map(
                              (s) => MetricFormatter.formatSetSummary(
                                s,
                                enabledMetrics,
                              ),
                            )
                            .join('  •  '),
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ).copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

            // AI Adaptive Progressive Overload Coach Target Banner
            AdaptiveSetCoachBanner(
              exerciseId: draft.exercise.id,
              weightUnit: settings.weightUnit.label,
              onApplyTarget: (recommendedWeight, recommendedReps) {
                setState(() {
                  final targetSet = draft.sets.firstWhere(
                    (s) => !s.isCompleted,
                    orElse: () => draft.sets.last,
                  );
                  targetSet.weight = recommendedWeight;
                  targetSet.weightController.text = recommendedWeight
                      .toStringAsFixed(1)
                      .replaceAll(RegExp(r'\.0$'), '');
                  targetSet.reps = recommendedReps;
                  targetSet.repsController.text = recommendedReps.toString();
                });
                widget.onStateChanged();
              },
            ),

            const SizedBox(height: 12),

            // Sets Header
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    'TYPE',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelCaps(),
                  ),
                ),
                const SizedBox(width: 8),
                ...enabledMetrics.map(
                  (m) => Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        '${m.shortLabel} (${m.defaultUnit.toUpperCase()})',
                        style: AppTypography.labelCaps().copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 80),
              ],
            ),
            const SizedBox(height: 8),

            // Sets List with Dynamic Metric Columns
            ...draft.sets.asMap().entries.map((entry) {
              final index = entry.key;
              final setDraft = entry.value;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    // Set Type Toggle Badge
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (setDraft.type == 'normal') {
                            setDraft.type = 'warmup';
                          } else if (setDraft.type == 'warmup') {
                            setDraft.type = 'drop';
                          } else if (setDraft.type == 'drop') {
                            setDraft.type = 'failure';
                          } else {
                            setDraft.type = 'normal';
                          }
                        });
                        widget.onStateChanged();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 40,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _getSetTypeColor(setDraft.type, isDark),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getSetTypeTextColor(
                              setDraft.type,
                              isDark,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '${_getSetTypePrefix(setDraft.type)}${index + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getSetTypeTextColor(setDraft.type, isDark),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...enabledMetrics.map((m) {
                      TextEditingController controller;
                      FocusNode focusNode;
                      TextInputType keyboardType;
                      String hint;
                      ValueChanged<String> onChanged;

                      switch (m) {
                        case ExerciseMetric.weight:
                          controller = setDraft.weightController;
                          focusNode = setDraft.weightFocusNode;
                          keyboardType = const TextInputType.numberWithOptions(
                            decimal: true,
                          );
                          hint = '0';
                          onChanged =
                              (val) =>
                                  setDraft.weight =
                                      double.tryParse(val.trim()) ?? 0.0;
                          break;
                        case ExerciseMetric.reps:
                          controller = setDraft.repsController;
                          focusNode = setDraft.repsFocusNode;
                          keyboardType = TextInputType.number;
                          hint = '0';
                          onChanged =
                              (val) =>
                                  setDraft.reps = int.tryParse(val.trim()) ?? 0;
                          break;
                        case ExerciseMetric.distance:
                          controller = setDraft.distanceController;
                          focusNode = setDraft.distanceFocusNode;
                          keyboardType = const TextInputType.numberWithOptions(
                            decimal: true,
                          );
                          hint = '0.0';
                          onChanged =
                              (val) =>
                                  setDraft.distance = double.tryParse(
                                    val.trim(),
                                  );
                          break;
                        case ExerciseMetric.time:
                          controller = setDraft.durationController;
                          focusNode = setDraft.durationFocusNode;
                          keyboardType = TextInputType.number;
                          hint = 'sec';
                          onChanged =
                              (val) =>
                                  setDraft.durationSeconds = int.tryParse(
                                    val.trim(),
                                  );
                          break;
                        case ExerciseMetric.incline:
                          controller = setDraft.inclineController;
                          focusNode = setDraft.inclineFocusNode;
                          keyboardType = const TextInputType.numberWithOptions(
                            decimal: true,
                          );
                          hint = '%';
                          onChanged =
                              (val) =>
                                  setDraft.incline = double.tryParse(
                                    val.trim(),
                                  );
                          break;
                        case ExerciseMetric.speed:
                          controller = setDraft.speedController;
                          focusNode = setDraft.speedFocusNode;
                          keyboardType = const TextInputType.numberWithOptions(
                            decimal: true,
                          );
                          hint = 'km/h';
                          onChanged =
                              (val) =>
                                  setDraft.speed = double.tryParse(val.trim());
                          break;
                      }

                      return Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            keyboardType: keyboardType,
                            style: AppTypography.bodyLg(
                              color:
                                  isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              hintText: hint,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onChanged: onChanged,
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        setDraft.isCompleted
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        color: setDraft.isCompleted
                            ? (isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary)
                            : (isDark
                                  ? AppColors.darkOutlineVariant
                                  : AppColors.lightOutline),
                      ),
                      onPressed: () async {
                        final wasCompleted = setDraft.isCompleted;
                        setState(() {
                          setDraft.isCompleted = !setDraft.isCompleted;
                        });
                        widget.onStateChanged();

                        if (!wasCompleted && setDraft.isCompleted) {
                          final appSettings = ref.read(settingsProvider);
                          if (appSettings.autoStartRestTimer) {
                            ref
                                .read(restTimerProvider.notifier)
                                .startTimer(
                                  durationSeconds:
                                      appSettings.defaultRestDuration,
                                );
                          }

                          // Automatic PR Detection & Toast Celebration
                          final db = ref.read(databaseProvider);
                          final prevSets = await db.getPreviousSetsForExercise(
                            draft.exercise.id,
                          );
                          double highestPrevWeight = 0;
                          for (final s in prevSets) {
                            if (s.weight > highestPrevWeight) {
                              highestPrevWeight = s.weight;
                            }
                          }

                          if (setDraft.weight > highestPrevWeight &&
                              setDraft.weight > 0 &&
                              highestPrevWeight > 0) {
                            HapticFeedback.vibrate();
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.emoji_events,
                                        color: Colors.amber,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'NEW WEIGHT PR! ${setDraft.weight % 1 == 0 ? setDraft.weight.toInt() : setDraft.weight} ${setDraft.unit} on ${draft.exercise.name}!',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.purple.shade900,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          } else {
                            HapticFeedback.lightImpact();
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          setDraft.dispose();
                          draft.sets.removeAt(index);
                          for (int i = 0; i < draft.sets.length; i++) {
                            draft.sets[i].setNumber = i + 1;
                          }
                        });
                        widget.onStateChanged();
                      },
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  final lastSet = draft.sets.isNotEmpty
                      ? draft.sets.last
                      : null;
                  final newWeight = lastSet?.weight ?? 60.0;
                  final newReps = lastSet?.reps ?? 10;
                  setState(() {
                    draft.sets.add(
                      SetDraft(
                        setNumber: draft.sets.length + 1,
                        weight: newWeight,
                        reps: newReps,
                        unit: 'kg',
                        type: 'normal',
                      ),
                    );
                  });
                  widget.onStateChanged();
                },
                icon: Icon(
                  Icons.add,
                  size: 18,
                  color: isDark
                      ? AppColors.primaryVolt
                      : AppColors.lightPrimary,
                ),
                label: Text(
                  '+ ADD SET',
                  style: AppTypography.labelCaps(
                    color: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSetTypeColor(String type, bool isDark) {
    switch (type) {
      case 'warmup':
        return isDark
            ? Colors.amber.shade900.withValues(alpha: 0.5)
            : Colors.amber.shade100;
      case 'drop':
        return isDark
            ? Colors.purple.shade900.withValues(alpha: 0.5)
            : Colors.purple.shade100;
      case 'failure':
        return isDark
            ? Colors.red.shade900.withValues(alpha: 0.5)
            : Colors.red.shade100;
      case 'normal':
      default:
        return isDark
            ? AppColors.darkSurfaceContainerHigh
            : AppColors.lightSurfaceContainerLow;
    }
  }

  Color _getSetTypeTextColor(String type, bool isDark) {
    switch (type) {
      case 'warmup':
        return isDark ? Colors.amber.shade300 : Colors.amber.shade900;
      case 'drop':
        return isDark ? Colors.purple.shade300 : Colors.purple.shade900;
      case 'failure':
        return isDark ? Colors.red.shade300 : Colors.red.shade900;
      case 'normal':
      default:
        return isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    }
  }

  String _getSetTypePrefix(String type) {
    switch (type) {
      case 'warmup':
        return 'W';
      case 'drop':
        return 'D';
      case 'failure':
        return 'F';
      case 'normal':
      default:
        return '';
    }
  }
}
