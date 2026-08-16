import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/exercise_metric.dart';
import '../../../core/models/smartwatch_models.dart';
import '../../../core/services/health_platform_service.dart';
import '../../../core/services/smartwatch_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/metric_formatter.dart';

import '../domain/workout_draft_models.dart';
import 'rest_timer_provider.dart';
import 'routines_provider.dart';
import 'widgets/add_exercise_bottom_sheet.dart';
import 'widgets/exercise_card_widget.dart';
import 'widgets/live_heart_rate_hud.dart';
import 'widgets/plate_calculator_sheet.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  final _workoutTitleController = TextEditingController(
    text: 'Untitled Session',
  );
  final _notesController = TextEditingController();
  final List<WorkoutExerciseDraft> _selectedExercises = [];

  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isTimerRunning = false;
  bool _hasStartedWorkout = false;
  bool _isSaving = false;
  DateTime? _workoutStartTime;
  DateTime? _pauseStartTime;
  Duration _totalPausedDuration = Duration.zero;
  StreamSubscription<WristSetAction>? _wristSub;

  @override
  void initState() {
    super.initState();
    _initWristSyncListener();
  }

  void _initWristSyncListener() {
    _wristSub = ref
        .read(smartwatchServiceProvider.notifier)
        .wristActionStream
        .listen((action) {
      if (!mounted) return;
      if (action.actionType == WristActionType.completeSet) {
        for (final exDraft in _selectedExercises) {
          if (action.exerciseName.isEmpty ||
              exDraft.exercise.name.toLowerCase() ==
                  action.exerciseName.toLowerCase()) {
            final targetSet = exDraft.sets.firstWhere(
              (s) => !s.isCompleted,
              orElse: () => exDraft.sets.last,
            );
            setState(() {
              targetSet.isCompleted = true;
              if (action.weightKg != null) targetSet.weight = action.weightKg!;
              if (action.reps != null) targetSet.reps = action.reps!;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Wrist logged: ${exDraft.exercise.name} (Set ${targetSet.setNumber})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: AppColors.primaryVolt,
                duration: const Duration(seconds: 2),
              ),
            );
            break;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _wristSub?.cancel();
    _timer?.cancel();
    _workoutTitleController.dispose();
    _notesController.dispose();
    for (final draft in _selectedExercises) {
      draft.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    if (_isTimerRunning) return;
    final now = DateTime.now();
    if (_workoutStartTime == null) {
      _workoutStartTime = now;
      _totalPausedDuration = Duration.zero;
    } else if (_pauseStartTime != null) {
      _totalPausedDuration += now.difference(_pauseStartTime!);
      _pauseStartTime = null;
    }

    setState(() {
      _hasStartedWorkout = true;
      _isTimerRunning = true;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isTimerRunning && _workoutStartTime != null) {
        final activeSecs = DateTime.now()
                .difference(_workoutStartTime!)
                .inSeconds -
            _totalPausedDuration.inSeconds;
        setState(() => _secondsElapsed = activeSecs < 0 ? 0 : activeSecs);
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    if (_isTimerRunning) {
      _pauseStartTime = DateTime.now();
    }
    if (mounted) {
      setState(() {
        _isTimerRunning = false;
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = null;
    _workoutStartTime = null;
    _pauseStartTime = null;
    _totalPausedDuration = Duration.zero;
    if (mounted) {
      setState(() {
        _hasStartedWorkout = false;
        _isTimerRunning = false;
        _secondsElapsed = 0;
      });
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _addExercise(ExerciseData exercise) async {
    final db = ref.read(databaseProvider);
    final prevSets = await db.getPreviousSetsForExercise(exercise.id);

    final enabledMetrics = ExerciseMetric.parseMetrics(exercise.enabledMetrics);
    List<SetDraft> initialSets = [];
    if (prevSets.isNotEmpty) {
      initialSets = prevSets.asMap().entries.map((entry) {
        final idx = entry.key;
        final pSet = entry.value;
        final prevPerf = MetricFormatter.formatSetSummary(pSet, enabledMetrics);
        return SetDraft(
          setNumber: idx + 1,
          weight: pSet.weight,
          reps: pSet.reps,
          unit: pSet.unit,
          type: pSet.type,
          previousPerformance: prevPerf,
        );
      }).toList();
    } else {
      initialSets = [
        SetDraft(
          setNumber: 1,
          weight: 60.0,
          reps: 10,
          unit: 'kg',
          type: 'normal',
        ),
        SetDraft(
          setNumber: 2,
          weight: 60.0,
          reps: 10,
          unit: 'kg',
          type: 'normal',
        ),
        SetDraft(
          setNumber: 3,
          weight: 60.0,
          reps: 8,
          unit: 'kg',
          type: 'normal',
        ),
      ];
    }

    if (mounted) {
      setState(() {
        _selectedExercises.add(
          WorkoutExerciseDraft(
            exercise: exercise,
            sets: initialSets,
            previousSets: prevSets,
          ),
        );
      });
    }
  }

  Future<void> _loadRoutineTemplate(RoutineData routine) async {
    final db = ref.read(databaseProvider);
    final details = await db.watchRoutineDetails(routine.id).first;
    if (details.isEmpty) return;

    _workoutTitleController.text = routine.name;
    for (final draft in _selectedExercises) {
      draft.dispose();
    }
    _selectedExercises.clear();
    _startTimer();

    for (final d in details) {
      final prevSets = await db.getPreviousSetsForExercise(d.exercise.id);
      final enabledMetrics = ExerciseMetric.parseMetrics(d.exercise.enabledMetrics);
      final initialSets = List.generate(d.routineExercise.targetSets, (idx) {
        final pSet = idx < prevSets.length ? prevSets[idx] : null;
        final prevPerf = pSet != null
            ? MetricFormatter.formatSetSummary(pSet, enabledMetrics)
            : null;
        return SetDraft(
          setNumber: idx + 1,
          weight: d.routineExercise.targetWeight > 0
              ? d.routineExercise.targetWeight
              : (pSet?.weight ?? 60.0),
          reps: d.routineExercise.targetReps,
          unit: 'kg',
          type: 'normal',
          previousPerformance: prevPerf,
        );
      });

      _selectedExercises.add(
        WorkoutExerciseDraft(
          exercise: d.exercise,
          sets: initialSets,
          previousSets: prevSets,
        ),
      );
    }
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded Routine: "${routine.name}"'),
          backgroundColor: AppColors.primaryVolt,
        ),
      );
    }
  }

  void _showRoutinesSelector(BuildContext context) {
    final routinesAsync = ref.read(allRoutinesProvider);
    routinesAsync.whenData((routines) {
      if (routines.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No saved routine templates found.')),
        );
        return;
      }
      showDialog(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Load Routine Template'),
          children: routines.map((r) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                _loadRoutineTemplate(r);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (r.description != null)
                      Text(
                        r.description!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  void _openPlateCalculator(double initialWeight) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlateCalculatorSheet(initialWeight: initialWeight),
    );
  }

  Future<void> _finishWorkout() async {
    if (_isSaving) return;
    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add at least one exercise before completing workout',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    _pauseTimer();
    ref.read(restTimerProvider.notifier).stopTimer();

    try {
      final db = ref.read(databaseProvider);

      // Save Workout
      final workoutId = await db.insertWorkout(
        WorkoutsCompanion.insert(
          date: Value(DateTime.now()),
          notes: Value(
            _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : _workoutTitleController.text.trim(),
          ),
          durationSeconds: Value(_secondsElapsed),
        ),
      );

      // Save Exercises & Sets (with Set Types!)
      for (int i = 0; i < _selectedExercises.length; i++) {
        final exDraft = _selectedExercises[i];
        final workoutExId = await db.insertWorkoutExercise(
          WorkoutExercisesCompanion.insert(
            workoutId: workoutId,
            exerciseId: exDraft.exercise.id,
            sortOrder: Value(i),
          ),
        );

        for (final setDraft in exDraft.sets) {
          await db.insertSetEntry(
            SetEntriesCompanion.insert(
              workoutExerciseId: workoutExId,
              setNumber: setDraft.setNumber,
              weight: setDraft.weight,
              reps: setDraft.reps,
              unit: Value(setDraft.unit),
              type: Value(setDraft.type),
              distance: Value(setDraft.distance),
              durationSeconds: Value(setDraft.durationSeconds),
              incline: Value(setDraft.incline),
              speed: Value(setDraft.speed),
            ),
          );
        }
      }

      // Calculate Volume and Export to Health Platform
      double totalVolume = 0.0;
      for (final ex in _selectedExercises) {
        for (final s in ex.sets) {
          if (s.isCompleted) {
            totalVolume += (s.weight * s.reps);
          }
        }
      }
      final watchState = ref.read(smartwatchServiceProvider);
      final activeCalories = watchState.activeCaloriesBurned > 0
          ? watchState.activeCaloriesBurned
          : (_secondsElapsed / 60.0) * 6.5;
      final avgHr = watchState.currentBpm > 0 ? watchState.currentBpm : 125;

      ref.read(healthPlatformServiceProvider.notifier).exportWorkoutSessionToHealth(
        title: _workoutTitleController.text.trim().isNotEmpty
            ? _workoutTitleController.text.trim()
            : 'Strength Workout',
        startTime: _workoutStartTime ??
            DateTime.now().subtract(Duration(seconds: _secondsElapsed)),
        endTime: DateTime.now(),
        activeCalories: activeCalories,
        averageHeartRate: avgHr,
        totalVolumeKg: totalVolume,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Workout Saved! Duration: ${_formatDuration(_secondsElapsed)}',
              style: AppTypography.bodyMd(color: AppColors.primaryVoltOn),
            ),
            backgroundColor: AppColors.primaryVolt,
          ),
        );
        setState(() {
          for (final draft in _selectedExercises) {
            draft.dispose();
          }
          _selectedExercises.clear();
          _secondsElapsed = 0;
          _isTimerRunning = false;
          _hasStartedWorkout = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving workout: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final restTimerState = ref.watch(restTimerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'LOG WORKOUT',
          style: AppTypography.headlineMd(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            tooltip: 'Load Routine Template',
            onPressed: () => _showRoutinesSelector(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Explicit Timer Control Header Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceContainerHigh
                  : AppColors.lightSurfaceContainerLow,
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? AppColors.darkOutline.withValues(alpha: 0.2)
                      : AppColors.lightOutline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        _isTimerRunning
                            ? Icons.timer_outlined
                            : Icons.timer_off_outlined,
                        color: _isTimerRunning
                            ? (isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary)
                            : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatDuration(_secondsElapsed),
                          style: AppTypography.headlineSm(
                            color: _isTimerRunning
                                ? (isDark
                                      ? AppColors.primaryVolt
                                      : AppColors.lightPrimary)
                                : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary),
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _isTimerRunning
                              ? 'RUNNING'
                              : (_secondsElapsed > 0 ? 'PAUSED' : 'READY'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelCaps(
                            color: _isTimerRunning
                                ? (isDark
                                      ? AppColors.primaryVoltDim
                                      : AppColors.lightPrimary)
                                : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary),
                          ).copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isTimerRunning)
                      ElevatedButton.icon(
                        onPressed: _startTimer,
                        icon: const Icon(Icons.play_arrow, size: 14),
                        label: Text(
                          _secondsElapsed > 0 ? 'RESUME' : 'START WORKOUT',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryVolt,
                          foregroundColor: AppColors.primaryVoltOn,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: const StadiumBorder(),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _pauseTimer,
                        icon: const Icon(Icons.pause, size: 14),
                        label: const Text(
                          'PAUSE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: const StadiumBorder(),
                        ),
                      ),
                    if (_secondsElapsed > 0 && !_isTimerRunning) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        tooltip: 'Reset Timer',
                        onPressed: _resetTimer,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const LiveHeartRateHud(),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Session Header Title
                TextField(
                  controller: _workoutTitleController,
                  style: AppTypography.headlineLg(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Workout Session Title',
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 12),

                // Selected Exercises
                if (_selectedExercises.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceContainer
                          : AppColors.lightSurfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkOutline
                            : AppColors.lightOutline,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _hasStartedWorkout
                              ? Icons.fitness_center
                              : Icons.play_circle_outline,
                          size: 48,
                          color: isDark
                              ? AppColors.primaryVoltDim
                              : AppColors.lightPrimary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _hasStartedWorkout
                              ? 'No exercises added yet'
                              : 'Workout session not started',
                          style: AppTypography.bodyLg(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hasStartedWorkout
                              ? 'Tap below to add exercises, or load a Routine template'
                              : 'Tap START WORKOUT above or button below to start session and add exercises',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySm(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (!_hasStartedWorkout)
                              ElevatedButton.icon(
                                onPressed: _startTimer,
                                icon: const Icon(Icons.play_arrow, size: 16),
                                label: const Text(
                                  'START WORKOUT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryVolt,
                                  foregroundColor: AppColors.primaryVoltOn,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => _showRoutinesSelector(context),
                              icon: const Icon(
                                Icons.assignment_outlined,
                                size: 18,
                              ),
                              label: const Text('LOAD ROUTINE'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  ..._selectedExercises.map(
                    (draft) => ExerciseCardWidget(
                      draft: draft,
                      onRemoveExercise: () {
                        setState(() {
                          draft.dispose();
                          _selectedExercises.remove(draft);
                        });
                      },
                      onOpenPlateCalculator: () => _openPlateCalculator(
                        draft.sets.isNotEmpty ? draft.sets.first.weight : 60.0,
                      ),
                      onStateChanged: () => setState(() {}),
                    ),
                  ),

                const SizedBox(height: 20),

                // Add Exercise Button
                OutlinedButton.icon(
                  onPressed: () => _showAddExerciseBottomSheet(context),
                  icon: Icon(
                    _hasStartedWorkout ? Icons.add : Icons.lock_outline,
                    color: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                  ),
                  label: Text(
                    _hasStartedWorkout
                        ? 'ADD EXERCISE'
                        : 'START WORKOUT TO ADD EXERCISES',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelCaps(
                      color: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Integrated Rest Timer Floating Bar (Phase 1.2)
          if (restTimerState.secondsRemaining > 0 || restTimerState.isExpired)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: restTimerState.isExpired
                    ? Colors.red.shade900
                    : (isDark
                          ? AppColors.darkSurfaceContainerHigh
                          : AppColors.lightSurfaceContainerLow),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: restTimerState.isExpired
                      ? Colors.redAccent
                      : (isDark
                            ? AppColors.primaryVolt
                            : AppColors.lightPrimary),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    restTimerState.isExpired ? Icons.alarm_on : Icons.timer,
                    color: restTimerState.isExpired
                        ? Colors.white
                        : (isDark
                              ? AppColors.primaryVolt
                              : AppColors.lightPrimary),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        restTimerState.isExpired
                            ? 'REST COMPLETE!'
                            : 'REST TIMER',
                        style: AppTypography.labelCaps(
                          color: restTimerState.isExpired
                              ? Colors.white70
                              : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                        ).copyWith(fontSize: 10),
                      ),
                      Text(
                        restTimerState.isExpired
                            ? '00:00'
                            : restTimerState.formattedTime,
                        style: AppTypography.headlineSm(
                          color: restTimerState.isExpired
                              ? Colors.white
                              : (isDark
                                    ? AppColors.primaryVolt
                                    : AppColors.lightPrimary),
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (!restTimerState.isExpired) ...[
                    TextButton(
                      onPressed: () =>
                          ref.read(restTimerProvider.notifier).addTime(30),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        '+30s',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        restTimerState.isRunning
                            ? Icons.pause
                            : Icons.play_arrow,
                        size: 20,
                      ),
                      onPressed: () {
                        if (restTimerState.isRunning) {
                          ref.read(restTimerProvider.notifier).pauseTimer();
                        } else {
                          ref.read(restTimerProvider.notifier).resumeTimer();
                        }
                      },
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () =>
                        ref.read(restTimerProvider.notifier).stopTimer(),
                  ),
                ],
              ),
            ),

          // Bottom Finish Workout Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceContainerLow
                  : AppColors.lightSurfaceContainerLowest,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _finishWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryVolt,
                  foregroundColor: AppColors.primaryVoltOn,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: const StadiumBorder(),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(
                        color: AppColors.primaryVoltOn,
                      )
                    : const Text(
                        'FINISH WORKOUT',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryVoltOn,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExerciseBottomSheet(BuildContext context) {
    if (!_hasStartedWorkout) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Start your workout session first before adding exercises!',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'START NOW',
            textColor: Colors.white,
            onPressed: () {
              _startTimer();
              _showAddExerciseBottomSheet(context);
            },
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AddExerciseBottomSheet(onSelectExercise: (ex) => _addExercise(ex)),
    );
  }
}
