enum InterferenceRiskLevel {
  minimal,
  moderate,
  high,
}

/// Result of cellular signaling interference analysis between strength and endurance training.
class InterferenceAdvisorResult {
  final InterferenceRiskLevel riskLevel;
  final String title;
  final String summary;
  final String biochemicalExplanation;
  final Duration recommendedRunDelay;
  final String recommendedSessionType;
  final double interferencePenaltyScore; // 0.0 to 30.0 penalty points

  const InterferenceAdvisorResult({
    required this.riskLevel,
    required this.title,
    required this.summary,
    required this.biochemicalExplanation,
    required this.recommendedRunDelay,
    required this.recommendedSessionType,
    required this.interferencePenaltyScore,
  });

  factory InterferenceAdvisorResult.optimal() {
    return const InterferenceAdvisorResult(
      riskLevel: InterferenceRiskLevel.minimal,
      title: 'Optimal Hybrid Signaling Window',
      summary: 'Cellular pathways clear. No significant mTOR/AMPK interference detected.',
      biochemicalExplanation:
          'Sufficient temporal spacing (> 8 hours) or distinct muscle groups allow uninhibited mTORC1 protein synthesis and aerobic mitochondrial biogenesis.',
      recommendedRunDelay: Duration.zero,
      recommendedSessionType: 'All Training Types (HIIT, Tempo, Hypertrophy, Long Run)',
      interferencePenaltyScore: 0.0,
    );
  }
}

/// Simple model for a recent workout session used in interference optimization.
class HybridLiftingSession {
  final DateTime timestamp;
  final double totalVolumeKg;
  final int legSetsCount;
  final bool hasHeavyLowerBodyCompound; // Squat, Deadlift, Leg Press, Lunge

  const HybridLiftingSession({
    required this.timestamp,
    required this.totalVolumeKg,
    this.legSetsCount = 0,
    this.hasHeavyLowerBodyCompound = false,
  });
}

/// Simple model for a recent or planned endurance session.
class HybridRunningSession {
  final DateTime timestamp;
  final double distanceKm;
  final int durationSeconds;
  final bool isHighIntensity; // Intervals / Hill Sprints / Tempo vs Zone 2 Base

  const HybridRunningSession({
    required this.timestamp,
    required this.distanceKm,
    required this.durationSeconds,
    this.isHighIntensity = false,
  });
}

/// Analyzes concurrent training interference (mTOR vs. AMPK molecular cascades).
class InterferenceOptimizer {
  /// Evaluates interference risk between recent lifting and running activities.
  static InterferenceAdvisorResult evaluateInterference({
    required List<HybridLiftingSession> recentLiftingSessions,
    required List<HybridRunningSession> recentRunningSessions,
    DateTime? referenceTime,
  }) {
    final now = referenceTime ?? DateTime.now();

    if (recentLiftingSessions.isEmpty) {
      return InterferenceAdvisorResult.optimal();
    }

    // Find the most recent heavy leg session within the past 48 hours
    HybridLiftingSession? lastLegSession;
    double hoursSinceLegSession = 999.0;

    for (final session in recentLiftingSessions) {
      if (session.hasHeavyLowerBodyCompound || session.legSetsCount >= 4) {
        final hoursAgo = now.difference(session.timestamp).inMinutes / 60.0;
        if (hoursAgo >= 0 && hoursAgo < hoursSinceLegSession) {
          hoursSinceLegSession = hoursAgo;
          lastLegSession = session;
        }
      }
    }

    // If no heavy leg session in last 48h, signaling interference is minimal
    if (lastLegSession == null || hoursSinceLegSession >= 36.0) {
      return InterferenceAdvisorResult.optimal();
    }

    // High Interference Window (0 to 6 hours post-heavy leg training)
    if (hoursSinceLegSession < 6.0) {
      final remainingCooldown = Duration(minutes: ((6.0 - hoursSinceLegSession) * 60).round());
      return InterferenceAdvisorResult(
        riskLevel: InterferenceRiskLevel.high,
        title: 'High Interference Window (mTOR vs AMPK)',
        summary:
            'Heavy lower-body resistance training was logged ${hoursSinceLegSession.toStringAsFixed(1)}h ago. High-intensity running right now will blunt muscle protein synthesis.',
        biochemicalExplanation:
            'Intense endurance exercise activates AMPK and SIRT1, activating TSC2 and inhibiting the mTORC1 pathway responsible for myofibrillar hypertrophy. A delay of 6–8 hours minimizes this antagonistic effect.',
        recommendedRunDelay: remainingCooldown,
        recommendedSessionType: 'Low-Intensity Zone 2 Active Recovery (< 135 BPM) or Upper Body Lifting',
        interferencePenaltyScore: 25.0,
      );
    }

    // Moderate Interference Window (6 to 24 hours post-heavy leg training)
    if (hoursSinceLegSession < 24.0) {
      final remainingCooldown = Duration(minutes: ((24.0 - hoursSinceLegSession) * 60).round());
      return InterferenceAdvisorResult(
        riskLevel: InterferenceRiskLevel.moderate,
        title: 'Moderate Neuromuscular Fatigue Window',
        summary:
            'Lower body is in active recovery (${hoursSinceLegSession.toStringAsFixed(1)}h ago). Moderate pace is safe, but avoid all-out sprint intervals.',
        biochemicalExplanation:
            'While peak mTOR inhibition has subsided, residual eccentric muscle damage and depleted glycogen stores increase tendon strain during high-impact anaerobic running.',
        recommendedRunDelay: remainingCooldown,
        recommendedSessionType: 'Aerobic Base Run (Zone 2) or Easy Progression Run',
        interferencePenaltyScore: 12.0,
      );
    }

    // Low / Extended Recovery (24 to 36 hours)
    return InterferenceAdvisorResult(
      riskLevel: InterferenceRiskLevel.minimal,
      title: 'Optimal Hybrid Window',
      summary:
          'Sufficient recovery window achieved (${hoursSinceLegSession.toStringAsFixed(1)}h post-legs). Safe for tempo runs or high-intensity intervals.',
      biochemicalExplanation:
          'Glycogen resynthesis and acute muscle damage have stabilized, allowing optimal neuromuscular recruitment for both strength and cardiovascular adaptations.',
      recommendedRunDelay: Duration.zero,
      recommendedSessionType: 'Any Outdoor Activity (Intervals, Tempo, Long Run)',
      interferencePenaltyScore: 0.0,
    );
  }
}
