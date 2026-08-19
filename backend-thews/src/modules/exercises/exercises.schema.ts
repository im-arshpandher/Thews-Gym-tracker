import { z } from 'zod';

export const CreateExerciseSchema = z.object({
  name: z.string().min(1).max(100),
  muscleGroup: z.string().min(1).max(50),
  secondaryMuscleGroups: z.string().max(255).optional().nullable(),
  videoUrl: z.string().url().optional().nullable(),
  category: z.string().default('weight_reps'),
  enabledMetrics: z.string().default('weight,reps'),
  profileId: z.string().optional().nullable(),
});

export const UpdateExerciseSchema = CreateExerciseSchema.partial();

export const ExerciseQuerySchema = z.object({
  muscleGroup: z.string().optional(),
  category: z.string().optional(),
  search: z.string().optional(),
  profileId: z.string().optional(),
});

export type CreateExerciseInput = z.infer<typeof CreateExerciseSchema>;
export type UpdateExerciseInput = z.infer<typeof UpdateExerciseSchema>;
export type ExerciseQueryInput = z.infer<typeof ExerciseQuerySchema>;
