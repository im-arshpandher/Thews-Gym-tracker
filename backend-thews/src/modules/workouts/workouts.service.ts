import { prisma } from '../../core/database/prisma.js';
import { CreateWorkoutInput, UpdateWorkoutInput, WorkoutQueryInput } from './workouts.schema.js';
import { NotFoundError } from '../../core/errors/app-error.js';

export class WorkoutsService {
  async listWorkouts(userId: string, query: WorkoutQueryInput) {
    const { startDate, endDate, page, limit, profileId } = query;
    const skip = (page - 1) * limit;

    const where = {
      userId,
      deletedAt: null,
      ...(profileId ? { profileId } : {}),
      ...(startDate || endDate
        ? {
            date: {
              ...(startDate ? { gte: startDate } : {}),
              ...(endDate ? { lte: endDate } : {}),
            },
          }
        : {}),
    };

    const [total, workouts] = await prisma.$transaction([
      prisma.workouts.count({ where }),
      prisma.workouts.findMany({
        where,
        skip,
        take: limit,
        orderBy: { date: 'desc' },
        include: {
          workoutExercises: {
            orderBy: { sortOrder: 'asc' },
            include: {
              exercise: true,
              setEntries: {
                orderBy: { setNumber: 'asc' },
              },
            },
          },
          runActivities: true,
        },
      }),
    ]);

    return {
      data: workouts,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getWorkoutById(id: number, userId: string) {
    const workout = await prisma.workouts.findFirst({
      where: { id, userId, deletedAt: null },
      include: {
        workoutExercises: {
          orderBy: { sortOrder: 'asc' },
          include: {
            exercise: true,
            setEntries: {
              orderBy: { setNumber: 'asc' },
            },
          },
        },
        runActivities: true,
      },
    });

    if (!workout) {
      throw new NotFoundError('Workout not found');
    }

    return workout;
  }

  async createWorkout(userId: string, input: CreateWorkoutInput, profileId?: string) {
    return await prisma.$transaction(async (tx) => {
      const workout = await tx.workouts.create({
        data: {
          userId,
          profileId: input.profileId ?? profileId ?? null,
          date: input.date,
          notes: input.notes ?? null,
          durationSeconds: input.durationSeconds,
        },
      });

      for (const we of input.exercises) {
        const workoutExercise = await tx.workoutExercises.create({
          data: {
            workoutId: workout.id,
            exerciseId: we.exerciseId,
            sortOrder: we.sortOrder,
          },
        });

        if (we.sets && we.sets.length > 0) {
          await tx.setEntries.createMany({
            data: we.sets.map((s) => ({
              workoutExerciseId: workoutExercise.id,
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

      return await tx.workouts.findUnique({
        where: { id: workout.id },
        include: {
          workoutExercises: {
            orderBy: { sortOrder: 'asc' },
            include: {
              exercise: true,
              setEntries: {
                orderBy: { setNumber: 'asc' },
              },
            },
          },
        },
      });
    });
  }

  async updateWorkout(id: number, userId: string, input: UpdateWorkoutInput) {
    const existing = await prisma.workouts.findFirst({
      where: { id, userId, deletedAt: null },
    });

    if (!existing) {
      throw new NotFoundError('Workout not found');
    }

    return await prisma.$transaction(async (tx) => {
      await tx.workouts.update({
        where: { id },
        data: {
          ...(input.date ? { date: input.date } : {}),
          ...(input.notes !== undefined ? { notes: input.notes } : {}),
          ...(input.durationSeconds !== undefined ? { durationSeconds: input.durationSeconds } : {}),
          ...(input.profileId !== undefined ? { profileId: input.profileId } : {}),
        },
      });

      if (input.exercises) {
        // Remove existing exercises and rewrite updated sets
        await tx.workoutExercises.deleteMany({
          where: { workoutId: id },
        });

        for (const we of input.exercises) {
          const workoutExercise = await tx.workoutExercises.create({
            data: {
              workoutId: id,
              exerciseId: we.exerciseId,
              sortOrder: we.sortOrder,
            },
          });

          if (we.sets && we.sets.length > 0) {
            await tx.setEntries.createMany({
              data: we.sets.map((s) => ({
                workoutExerciseId: workoutExercise.id,
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

      return await tx.workouts.findUnique({
        where: { id },
        include: {
          workoutExercises: {
            orderBy: { sortOrder: 'asc' },
            include: {
              exercise: true,
              setEntries: {
                orderBy: { setNumber: 'asc' },
              },
            },
          },
        },
      });
    });
  }

  async deleteWorkout(id: number, userId: string) {
    const existing = await prisma.workouts.findFirst({
      where: { id, userId, deletedAt: null },
    });

    if (!existing) {
      throw new NotFoundError('Workout not found');
    }

    // Soft delete for mobile delta sync support
    await prisma.workouts.update({
      where: { id },
      data: { deletedAt: new Date() },
    });

    return { success: true };
  }
}
