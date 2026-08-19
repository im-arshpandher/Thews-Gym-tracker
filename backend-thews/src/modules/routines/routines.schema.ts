import { z } from 'zod';

export const RoutineExerciseInputSchema = z.object({
  exerciseId: z.number().int().positive(),
  targetSets: z.number().int().min(1).default(3),
  targetReps: z.number().int().min(1).default(10),
  targetWeight: z.number().min(0).default(0.0),
  targetDistance: z.number().nullable().optional(),
  targetDurationSeconds: z.number().int().nullable().optional(),
  targetIncline: z.number().nullable().optional(),
  sortOrder: z.number().int().default(0),
});

export const CreateRoutineSchema = z.object({
  profileId: z.string().optional().nullable(),
  name: z.string().min(1).max(100),
  description: z.string().max(500).optional().nullable(),
  exercises: z.array(RoutineExerciseInputSchema).default([]),
});

export const UpdateRoutineSchema = z.object({
  profileId: z.string().optional().nullable(),
  name: z.string().min(1).max(100).optional(),
  description: z.string().max(500).optional().nullable(),
  exercises: z.array(RoutineExerciseInputSchema).optional(),
});

export type CreateRoutineInput = z.infer<typeof CreateRoutineSchema>;
export type UpdateRoutineInput = z.infer<typeof UpdateRoutineSchema>;
