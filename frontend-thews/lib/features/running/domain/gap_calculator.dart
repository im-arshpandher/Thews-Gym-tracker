import 'dart:math' as math;

/// Minetti Grade-Adjusted Pace (GAP) Computational Engine.
///
/// Implements the physiological polynomial cost of running on slopes
/// derived by Minetti et al. (2002):
/// C_r(i) = 155.4 * i^5 - 30.4 * i^4 - 43.3 * i^3 + 46.3 * i^2 + 19.5 * i + 3.6
/// where i is the incline gradient (decimal: +0.10 for +10% grade).
class GapCalculator {
  /// Baseline energy cost on flat ground (i = 0): C_r(0) = 3.6 J / (kg * m)
  static const double flatEnergyCost = 3.6;

  /// Computes the energetic cost of running at a given gradient i.
  /// Gradient i is decimal (e.g. 0.05 for 5% uphill, -0.05 for 5% downhill).
  static double calculateEnergyCost(double gradient) {
    // Clamp gradient within physiological running limits [-0.45, 0.45]
    final i = gradient.clamp(-0.45, 0.45);

    final i2 = i * i;
    final i3 = i2 * i;
    final i4 = i3 * i;
    final i5 = i4 * i;

    final cost = (155.4 * i5) -
        (30.4 * i4) -
        (43.3 * i3) +
        (46.3 * i2) +
        (19.5 * i) +
        3.6;

    // Energy cost cannot drop below minimal biomechanical cost (~2.2 J/kg*m)
    return math.max(2.2, cost);
  }

  /// Calculates Grade-Adjusted Pace (seconds per km) from actual pace and gradient.
  ///
  /// For an uphill (+10%), actual pace 6:00/km (360s) will produce a faster GAP
  /// (e.g. ~4:30/km or ~270s) representing the equivalent flat-ground effort.
  static double calculateGapPace({
    required double actualPaceSecondsPerKm,
    required double gradient,
  }) {
    if (actualPaceSecondsPerKm <= 0.0 || actualPaceSecondsPerKm.isInfinite) {
      return 0.0;
    }

    final slopeCost = calculateEnergyCost(gradient);
    // Ratio of flat ground cost to slope cost
    final costRatio = flatEnergyCost / slopeCost;

    final gapPace = actualPaceSecondsPerKm * costRatio;
    return math.max(60.0, gapPace); // Clamped to realistic running minimum (1:00/km)
  }

  /// Formats pace in seconds per km to a standard "MM:SS /km" string.
  static String formatPace(double paceSecondsPerKm) {
    if (paceSecondsPerKm <= 0.0 || paceSecondsPerKm.isInfinite) {
      return '--:-- /km';
    }
    final mins = (paceSecondsPerKm ~/ 60).toString().padLeft(2, '0');
    final secs = (paceSecondsPerKm % 60).toInt().toString().padLeft(2, '0');
    return '$mins:$secs /km';
  }

  /// Calculates gradient from elevation delta and distance delta.
  static double calculateGradient({
    required double elevationDeltaMeters,
    required double distanceDeltaMeters,
  }) {
    if (distanceDeltaMeters <= 1.0) return 0.0;
    return elevationDeltaMeters / distanceDeltaMeters;
  }
}
