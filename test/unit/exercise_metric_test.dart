import 'package:flutter_test/flutter_test.dart';
import 'package:thews/core/models/exercise_metric.dart';

void main() {
  group('ExerciseMetric Parsing and Serialization Tests', () {
    test('Parses default weight,reps when null or empty', () {
      final metrics = ExerciseMetric.parseMetrics(null);
      expect(metrics, [ExerciseMetric.weight, ExerciseMetric.reps]);
    });

    test('Parses cardio metric list correctly', () {
      final metrics = ExerciseMetric.parseMetrics('distance,time,incline,speed');
      expect(metrics, [
        ExerciseMetric.distance,
        ExerciseMetric.time,
        ExerciseMetric.incline,
        ExerciseMetric.speed,
      ]);
    });

    test('Serializes metrics to string correctly', () {
      final serialized = ExerciseMetric.serializeMetrics([
        ExerciseMetric.distance,
        ExerciseMetric.time,
      ]);
      expect(serialized, 'distance,time');
    });
  });
}
