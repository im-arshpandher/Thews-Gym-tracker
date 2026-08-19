import { z } from 'zod';

export const CreateRunActivitySchema = z.object({
  profileId: z.string().optional().nullable(),
  workoutId: z.number().int().positive().optional().nullable(),
  activityType: z.enum(['run', 'walk', 'cycle']).default('run'),
  startTime: z.coerce.date().default(() => new Date()),
  distanceMeters: z.number().min(0),
  durationSeconds: z.number().int().min(0),
  avgPaceSecondsPerKm: z.number().min(0).default(0.0),
  elevationGainMeters: z.number().default(0.0),
  gpxData: z.string().optional().nullable(),
});

export const RunQuerySchema = z.object({
  profileId: z.string().optional(),
  activityType: z.enum(['run', 'walk', 'cycle']).optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

export type CreateRunActivityInput = z.infer<typeof CreateRunActivitySchema>;
export type RunQueryInput = z.infer<typeof RunQuerySchema>;
