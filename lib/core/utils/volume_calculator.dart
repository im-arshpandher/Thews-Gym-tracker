class VolumeCalculator {
  static const double lbsToKgFactor = 0.45359237;

  /// Calculates deterministic volume for a set entry in kg (or requested unit).
  /// Warmup sets are excluded (return 0.0 volume).
  static double calculateSetVolume({
    required double weight,
    required int reps,
    required String type,
    required String unit,
  }) {
    if (type.toLowerCase() == 'warmup') return 0.0;

    final normalizedWeight =
        unit.toLowerCase() == 'lbs' ? weight * lbsToKgFactor : weight;
    return normalizedWeight * reps;
  }

  /// Calculates total volume for a list of set entries.
  static double calculateTotalVolume(Iterable<dynamic> sets) {
    double total = 0.0;
    for (final s in sets) {
      final double weight = (s.weight as num).toDouble();
      final int reps = (s.reps as num).toInt();
      final String type = s.type as String;
      final String unit = s.unit as String;
      total += calculateSetVolume(
        weight: weight,
        reps: reps,
        type: type,
        unit: unit,
      );
    }
    return total;
  }
}
