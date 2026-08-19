import { z } from 'zod';

export const SetEntryInputSchema = z.object({
  setNumber: z.number().int().min(1),
  weight: z.number().min(0),
  reps: z.number().int().min(0),
  unit: z.string().default('kg'),
  type: z.enum(['warmup', 'normal', 'drop', 'failure']).default('normal'),
  distance: z.number().nullable().optional(),
  distanceUnit: z.string().nullable().optional().default('km'),
  durationSeconds: z.number().int().nullable().optional(),
  incline: z.number().nullable().optional(),
  speed: z.number().nullable().optional(),
});

export const WorkoutExerciseInputSchema = z.object({
  exerciseId: z.number().int().positive(),
  sortOrder: z.number().int().default(0),
  sets: z.array(SetEntryInputSchema).min(1),
});

export const CreateWorkoutSchema = z.object({
  profileId: z.string().optional().nullable(),
  date: z.coerce.date().default(() => new Date()),
  notes: z.string().max(1000).optional().nullable(),
  durationSeconds: z.number().int().min(0).default(0),
  exercises: z.array(WorkoutExerciseInputSchema).default([]),
});

export const UpdateWorkoutSchema = z.object({
  profileId: z.string().optional().nullable(),
  date: z.coerce.date().optional(),
  notes: z.string().max(1000).optional().nullable(),
  durationSeconds: z.number().int().min(0).optional(),
  exercises: z.array(WorkoutExerciseInputSchema).optional(),
});

export const WorkoutQuerySchema = z.object({
  profileId: z.string().optional(),
  startDate: z.coerce.date().optional(),
  endDate: z.coerce.date().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

export type CreateWorkoutInput = z.infer<typeof CreateWorkoutSchema>;
export type UpdateWorkoutInput = z.infer<typeof UpdateWorkoutSchema>;
export type WorkoutQueryInput = z.infer<typeof WorkoutQuerySchema>;
