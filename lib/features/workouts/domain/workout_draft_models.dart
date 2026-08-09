import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';

/// Draft model for an exercise being tracked in an active workout session.
class WorkoutExerciseDraft {
  final ExerciseData exercise;
  final List<SetDraft> sets;
  final List<SetEntryData>? previousSets;

  WorkoutExerciseDraft({
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

/// Draft model for a single set being logged during an active workout.
class SetDraft {
  int setNumber;
  double weight;
  int reps;
  String unit;
  String type; // 'normal' | 'warmup' | 'drop' | 'failure'
  double? distance;
  int? durationSeconds;
  double? incline;
  double? speed;
  String? previousPerformance;
  bool isCompleted = false;

  final FocusNode weightFocusNode = FocusNode();
  final FocusNode repsFocusNode = FocusNode();
  final FocusNode distanceFocusNode = FocusNode();
  final FocusNode durationFocusNode = FocusNode();
  final FocusNode inclineFocusNode = FocusNode();
  final FocusNode speedFocusNode = FocusNode();

  TextEditingController? _weightController;
  TextEditingController? _repsController;
  TextEditingController? _distanceController;
  TextEditingController? _durationController;
  TextEditingController? _inclineController;
  TextEditingController? _speedController;

  SetDraft({
    required this.setNumber,
    required this.weight,
    required this.reps,
    this.unit = 'kg',
    this.type = 'normal',
    this.distance,
    this.durationSeconds,
    this.incline,
    this.speed,
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

  TextEditingController get distanceController {
    return _distanceController ??= TextEditingController(
      text: distance == null || distance == 0 ? '' : distance.toString(),
    );
  }

  TextEditingController get durationController {
    return _durationController ??= TextEditingController(
      text: durationSeconds == null || durationSeconds == 0
          ? ''
          : durationSeconds.toString(),
    );
  }

  TextEditingController get inclineController {
    return _inclineController ??= TextEditingController(
      text: incline == null || incline == 0 ? '' : incline.toString(),
    );
  }

  TextEditingController get speedController {
    return _speedController ??= TextEditingController(
      text: speed == null || speed == 0 ? '' : speed.toString(),
    );
  }

  void dispose() {
    weightFocusNode.dispose();
    repsFocusNode.dispose();
    distanceFocusNode.dispose();
    durationFocusNode.dispose();
    inclineFocusNode.dispose();
    speedFocusNode.dispose();
    _weightController?.dispose();
    _repsController?.dispose();
    _distanceController?.dispose();
    _durationController?.dispose();
    _inclineController?.dispose();
    _speedController?.dispose();
  }
}
