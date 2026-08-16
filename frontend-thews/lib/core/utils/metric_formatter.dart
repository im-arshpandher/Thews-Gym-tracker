import '../database/app_database.dart';
import '../models/exercise_metric.dart';

/// Central utility for formatting exercise set metrics dynamically based on enabled metrics.
class MetricFormatter {
  /// Returns a clean formatted string for a specific metric from a [SetEntryData].
  static String getMetricValueString(SetEntryData set, ExerciseMetric metric) {
    switch (metric) {
      case ExerciseMetric.weight:
        final wStr = set.weight % 1 == 0
            ? set.weight.toInt().toString()
            : set.weight.toString();
        return '$wStr ${set.unit}';
      case ExerciseMetric.reps:
        return '${set.reps} reps';
      case ExerciseMetric.distance:
        if (set.distance == null || set.distance == 0) return '-';
        final dStr = set.distance! % 1 == 0
            ? set.distance!.toInt().toString()
            : set.distance!.toString();
        return '$dStr ${set.distanceUnit ?? "km"}';
      case ExerciseMetric.time:
        if (set.durationSeconds == null || set.durationSeconds == 0) return '-';
        return formatSeconds(set.durationSeconds!);
      case ExerciseMetric.incline:
        if (set.incline == null || set.incline == 0) return '-';
        final incStr = set.incline! % 1 == 0
            ? set.incline!.toInt().toString()
            : set.incline!.toString();
        return '$incStr%';
      case ExerciseMetric.speed:
        if (set.speed == null || set.speed == 0) return '-';
        final spdStr = set.speed! % 1 == 0
            ? set.speed!.toInt().toString()
            : set.speed!.toString();
        return '$spdStr km/h';
    }
  }

  /// Formats seconds into a human readable duration string (e.g., 1h 15m, 25m 30s, or 45s).
  static String formatSeconds(int totalSeconds) {
    if (totalSeconds <= 0) return '-';
    final hours = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;

    if (hours > 0) {
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h ${secs}s';
    } else if (mins > 0) {
      return secs > 0 ? '${mins}m ${secs}s' : '${mins}m';
    } else {
      return '${secs}s';
    }
  }

  /// Formats set performance summary for ghost targets or quick preview lists.
  static String formatSetSummary(
    SetEntryData set,
    List<ExerciseMetric> enabledMetrics,
  ) {
    final List<String> parts = [];

    for (final metric in enabledMetrics) {
      switch (metric) {
        case ExerciseMetric.weight:
          if (set.weight > 0) {
            final wStr = set.weight % 1 == 0
                ? set.weight.toInt().toString()
                : set.weight.toString();
            parts.add('$wStr${set.unit}');
          }
          break;
        case ExerciseMetric.reps:
          if (set.reps > 0) {
            parts.add('${set.reps} reps');
          }
          break;
        case ExerciseMetric.distance:
          if (set.distance != null && set.distance! > 0) {
            final dStr = set.distance! % 1 == 0
                ? set.distance!.toInt().toString()
                : set.distance!.toString();
            parts.add('$dStr${set.distanceUnit ?? "km"}');
          }
          break;
        case ExerciseMetric.time:
          if (set.durationSeconds != null && set.durationSeconds! > 0) {
            parts.add(formatSeconds(set.durationSeconds!));
          }
          break;
        case ExerciseMetric.incline:
          if (set.incline != null && set.incline! > 0) {
            final incStr = set.incline! % 1 == 0
                ? set.incline!.toInt().toString()
                : set.incline!.toString();
            parts.add('$incStr% incl');
          }
          break;
        case ExerciseMetric.speed:
          if (set.speed != null && set.speed! > 0) {
            final spdStr = set.speed! % 1 == 0
                ? set.speed!.toInt().toString()
                : set.speed!.toString();
            parts.add('$spdStr km/h');
          }
          break;
      }
    }

    if (parts.isEmpty) {
      final wStr = set.weight % 1 == 0
          ? set.weight.toInt().toString()
          : set.weight.toString();
      return '$wStr${set.unit} × ${set.reps} reps';
    }

    return parts.join(' × ');
  }

  /// Helper to get set type badge prefix label ('W', 'D', 'F', '')
  static String getSetTypePrefix(String type) {
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
