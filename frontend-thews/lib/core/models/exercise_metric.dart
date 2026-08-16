import 'package:flutter/material.dart';

enum ExerciseMetric {
  weight,
  reps,
  distance,
  time,
  incline,
  speed;

  String get key => name;

  String get label {
    switch (this) {
      case ExerciseMetric.weight:
        return 'Weight';
      case ExerciseMetric.reps:
        return 'Reps';
      case ExerciseMetric.distance:
        return 'Distance';
      case ExerciseMetric.time:
        return 'Time / Duration';
      case ExerciseMetric.incline:
        return 'Incline (%)';
      case ExerciseMetric.speed:
        return 'Speed';
    }
  }

  String get shortLabel {
    switch (this) {
      case ExerciseMetric.weight:
        return 'WEIGHT';
      case ExerciseMetric.reps:
        return 'REPS';
      case ExerciseMetric.distance:
        return 'DIST';
      case ExerciseMetric.time:
        return 'TIME';
      case ExerciseMetric.incline:
        return 'INCLINE';
      case ExerciseMetric.speed:
        return 'SPEED';
    }
  }

  IconData get icon {
    switch (this) {
      case ExerciseMetric.weight:
        return Icons.fitness_center;
      case ExerciseMetric.reps:
        return Icons.repeat;
      case ExerciseMetric.distance:
        return Icons.directions_run;
      case ExerciseMetric.time:
        return Icons.timer;
      case ExerciseMetric.incline:
        return Icons.trending_up;
      case ExerciseMetric.speed:
        return Icons.speed;
    }
  }

  String get defaultUnit {
    switch (this) {
      case ExerciseMetric.weight:
        return 'kg';
      case ExerciseMetric.reps:
        return 'reps';
      case ExerciseMetric.distance:
        return 'km';
      case ExerciseMetric.time:
        return 'min';
      case ExerciseMetric.incline:
        return '%';
      case ExerciseMetric.speed:
        return 'km/h';
    }
  }

  static List<ExerciseMetric> parseMetrics(String? metricsStr) {
    if (metricsStr == null || metricsStr.trim().isEmpty) {
      return [ExerciseMetric.weight, ExerciseMetric.reps];
    }
    try {
      final keys =
          metricsStr.split(',').map((s) => s.trim().toLowerCase()).toList();
      final List<ExerciseMetric> result = [];
      for (final key in keys) {
        for (final m in ExerciseMetric.values) {
          if (m.name.toLowerCase() == key) {
            result.add(m);
            break;
          }
        }
      }
      return result.isEmpty
          ? [ExerciseMetric.weight, ExerciseMetric.reps]
          : result;
    } catch (_) {
      return [ExerciseMetric.weight, ExerciseMetric.reps];
    }
  }

  static String serializeMetrics(Iterable<ExerciseMetric> metrics) {
    if (metrics.isEmpty) return 'weight,reps';
    return metrics.map((m) => m.name).join(',');
  }
}
