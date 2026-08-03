import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/muscle_group.dart';
import '../../../core/presentation/widgets/muscle_group_icon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../exercises/presentation/exercises_provider.dart';
import 'rest_timer_provider.dart';
import 'routines_provider.dart';
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
  final List<_WorkoutExerciseDraft> _selectedExercises = [];

  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isTimerRunning = false;
  bool _hasStartedWorkout = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
  }

  void _startTimer() {
    if (_isTimerRunning) return;
    setState(() {
      _hasStartedWorkout = true;
      _isTimerRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _isTimerRunning = false;
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _hasStartedWorkout = false;
        _isTimerRunning = false;
        _secondsElapsed = 0;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _workoutTitleController.dispose();
    _notesController.dispose();
    for (final draft in _selectedExercises) {
      draft.dispose();
    }
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _addExercise(ExerciseData exercise) async {
    final db = ref.read(databaseProvider);
    final prevSets = await db.getPreviousSetsForExercise(exercise.id);

    List<_SetDraft> initialSets = [];
    if (prevSets.isNotEmpty) {
      initialSets = prevSets.asMap().entries.map((entry) {
        final idx = entry.key;
        final pSet = entry.value;
        final prevPerf =
            '${pSet.weight % 1 == 0 ? pSet.weight.toInt() : pSet.weight} ${pSet.unit} × ${pSet.reps} reps';
        return _SetDraft(
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
        _SetDraft(
          setNumber: 1,
          weight: 60.0,
          reps: 10,
          unit: 'kg',
          type: 'normal',
        ),
        _SetDraft(
          setNumber: 2,
          weight: 60.0,
          reps: 10,
          unit: 'kg',
          type: 'normal',
        ),
        _SetDraft(
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
          _WorkoutExerciseDraft(
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
      final initialSets = List.generate(d.routineExercise.targetSets, (idx) {
        final pSet = idx < prevSets.length ? prevSets[idx] : null;
        final prevPerf = pSet != null
            ? '${pSet.weight % 1 == 0 ? pSet.weight.toInt() : pSet.weight} ${pSet.unit} × ${pSet.reps} reps'
            : null;
        return _SetDraft(
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
        _WorkoutExerciseDraft(
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
            ),
          );
        }
      }

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
                    (draft) => _buildExerciseCard(context, draft),
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

  Widget _buildExerciseCard(BuildContext context, _WorkoutExerciseDraft draft) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    // Plate Calculator Helper Button (Phase 1.4)
                    IconButton(
                      icon: const Icon(Icons.calculate_outlined, size: 20),
                      tooltip: 'Plate Calculator',
                      onPressed: () => _openPlateCalculator(
                        draft.sets.isNotEmpty ? draft.sets.first.weight : 60.0,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        setState(() {
                          draft.dispose();
                          _selectedExercises.remove(draft);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),

            // Previous Session Ghost Performance Target Guidance (Phase 1.1)
            if (draft.previousSets != null && draft.previousSets!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainer
                      : AppColors.lightSurfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
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
                              (s) =>
                                  '${s.weight % 1 == 0 ? s.weight.toInt() : s.weight}${s.unit}×${s.reps}',
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
                Expanded(
                  flex: 2,
                  child: Text('WEIGHT (KG)', style: AppTypography.labelCaps()),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text('REPS', style: AppTypography.labelCaps()),
                ),
                const SizedBox(width: 80),
              ],
            ),
            const SizedBox(height: 8),

            // Sets List with Set Types Badge Toggle (Phase 2.1) & Focus Traversal (Phase 1.3)
            ...draft.sets.asMap().entries.map((entry) {
              final index = entry.key;
              final setDraft = entry.value;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    // Set Type Toggle Badge (W = Warmup, N/Wk = Normal, D = Drop, F = Failure)
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
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: setDraft.weightController,
                        focusNode: setDraft.weightFocusNode,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            setDraft.repsFocusNode.requestFocus(),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: AppTypography.bodyLg(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          hintText: setDraft.previousPerformance != null
                              ? setDraft.previousPerformance!.split(' ').first
                              : '0',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (val) {
                          setDraft.weight = double.tryParse(val.trim()) ?? 0.0;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: setDraft.repsController,
                        focusNode: setDraft.repsFocusNode,
                        textInputAction: TextInputAction.done,
                        keyboardType: TextInputType.number,
                        style: AppTypography.bodyLg(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          hintText: setDraft.previousPerformance != null
                              ? setDraft.previousPerformance!
                                    .split('×')
                                    .last
                                    .replaceAll('reps', '')
                                    .trim()
                              : '0',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (val) {
                          setDraft.reps = int.tryParse(val.trim()) ?? 0;
                        },
                      ),
                    ),
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

                        if (!wasCompleted && setDraft.isCompleted) {
                          ref
                              .read(restTimerProvider.notifier)
                              .startTimer(durationSeconds: 90);

                          // Automatic PR Detection & Toast Celebration (Phase 3.3)
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
                  setState(() {
                    final lastSet = draft.sets.isNotEmpty
                        ? draft.sets.last
                        : null;
                    final newWeight = lastSet?.weight ?? 60.0;
                    final newReps = lastSet?.reps ?? 10;
                    draft.sets.add(
                      _SetDraft(
                        setNumber: draft.sets.length + 1,
                        weight: newWeight,
                        reps: newReps,
                        unit: 'kg',
                        type: 'normal',
                      ),
                    );
                  });
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
          _AddExerciseBottomSheet(onSelectExercise: (ex) => _addExercise(ex)),
    );
  }
}

class _AddExerciseBottomSheet extends ConsumerStatefulWidget {
  final ValueChanged<ExerciseData> onSelectExercise;

  const _AddExerciseBottomSheet({required this.onSelectExercise});

  @override
  ConsumerState<_AddExerciseBottomSheet> createState() =>
      _AddExerciseBottomSheetState();
}

class _AddExerciseBottomSheetState
    extends ConsumerState<_AddExerciseBottomSheet> {
  String _selectedGroup = 'All';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exercisesAsync = ref.watch(allExercisesProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.lightSurfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handlebar & Title Bar
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Add Exercise to Session',
                      style: AppTypography.headlineMd(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                style: AppTypography.bodyMd(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search exercises...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark
                        ? AppColors.darkOutlineVariant
                        : AppColors.lightOutline,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),

              // Top Muscle Group Selection Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: MuscleGroup.values.map((group) {
                    final isSelected = _selectedGroup == group.label;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(group.label.toUpperCase()),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedGroup = group.label;
                          });
                        },
                        selectedColor: isDark
                            ? AppColors.primaryVolt
                            : AppColors.lightPrimaryContainer,
                        backgroundColor: isDark
                            ? AppColors.darkSurfaceContainer
                            : AppColors.lightSurfaceContainerLow,
                        checkmarkColor: isDark
                            ? AppColors.primaryVoltOn
                            : AppColors.lightPrimaryDark,
                        labelStyle: AppTypography.labelCaps(
                          color: isSelected
                              ? (isDark
                                    ? AppColors.primaryVoltOn
                                    : AppColors.lightPrimaryDark)
                              : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                        ),
                        shape: const StadiumBorder(),
                        side: BorderSide(
                          color: isSelected
                              ? (isDark
                                    ? AppColors.primaryVolt
                                    : AppColors.lightPrimary)
                              : Colors.transparent,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Exercises List
              Expanded(
                child: exercisesAsync.when(
                  data: (allExercises) {
                    // Filter by selected muscle group and search query locally
                    final filtered = allExercises.where((ex) {
                      final matchesGroup =
                          _selectedGroup == 'All' ||
                          ex.muscleGroup.toLowerCase() ==
                              _selectedGroup.toLowerCase();
                      final matchesSearch =
                          _searchQuery.isEmpty ||
                          ex.name.toLowerCase().contains(_searchQuery);
                      return matchesGroup && matchesSearch;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fitness_center_outlined,
                              size: 48,
                              color: isDark
                                  ? AppColors.darkOutlineVariant
                                  : AppColors.lightOutlineVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No exercises found',
                              style: AppTypography.bodyLg(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: isDark
                            ? AppColors.darkOutline.withValues(alpha: 0.15)
                            : AppColors.lightOutline.withValues(alpha: 0.15),
                      ),
                      itemBuilder: (context, index) {
                        final ex = filtered[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          leading: MuscleGroupIcon(
                            muscleGroup: ex.muscleGroup,
                            size: 44,
                          ),
                          title: Text(
                            ex.name,
                            style: AppTypography.bodyLg(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.getMuscleGroupBgColor(
                                    ex.muscleGroup,
                                    isDark,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ex.muscleGroup.toUpperCase(),
                                  style:
                                      AppTypography.labelCaps(
                                        color:
                                            AppColors.getMuscleGroupTextColor(
                                              ex.muscleGroup,
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
                          trailing: IconButton(
                            icon: Icon(
                              Icons.add_circle,
                              color: isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary,
                              size: 28,
                            ),
                            onPressed: () {
                              widget.onSelectExercise(ex);
                              Navigator.of(context).pop();
                            },
                          ),
                          onTap: () {
                            widget.onSelectExercise(ex);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryVolt,
                    ),
                  ),
                  error: (e, s) =>
                      Center(child: Text('Error loading exercises: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutExerciseDraft {
  final ExerciseData exercise;
  final List<_SetDraft> sets;
  final List<SetEntryData>? previousSets;

  _WorkoutExerciseDraft({
    required this.exercise,
    required this.sets,
    this.previousSets,
  });

  void dispose() {
    for (final s in sets) {
      s.dispose();
    }
  }
}

class _SetDraft {
  int setNumber;
  double weight;
  int reps;
  String unit;
  String type; // 'normal' | 'warmup' | 'drop' | 'failure'
  String? previousPerformance;
  bool isCompleted = false;

  final FocusNode weightFocusNode = FocusNode();
  final FocusNode repsFocusNode = FocusNode();
  TextEditingController? _weightController;
  TextEditingController? _repsController;

  _SetDraft({
    required this.setNumber,
    required this.weight,
    required this.reps,
    this.unit = 'kg',
    this.type = 'normal',
    this.previousPerformance,
  });

  TextEditingController get weightController {
    return _weightController ??= TextEditingController(
      text: weight == 0
          ? ''
          : (weight % 1 == 0 ? weight.toInt().toString() : weight.toString()),
    );
  }

  TextEditingController get repsController {
    return _repsController ??= TextEditingController(
      text: reps == 0 ? '' : reps.toString(),
    );
  }

  void dispose() {
    weightFocusNode.dispose();
    repsFocusNode.dispose();
    _weightController?.dispose();
    _repsController?.dispose();
  }
}
