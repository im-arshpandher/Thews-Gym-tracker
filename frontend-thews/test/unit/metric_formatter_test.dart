import 'package:flutter_test/flutter_test.dart';
import 'package:thews/core/database/app_database.dart';
import 'package:thews/core/models/exercise_metric.dart';
import 'package:thews/core/utils/metric_formatter.dart';

void main() {
  group('MetricFormatter Tests', () {
    test('formatSeconds formats durations correctly', () {
      expect(MetricFormatter.formatSeconds(0), '-');
      expect(MetricFormatter.formatSeconds(45), '45s');
      expect(MetricFormatter.formatSeconds(90), '1m 30s');
      expect(MetricFormatter.formatSeconds(300), '5m');
      expect(MetricFormatter.formatSeconds(3665), '1h 1m');
    });

    test('getMetricValueString formats weight, reps, distance, time, speed, incline', () {
      const set = SetEntryData(
        id: 1,
        workoutExerciseId: 1,
        setNumber: 1,
        weight: 80.0,
        reps: 10,
        unit: 'kg',
        type: 'normal',
        distance: 5.5,
        distanceUnit: 'km',
        durationSeconds: 1500, // 25m
        incline: 4.0,
        speed: 10.5,
      );

      expect(
        MetricFormatter.getMetricValueString(set, ExerciseMetric.weight),
        '80 kg',
      );
      expect(
        MetricFormatter.getMetricValueString(set, ExerciseMetric.reps),
        '10 reps',
      );
      expect(
        MetricFormatter.getMetricValueString(set, ExerciseMetric.distance),
        '5.5 km',
      );
      expect(
        MetricFormatter.getMetricValueString(set, ExerciseMetric.time),
        '25m',
      );
      expect(
        MetricFormatter.getMetricValueString(set, ExerciseMetric.incline),
        '4%',
      );
      expect(
        MetricFormatter.getMetricValueString(set, ExerciseMetric.speed),
        '10.5 km/h',
      );
    });

    test('formatSetSummary creates combined summary for enabled metrics', () {
      const set = SetEntryData(
        id: 1,
        workoutExerciseId: 1,
        setNumber: 1,
        weight: 60.0,
        reps: 8,
        unit: 'kg',
        type: 'normal',
        distance: 3.0,
        durationSeconds: 900,
      );

      final weightReps = [ExerciseMetric.weight, ExerciseMetric.reps];
      final cardio = [ExerciseMetric.distance, ExerciseMetric.time];

      expect(
        MetricFormatter.formatSetSummary(set, weightReps),
        '60kg × 8 reps',
      );
      expect(
        MetricFormatter.formatSetSummary(set, cardio),
        '3km × 15m',
      );
    });

    test('getSetTypePrefix returns correct prefixes', () {
      expect(MetricFormatter.getSetTypePrefix('normal'), '');
      expect(MetricFormatter.getSetTypePrefix('warmup'), 'W');
      expect(MetricFormatter.getSetTypePrefix('drop'), 'D');
      expect(MetricFormatter.getSetTypePrefix('failure'), 'F');
    });
  });
}
