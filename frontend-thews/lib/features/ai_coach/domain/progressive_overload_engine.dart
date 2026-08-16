import 'dart:math' as math;
import 'ai_coach_models.dart';

/// Core computational engine for dynamic progressive overload and auto-regulation.
class ProgressiveOverloadEngine {
  /// Calculate estimated 1 Rep Max using the Epley formula:
  /// 1RM = Weight * (1 + Reps / 30)
  static double calculateEpleyOneRm(double weight, int reps) {
    if (weight <= 0.0 || reps <= 0) return 0.0;
    if (reps == 1) return weight;
    return weight * (1.0 + (reps / 30.0));
  }

  /// Evaluates historical workout sessions for an exercise and generates
  /// an optimal progressive overload recommendation.
  static OverloadRecommendation computeRecommendation({
    required int exerciseId,
    required String exerciseName,
    required String muscleGroup,
    required List<ExerciseSessionHistory> sessionHistories,
    double defaultWeight = 20.0,
    int defaultTargetReps = 8,
  }) {
    // 1. Cold Start: No historical data available
    if (sessionHistories.isEmpty) {
      final initialWeight = defaultWeight;
      final initialReps = defaultTargetReps;
      final initial1RM = calculateEpleyOneRm(initialWeight, initialReps);
      return OverloadRecommendation(
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        recommendedWeight: initialWeight,
        recommendedReps: initialReps,
        strategy: OverloadStrategy.maintain,
        reason: 'Baseline calibration target. Focus on controlled eccentric tempo.',
        estimatedOneRm: initial1RM,
        estimatedOneRmDelta: 0.0,
      );
    }

    // Sort histories from oldest to newest
    final sortedHistories = List<ExerciseSessionHistory>.from(sessionHistories)
      ..sort((a, b) => a.workoutDate.compareTo(b.workoutDate));

    final latestSession = sortedHistories.last;
    final latestTopSet = latestSession.topSet;

    if (latestTopSet == null) {
      return OverloadRecommendation(
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        recommendedWeight: defaultWeight,
        recommendedReps: defaultTargetReps,
        strategy: OverloadStrategy.maintain,
        reason: 'Calibrating baseline target after empty previous session.',
        estimatedOneRm: calculateEpleyOneRm(defaultWeight, defaultTargetReps),
      );
    }

    final prevWeight = latestTopSet.weight;
    final prevReps = latestTopSet.reps;
    final prev1RM = calculateEpleyOneRm(prevWeight, prevReps);

    // Determine exercise load increment category
    final isLower = _isLowerBody(muscleGroup, exerciseName);
    final isArmOrIsolation = _isIsolation(muscleGroup, exerciseName);

    final double weightIncrement = isLower
        ? 5.0
        : isArmOrIsolation
            ? 1.25
            : 2.5;

    final int targetTopReps = isArmOrIsolation ? 12 : 8;
    final int targetFloorReps = isArmOrIsolation ? 8 : 6;

    // 2. Deload & Stagnation Detection: Check last 3 distinct sessions
    if (sortedHistories.length >= 3) {
      final last3 = sortedHistories.sublist(sortedHistories.length - 3);
      final oneRms = last3.map((s) => s.maxOneRm).toList();

      final isStagnant = oneRms[2] <= oneRms[1] && oneRms[1] <= oneRms[0];
      final isDegrading = (oneRms[0] - oneRms[2]) > 0.0;

      if (isStagnant || isDegrading) {
        // Recommend Deload: -15% weight, maintain floor reps
        final deloadWeight = _roundToNearestPlate(prevWeight * 0.85);
        final deloadReps = math.max(targetFloorReps, prevReps - 2);
        final deload1RM = calculateEpleyOneRm(deloadWeight, deloadReps);

        return OverloadRecommendation(
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          recommendedWeight: deloadWeight,
          recommendedReps: deloadReps,
          strategy: OverloadStrategy.deload,
          reason:
              '3 consecutive sessions without 1RM progression. 1-week strategic deload to clear systemic fatigue.',
          previousWeight: prevWeight,
          previousReps: prevReps,
          estimatedOneRm: deload1RM,
          estimatedOneRmDelta: deload1RM - prev1RM,
          isDeload: true,
        );
      }
    }

    // 3. Double Progression Model
    // Condition A: User reached or exceeded top of target rep range
    if (prevReps >= targetTopReps) {
      final nextWeight = prevWeight + weightIncrement;
      final nextReps = targetFloorReps;
      final next1RM = calculateEpleyOneRm(nextWeight, nextReps);

      return OverloadRecommendation(
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        recommendedWeight: nextWeight,
        recommendedReps: nextReps,
        strategy: OverloadStrategy.increaseWeight,
        reason:
            'Hit target $prevReps reps in previous session. Step up load by +${weightIncrement.toStringAsFixed(1)} kg.',
        previousWeight: prevWeight,
        previousReps: prevReps,
        estimatedOneRm: next1RM,
        estimatedOneRmDelta: next1RM - prev1RM,
      );
    }

    // Condition B: User is in the middle of the rep range -> Progress Reps
    final nextReps = prevReps + 1;
    final next1RM = calculateEpleyOneRm(prevWeight, nextReps);

    return OverloadRecommendation(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      recommendedWeight: prevWeight,
      recommendedReps: nextReps,
      strategy: OverloadStrategy.increaseReps,
      reason:
          'Maintain ${prevWeight.toStringAsFixed(1)} kg and push +1 rep toward $targetTopReps-rep overload threshold.',
      previousWeight: prevWeight,
      previousReps: prevReps,
      estimatedOneRm: next1RM,
      estimatedOneRmDelta: next1RM - prev1RM,
    );
  }

  static bool _isLowerBody(String muscleGroup, String name) {
    final lowerName = name.toLowerCase();
    final lowerMuscle = muscleGroup.toLowerCase();
    if (lowerMuscle == 'legs') return true;
    return lowerName.contains('squat') ||
        lowerName.contains('deadlift') ||
        lowerName.contains('lunge') ||
        lowerName.contains('leg press');
  }

  static bool _isIsolation(String muscleGroup, String name) {
    final lowerName = name.toLowerCase();
    final lowerMuscle = muscleGroup.toLowerCase();
    if (lowerMuscle == 'arms' || lowerMuscle == 'core' || lowerMuscle == 'calves') {
      return true;
    }
    return lowerName.contains('curl') ||
        lowerName.contains('extension') ||
        lowerName.contains('raise') ||
        lowerName.contains('fly');
  }

  static double _roundToNearestPlate(double weight, [double minIncrement = 2.5]) {
    if (weight <= 0) return 0.0;
    return (weight / minIncrement).round() * minIncrement;
  }
}
