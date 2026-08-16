import 'package:flutter_test/flutter_test.dart';
import 'package:thews/features/ai_coach/domain/ai_coach_models.dart';
import 'package:thews/features/ai_coach/domain/progressive_overload_engine.dart';
import 'package:thews/features/ai_coach/domain/recovery_fatigue_calculator.dart';

void main() {
  group('Epley 1RM Formula & Cold Start Tests', () {
    test('calculateEpleyOneRm returns accurate mathematical values', () {
      expect(ProgressiveOverloadEngine.calculateEpleyOneRm(100.0, 1), 100.0);
      expect(ProgressiveOverloadEngine.calculateEpleyOneRm(100.0, 10), closeTo(133.33, 0.01));
      expect(ProgressiveOverloadEngine.calculateEpleyOneRm(0.0, 10), 0.0);
      expect(ProgressiveOverloadEngine.calculateEpleyOneRm(100.0, 0), 0.0);
    });

    test('Cold start without previous sessions provides baseline maintain target', () {
      final rec = ProgressiveOverloadEngine.computeRecommendation(
        exerciseId: 1,
        exerciseName: 'Barbell Bench Press',
        muscleGroup: 'Chest',
        sessionHistories: [],
        defaultWeight: 60.0,
        defaultTargetReps: 8,
      );

      expect(rec.recommendedWeight, 60.0);
      expect(rec.recommendedReps, 8);
      expect(rec.strategy, OverloadStrategy.maintain);
      expect(rec.isDeload, isFalse);
    });
  });

  group('Double Progression Model & Weight Steps Tests', () {
    test('Increases load by +5.0 kg for lower body compound when top reps (8) reached', () {
      final history = [
        ExerciseSessionHistory(
          workoutDate: DateTime(2026, 8, 1),
          workingSets: const [
            HistoricalSet(weight: 100.0, reps: 8, type: 'normal'),
            HistoricalSet(weight: 100.0, reps: 8, type: 'normal'),
          ],
        ),
      ];

      final rec = ProgressiveOverloadEngine.computeRecommendation(
        exerciseId: 2,
        exerciseName: 'Barbell Back Squat',
        muscleGroup: 'Legs',
        sessionHistories: history,
      );

      expect(rec.strategy, OverloadStrategy.increaseWeight);
      expect(rec.recommendedWeight, 105.0); // +5kg
      expect(rec.recommendedReps, 6); // floor reps
      expect(rec.headline, contains('+5 kg Overload'));
    });

    test('Increases load by +2.5 kg for upper body compound when top reps (8) reached', () {
      final history = [
        ExerciseSessionHistory(
          workoutDate: DateTime(2026, 8, 1),
          workingSets: const [
            HistoricalSet(weight: 80.0, reps: 8, type: 'normal'),
          ],
        ),
      ];

      final rec = ProgressiveOverloadEngine.computeRecommendation(
        exerciseId: 3,
        exerciseName: 'Overhead Shoulder Press',
        muscleGroup: 'Shoulders',
        sessionHistories: history,
      );

      expect(rec.strategy, OverloadStrategy.increaseWeight);
      expect(rec.recommendedWeight, 82.5); // +2.5kg
      expect(rec.recommendedReps, 6);
      expect(rec.headline, contains('+2.5 kg Overload'));
    });

    test('Progresses reps (+1 rep) when athlete has not yet hit upper rep threshold', () {
      final history = [
        ExerciseSessionHistory(
          workoutDate: DateTime(2026, 8, 1),
          workingSets: const [
            HistoricalSet(weight: 80.0, reps: 6, type: 'normal'),
          ],
        ),
      ];

      final rec = ProgressiveOverloadEngine.computeRecommendation(
        exerciseId: 3,
        exerciseName: 'Barbell Bench Press',
        muscleGroup: 'Chest',
        sessionHistories: history,
      );

      expect(rec.strategy, OverloadStrategy.increaseReps);
      expect(rec.recommendedWeight, 80.0);
      expect(rec.recommendedReps, 7); // 6 -> 7
      expect(rec.headline, contains('+1 Reps Progression'));
    });
  });

  group('Stagnation & Strategic Deload Detection Tests', () {
    test('Triggers deload when 3 consecutive sessions show stagnation or 1RM decline', () {
      final history = [
        ExerciseSessionHistory(
          workoutDate: DateTime(2026, 8, 1),
          workingSets: const [
            HistoricalSet(weight: 100.0, reps: 6, type: 'normal'), // 1RM ~ 120
          ],
        ),
        ExerciseSessionHistory(
          workoutDate: DateTime(2026, 8, 5),
          workingSets: const [
            HistoricalSet(weight: 100.0, reps: 5, type: 'normal'), // 1RM ~ 116.6
          ],
        ),
        ExerciseSessionHistory(
          workoutDate: DateTime(2026, 8, 9),
          workingSets: const [
            HistoricalSet(weight: 100.0, reps: 5, type: 'normal'), // 1RM ~ 116.6
          ],
        ),
      ];

      final rec = ProgressiveOverloadEngine.computeRecommendation(
        exerciseId: 4,
        exerciseName: 'Barbell Deadlift',
        muscleGroup: 'Back',
        sessionHistories: history,
      );

      expect(rec.strategy, OverloadStrategy.deload);
      expect(rec.isDeload, isTrue);
      expect(rec.recommendedWeight, 85.0); // 100 * 0.85
      expect(rec.reason, contains('3 consecutive sessions without 1RM progression'));
    });
  });

  group('Recovery & Fatigue Index Calculator Tests', () {
    test('Fresh user returns 100% readiness across all muscle groups', () {
      final state = RecoveryFatigueCalculator.computeSystemicReadiness(
        recentEvents: [],
      );

      expect(state.overallReadinessScore, 100.0);
      expect(state.muscleReadiness.length, 6);
      expect(state.muscleReadiness.every((m) => m.recoveryPercentage == 100.0), isTrue);
      expect(state.muscleReadiness.every((m) => m.tier == ReadinessTier.optimal), isTrue);
    });

    test('Heavy workout 12 hours ago reflects significant muscle fatigue', () {
      final now = DateTime(2026, 8, 16, 12, 0);
      final events = [
        MuscleWorkoutEvent(
          muscleGroup: 'Chest',
          timestamp: DateTime(2026, 8, 16, 0, 0), // 12 hours ago
          totalVolume: 5000.0,
          totalSets: 5,
        ),
      ];

      final state = RecoveryFatigueCalculator.computeSystemicReadiness(
        recentEvents: events,
        referenceTime: now,
      );

      final chest = state.muscleReadiness.firstWhere((m) => m.muscleGroup == 'Chest');
      expect(chest.recoveryPercentage, lessThan(50.0));
      expect(chest.tier, ReadinessTier.fatigued);

      // Back and Legs should still be 100% recovered
      final back = state.muscleReadiness.firstWhere((m) => m.muscleGroup == 'Back');
      expect(back.recoveryPercentage, 100.0);
      expect(back.tier, ReadinessTier.optimal);

      // Today's recommendation should suggest pulling or legs, not pushing
      expect(state.recommendedSplit, isNot(contains('Push')));
    });

    test('Resting heart rate elevation applies systemic recovery penalty', () {
      final state = RecoveryFatigueCalculator.computeSystemicReadiness(
        recentEvents: [],
        restingHeartRateBpm: 88.0, // High resting heart rate
      );

      expect(state.overallReadinessScore, lessThan(100.0));
      expect(state.alerts.any((a) => a.contains('Elevated resting heart rate')), isTrue);
    });
  });
}
