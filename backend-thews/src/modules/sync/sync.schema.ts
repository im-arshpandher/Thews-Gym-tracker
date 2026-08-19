import { z } from 'zod';

export const SyncPushSchema = z.object({
  profileId: z.string().optional().nullable(),
  lastPulledAt: z.coerce.date().nullable().optional(),
  workouts: z
    .array(
      z.object({
        clientLocalId: z.number().optional(),
        id: z.number().optional(),
        profileId: z.string().optional().nullable(),
        date: z.coerce.date(),
        notes: z.string().nullable().optional(),
        durationSeconds: z.number().default(0),
        isDeleted: z.boolean().default(false),
        updatedAt: z.coerce.date().optional(),
        exercises: z.array(
          z.object({
            exerciseId: z.number(),
            sortOrder: z.number().default(0),
            sets: z.array(
              z.object({
                setNumber: z.number(),
                weight: z.number(),
                reps: z.number(),
                unit: z.string().default('kg'),
                type: z.string().default('normal'),
                distance: z.number().nullable().optional(),
                distanceUnit: z.string().nullable().optional(),
                durationSeconds: z.number().nullable().optional(),
                incline: z.number().nullable().optional(),
                speed: z.number().nullable().optional(),
              })
            ),
          })
        ),
      })
    )
    .default([]),
  routines: z
    .array(
      z.object({
        id: z.number().optional(),
        profileId: z.string().optional().nullable(),
        name: z.string(),
        description: z.string().nullable().optional(),
        isDeleted: z.boolean().default(false),
        updatedAt: z.coerce.date().optional(),
        exercises: z.array(
          z.object({
            exerciseId: z.number(),
            targetSets: z.number().default(3),
            targetReps: z.number().default(10),
            targetWeight: z.number().default(0),
            targetDistance: z.number().nullable().optional(),
            targetDurationSeconds: z.number().nullable().optional(),
            targetIncline: z.number().nullable().optional(),
            sortOrder: z.number().default(0),
          })
        ),
      })
    )
    .default([]),
  runActivities: z
    .array(
      z.object({
        id: z.number().optional(),
        profileId: z.string().optional().nullable(),
        workoutId: z.number().nullable().optional(),
        activityType: z.string().default('run'),
        startTime: z.coerce.date(),
        distanceMeters: z.number(),
        durationSeconds: z.number(),
        avgPaceSecondsPerKm: z.number().default(0),
        elevationGainMeters: z.number().default(0),
        gpxData: z.string().nullable().optional(),
        isDeleted: z.boolean().default(false),
        updatedAt: z.coerce.date().optional(),
      })
    )
    .default([]),
});

export type SyncPushInput = z.infer<typeof SyncPushSchema>;
