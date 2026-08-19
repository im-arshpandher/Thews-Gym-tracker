import { prisma } from '../../core/database/prisma.js';
import { SyncPushInput } from './sync.schema.js';

export class SyncService {
  async performDeltaSync(userId: string, input: SyncPushInput, defaultProfileId?: string) {
    const syncStartTime = new Date();
    const { lastPulledAt, workouts, routines, runActivities, profileId } = input;
    const effectiveProfileId = profileId ?? defaultProfileId ?? null;

    // 1. Process client pushes inside a transaction
    await prisma.$transaction(async (tx) => {
      // Process Workouts
      for (const w of workouts) {
        if (w.isDeleted && w.id) {
          await tx.workouts.updateMany({
            where: { id: w.id, userId },
            data: { deletedAt: new Date() },
          });
        } else if (w.id) {
          // Update existing workout
          await tx.workouts.updateMany({
            where: { id: w.id, userId },
            data: {
              date: w.date,
              notes: w.notes ?? null,
              durationSeconds: w.durationSeconds,
              ...(w.profileId ? { profileId: w.profileId } : {}),
            },
          });
        } else {
          // Create new workout
          const created = await tx.workouts.create({
            data: {
              userId,
              profileId: w.profileId ?? effectiveProfileId,
              date: w.date,
              notes: w.notes ?? null,
              durationSeconds: w.durationSeconds,
            },
          });

          for (const we of w.exercises) {
            const createdWe = await tx.workoutExercises.create({
              data: {
                workoutId: created.id,
                exerciseId: we.exerciseId,
                sortOrder: we.sortOrder,
              },
            });

            if (we.sets && we.sets.length > 0) {
              await tx.setEntries.createMany({
                data: we.sets.map((s) => ({
                  workoutExerciseId: createdWe.id,
                  setNumber: s.setNumber,
                  weight: s.weight,
                  reps: s.reps,
                  unit: s.unit,
                  type: s.type,
                  distance: s.distance ?? null,
                  distanceUnit: s.distanceUnit ?? 'km',
                  durationSeconds: s.durationSeconds ?? null,
                  incline: s.incline ?? null,
                  speed: s.speed ?? null,
                })),
              });
            }
          }
        }
      }

      // Process Routines
      for (const r of routines) {
        if (r.isDeleted && r.id) {
          await tx.routines.updateMany({
            where: { id: r.id, userId },
            data: { deletedAt: new Date() },
          });
        } else if (r.id) {
          await tx.routines.updateMany({
            where: { id: r.id, userId },
            data: {
              name: r.name,
              description: r.description ?? null,
              ...(r.profileId ? { profileId: r.profileId } : {}),
            },
          });
        } else {
          const createdRoutine = await tx.routines.create({
            data: {
              userId,
              profileId: r.profileId ?? effectiveProfileId,
              name: r.name,
              description: r.description ?? null,
            },
          });

          if (r.exercises && r.exercises.length > 0) {
            await tx.routineExercises.createMany({
              data: r.exercises.map((re) => ({
                routineId: createdRoutine.id,
                exerciseId: re.exerciseId,
                targetSets: re.targetSets,
                targetReps: re.targetReps,
                targetWeight: re.targetWeight,
                targetDistance: re.targetDistance ?? null,
                targetDurationSeconds: re.targetDurationSeconds ?? null,
                targetIncline: re.targetIncline ?? null,
                sortOrder: re.sortOrder,
              })),
            });
          }
        }
      }

      // Process RunActivities
      for (const ra of runActivities) {
        if (ra.isDeleted && ra.id) {
          await tx.runActivities.updateMany({
            where: { id: ra.id, userId },
            data: { deletedAt: new Date() },
          });
        } else if (ra.id) {
          await tx.runActivities.updateMany({
            where: { id: ra.id, userId },
            data: {
              activityType: ra.activityType,
              startTime: ra.startTime,
              distanceMeters: ra.distanceMeters,
              durationSeconds: ra.durationSeconds,
              avgPaceSecondsPerKm: ra.avgPaceSecondsPerKm,
              elevationGainMeters: ra.elevationGainMeters,
              gpxData: ra.gpxData ?? null,
              ...(ra.profileId ? { profileId: ra.profileId } : {}),
            },
          });
        } else {
          await tx.runActivities.create({
            data: {
              userId,
              profileId: ra.profileId ?? effectiveProfileId,
              workoutId: ra.workoutId ?? null,
              activityType: ra.activityType,
              startTime: ra.startTime,
              distanceMeters: ra.distanceMeters,
              durationSeconds: ra.durationSeconds,
              avgPaceSecondsPerKm: ra.avgPaceSecondsPerKm,
              elevationGainMeters: ra.elevationGainMeters,
              gpxData: ra.gpxData ?? null,
            },
          });
        }
      }
    });

    // 2. Fetch server changes since lastPulledAt
    const deltaFilter = lastPulledAt ? { updatedAt: { gte: lastPulledAt } } : {};

    const [serverExercises, serverWorkouts, serverRoutines, serverRuns] = await Promise.all([
      prisma.exercises.findMany({
        where: {
          OR: [{ userId: null }, { userId }],
          ...deltaFilter,
        },
      }),
      prisma.workouts.findMany({
        where: {
          userId,
          ...deltaFilter,
        },
        include: {
          workoutExercises: {
            include: {
              setEntries: true,
            },
          },
        },
      }),
      prisma.routines.findMany({
        where: {
          userId,
          ...deltaFilter,
        },
        include: {
          routineExercises: true,
        },
      }),
      prisma.runActivities.findMany({
        where: {
          userId,
          ...deltaFilter,
        },
      }),
    ]);

    return {
      changes: {
        exercises: serverExercises,
        workouts: serverWorkouts,
        routines: serverRoutines,
        runActivities: serverRuns,
      },
      syncedAt: syncStartTime.toISOString(),
      timestamp: syncStartTime.toISOString(),
    };
  }
}
