import 'dart:math' as math;

/// Training Impulse (TRIMP) & Workload analysis results.
class WorkloadAnalysis {
  final double trimpScore; // e.g. 85.4
  final double acuteWorkload; // 7-day rolling average TRIMP
  final double chronicWorkload; // 28-day rolling average TRIMP
  final double acwr; // Acute:Chronic Workload Ratio
  final String riskZone; // "Optimal Sweet Spot", "Under-training", "Caution", "Danger Zone"
  final String recommendations;

  const WorkloadAnalysis({
    required this.trimpScore,
    required this.acuteWorkload,
    required this.chronicWorkload,
    required this.acwr,
    required this.riskZone,
    required this.recommendations,
  });
}

/// Computational engine for Bannister TRIMP and Acute-to-Chronic Workload Ratio (ACWR).
class TrimpWorkloadCalculator {
  /// Computes Bannister TRIMP for a single session.
  /// Duration in seconds, heart rates in BPM.
  static double calculateTrimp({
    required int durationSeconds,
    required int averageHeartRateBpm,
    int restingHeartRateBpm = 60,
    int maxHeartRateBpm = 190,
  }) {
    if (durationSeconds <= 0 || averageHeartRateBpm <= restingHeartRateBpm) {
      return 0.0;
    }

    final durationMinutes = durationSeconds / 60.0;
    final hrReserve = (maxHeartRateBpm - restingHeartRateBpm).toDouble();
    if (hrReserve <= 0) return 0.0;

    final hrRatio = ((averageHeartRateBpm - restingHeartRateBpm) / hrReserve)
        .clamp(0.0, 1.0);

    // Standard Bannister weighting equation (Men y = 1.92, Women y = 1.67; 1.92 default)
    final trimp = durationMinutes * hrRatio * 0.64 * math.exp(1.92 * hrRatio);
    return double.parse(trimp.toStringAsFixed(1));
  }

  /// Calculates Acute:Chronic Workload Ratio (ACWR) given daily TRIMP loads.
  /// [dailyTrimpsLast28Days] is an ordered list of the past 28 daily TRIMP values (newest first or oldest first).
  static WorkloadAnalysis evaluateAcwr({
    required double currentSessionTrimp,
    required List<double> past28DaysDailyTrimps,
  }) {
    final trimps = List<double>.from(past28DaysDailyTrimps);
    if (trimps.length < 28) {
      // Pad with zeros if less than 28 days of history
      final missing = 28 - trimps.length;
      trimps.addAll(List.filled(missing, 0.0));
    }

    // Acute: average of the last 7 days
    final acuteDays = trimps.take(7).toList();
    final acuteAvg = acuteDays.reduce((a, b) => a + b) / 7.0;

    // Chronic: average of all 28 days
    final chronicAvg = trimps.reduce((a, b) => a + b) / 28.0;

    final double acwr;
    if (chronicAvg <= 0.5) {
      acwr = acuteAvg > 0 ? 1.0 : 0.0;
    } else {
      acwr = double.parse((acuteAvg / chronicAvg).toStringAsFixed(2));
    }

    final String riskZone;
    final String recommendations;

    if (acwr < 0.8) {
      riskZone = 'Under-training Zone';
      recommendations =
          'Training stimulus is below baseline. Safe to gradually ramp up weekly volume.';
    } else if (acwr <= 1.3) {
      riskZone = 'Optimal Sweet Spot';
      recommendations =
          'Workload is perfectly balanced for progressive fitness gains while keeping injury risk minimal.';
    } else if (acwr <= 1.5) {
      riskZone = 'Caution Zone';
      recommendations =
          'Workload is ramping up rapidly. Monitor leg tightness and ensure adequate sleep.';
    } else {
      riskZone = 'Overtraining Danger Zone';
      recommendations =
          'Acute spike in workload (ACWR > 1.5). High risk of tendon and joint strain. Recommend an easy recovery day.';
    }

    return WorkloadAnalysis(
      trimpScore: currentSessionTrimp,
      acuteWorkload: double.parse(acuteAvg.toStringAsFixed(1)),
      chronicWorkload: double.parse(chronicAvg.toStringAsFixed(1)),
      acwr: acwr,
      riskZone: riskZone,
      recommendations: recommendations,
    );
  }
}
