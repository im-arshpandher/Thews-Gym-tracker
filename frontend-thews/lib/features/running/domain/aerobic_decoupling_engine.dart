/// Aerobic Decoupling & Cardiac Drift analysis result.
class DecouplingAnalysis {
  final double decouplingPercentage; // e.g. 3.2%
  final double firstHalfEf; // Efficiency Factor = Speed / HR
  final double secondHalfEf;
  final double firstHalfAvgPace;
  final double secondHalfAvgPace;
  final int firstHalfAvgHr;
  final int secondHalfAvgHr;
  final String statusHeadline; // "Optimal Aerobic Base", "Moderate Cardiac Drift", "High Fatigue / Decoupling"
  final String explanation;
  final bool isDecoupled; // true if > 5.0%

  const DecouplingAnalysis({
    required this.decouplingPercentage,
    required this.firstHalfEf,
    required this.secondHalfEf,
    required this.firstHalfAvgPace,
    required this.secondHalfAvgPace,
    required this.firstHalfAvgHr,
    required this.secondHalfAvgHr,
    required this.statusHeadline,
    required this.explanation,
    required this.isDecoupled,
  });
}

/// Computational engine for Aerobic Decoupling (Cardiac Drift).
class AerobicDecouplingEngine {
  /// Computes cardiac decoupling between first half and second half of an activity.
  static DecouplingAnalysis analyze({
    required double firstHalfDistanceMeters,
    required int firstHalfDurationSeconds,
    required int firstHalfAvgHr,
    required double secondHalfDistanceMeters,
    required int secondHalfDurationSeconds,
    required int secondHalfAvgHr,
  }) {
    if (firstHalfDurationSeconds <= 0 ||
        secondHalfDurationSeconds <= 0 ||
        firstHalfAvgHr <= 0 ||
        secondHalfAvgHr <= 0) {
      return const DecouplingAnalysis(
        decouplingPercentage: 0.0,
        firstHalfEf: 0.0,
        secondHalfEf: 0.0,
        firstHalfAvgPace: 0.0,
        secondHalfAvgPace: 0.0,
        firstHalfAvgHr: 0,
        secondHalfAvgHr: 0,
        statusHeadline: 'Insufficient Biometric Data',
        explanation: 'Heart rate telemetry was unavailable for this workout.',
        isDecoupled: false,
      );
    }

    final speed1 = firstHalfDistanceMeters / firstHalfDurationSeconds; // m/s
    final speed2 = secondHalfDistanceMeters / secondHalfDurationSeconds;

    final ef1 = speed1 / firstHalfAvgHr;
    final ef2 = speed2 / secondHalfAvgHr;

    final pace1 = firstHalfDistanceMeters > 0
        ? (firstHalfDurationSeconds / (firstHalfDistanceMeters / 1000.0))
        : 0.0;
    final pace2 = secondHalfDistanceMeters > 0
        ? (secondHalfDurationSeconds / (secondHalfDistanceMeters / 1000.0))
        : 0.0;

    double decouplingPct = 0.0;
    if (ef1 > 0.0) {
      decouplingPct = ((ef1 - ef2) / ef1) * 100.0;
    }

    final roundedPct = double.parse(decouplingPct.toStringAsFixed(1));
    final bool isDecoupled = roundedPct > 5.0;

    final String headline;
    final String explanation;

    if (roundedPct <= 3.5) {
      headline = 'Optimal Aerobic Base (${roundedPct.abs()}%)';
      explanation =
          'Minimal cardiac drift. Cardiovascular output remained remarkably steady across the entire duration.';
    } else if (roundedPct <= 5.0) {
      headline = 'Normal Cardiac Drift ($roundedPct%)';
      explanation =
          'Mild expected cardiovascular drift. Aerobic conditioning is well-aligned with this pacing and distance.';
    } else {
      headline = 'High Aerobic Decoupling ($roundedPct%)';
      explanation =
          'Significant cardiac drift detected (>5%). Heart rate rose relative to running speed due to dehydration, heat, or glycogen depletion.';
    }

    return DecouplingAnalysis(
      decouplingPercentage: roundedPct,
      firstHalfEf: double.parse(ef1.toStringAsFixed(4)),
      secondHalfEf: double.parse(ef2.toStringAsFixed(4)),
      firstHalfAvgPace: pace1,
      secondHalfAvgPace: pace2,
      firstHalfAvgHr: firstHalfAvgHr,
      secondHalfAvgHr: secondHalfAvgHr,
      statusHeadline: headline,
      explanation: explanation,
      isDecoupled: isDecoupled,
    );
  }
}
