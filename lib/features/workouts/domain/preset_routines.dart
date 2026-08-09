class PresetRoutineExercise {
  final String exerciseName;
  final String muscleGroup;
  final int targetSets;
  final int targetReps;

  const PresetRoutineExercise({
    required this.exerciseName,
    required this.muscleGroup,
    this.targetSets = 3,
    this.targetReps = 10,
  });
}

class PresetRoutine {
  final String name;
  final String description;
  final List<PresetRoutineExercise> exercises;

  const PresetRoutine({
    required this.name,
    required this.description,
    required this.exercises,
  });

  static const List<PresetRoutine> starterTemplates = [
    PresetRoutine(
      name: 'Push Hypertrophy',
      description: 'Focus on Chest, Shoulders & Triceps growth',
      exercises: [
        PresetRoutineExercise(
          exerciseName: 'Barbell Bench Press',
          muscleGroup: 'Chest',
          targetSets: 4,
          targetReps: 8,
        ),
        PresetRoutineExercise(
          exerciseName: 'Incline Dumbbell Press',
          muscleGroup: 'Chest',
          targetSets: 3,
          targetReps: 10,
        ),
        PresetRoutineExercise(
          exerciseName: 'Overhead Shoulder Press',
          muscleGroup: 'Shoulders',
          targetSets: 3,
          targetReps: 10,
        ),
        PresetRoutineExercise(
          exerciseName: 'Lateral Raise',
          muscleGroup: 'Shoulders',
          targetSets: 3,
          targetReps: 15,
        ),
        PresetRoutineExercise(
          exerciseName: 'Tricep Rope Pushdown',
          muscleGroup: 'Arms',
          targetSets: 3,
          targetReps: 12,
        ),
      ],
    ),
    PresetRoutine(
      name: 'Pull Power',
      description: 'Complete Back & Biceps workout for strength & width',
      exercises: [
        PresetRoutineExercise(
          exerciseName: 'Conventional Deadlift',
          muscleGroup: 'Back',
          targetSets: 3,
          targetReps: 6,
        ),
        PresetRoutineExercise(
          exerciseName: 'Lat Pulldown',
          muscleGroup: 'Back',
          targetSets: 4,
          targetReps: 10,
        ),
        PresetRoutineExercise(
          exerciseName: 'Bent Over Row',
          muscleGroup: 'Back',
          targetSets: 3,
          targetReps: 10,
        ),
        PresetRoutineExercise(
          exerciseName: 'Bicep Barbell Curl',
          muscleGroup: 'Arms',
          targetSets: 3,
          targetReps: 12,
        ),
      ],
    ),
    PresetRoutine(
      name: 'Legs & Lower Body',
      description: 'Quads, Hamstrings & Calves strength & size',
      exercises: [
        PresetRoutineExercise(
          exerciseName: 'Barbell Squat',
          muscleGroup: 'Legs',
          targetSets: 4,
          targetReps: 8,
        ),
        PresetRoutineExercise(
          exerciseName: 'Romanian Deadlift',
          muscleGroup: 'Legs',
          targetSets: 3,
          targetReps: 10,
        ),
        PresetRoutineExercise(
          exerciseName: 'Leg Press',
          muscleGroup: 'Legs',
          targetSets: 3,
          targetReps: 12,
        ),
      ],
    ),
    PresetRoutine(
      name: 'Upper Body Power',
      description: 'Heavy compound movements for upper body development',
      exercises: [
        PresetRoutineExercise(
          exerciseName: 'Barbell Bench Press',
          muscleGroup: 'Chest',
          targetSets: 4,
          targetReps: 6,
        ),
        PresetRoutineExercise(
          exerciseName: 'Bent Over Row',
          muscleGroup: 'Back',
          targetSets: 4,
          targetReps: 6,
        ),
        PresetRoutineExercise(
          exerciseName: 'Overhead Shoulder Press',
          muscleGroup: 'Shoulders',
          targetSets: 3,
          targetReps: 8,
        ),
        PresetRoutineExercise(
          exerciseName: 'Lat Pulldown',
          muscleGroup: 'Back',
          targetSets: 3,
          targetReps: 10,
        ),
      ],
    ),
    PresetRoutine(
      name: 'Full Body Foundations',
      description: 'Balanced full body workout targeting major muscle groups',
      exercises: [
        PresetRoutineExercise(
          exerciseName: 'Barbell Squat',
          muscleGroup: 'Legs',
          targetSets: 3,
          targetReps: 10,
        ),
        PresetRoutineExercise(
          exerciseName: 'Barbell Bench Press',
          muscleGroup: 'Chest',
          targetSets: 3,
          targetReps: 10,
        ),
        PresetRoutineExercise(
          exerciseName: 'Lat Pulldown',
          muscleGroup: 'Back',
          targetSets: 3,
          targetReps: 10,
        ),
        PresetRoutineExercise(
          exerciseName: 'Hanging Leg Raise',
          muscleGroup: 'Core',
          targetSets: 3,
          targetReps: 12,
        ),
      ],
    ),
  ];
}
