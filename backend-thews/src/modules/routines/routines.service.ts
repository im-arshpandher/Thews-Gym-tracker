import { prisma } from '../../core/database/prisma.js';
import { CreateRoutineInput, UpdateRoutineInput } from './routines.schema.js';
import { NotFoundError } from '../../core/errors/app-error.js';

export class RoutinesService {
  async listRoutines(userId: string, profileId?: string) {
    return await prisma.routines.findMany({
      where: {
        userId,
        deletedAt: null,
        ...(profileId ? { profileId } : {}),
      },
      orderBy: { createdAt: 'desc' },
      include: {
        routineExercises: {
          orderBy: { sortOrder: 'asc' },
          include: {
            exercise: true,
          },
        },
      },
    });
  }

  async getRoutineById(id: number, userId: string) {
    const routine = await prisma.routines.findFirst({
      where: { id, userId, deletedAt: null },
      include: {
        routineExercises: {
          orderBy: { sortOrder: 'asc' },
          include: {
            exercise: true,
          },
        },
      },
    });

    if (!routine) {
      throw new NotFoundError('Routine not found');
    }

    return routine;
  }

  async createRoutine(userId: string, input: CreateRoutineInput, profileId?: string) {
    return await prisma.$transaction(async (tx) => {
      const routine = await tx.routines.create({
        data: {
          userId,
          profileId: input.profileId ?? profileId ?? null,
          name: input.name.trim(),
          description: input.description ?? null,
        },
      });

      if (input.exercises && input.exercises.length > 0) {
        await tx.routineExercises.createMany({
          data: input.exercises.map((e) => ({
            routineId: routine.id,
            exerciseId: e.exerciseId,
            targetSets: e.targetSets,
            targetReps: e.targetReps,
            targetWeight: e.targetWeight,
            targetDistance: e.targetDistance ?? null,
            targetDurationSeconds: e.targetDurationSeconds ?? null,
            targetIncline: e.targetIncline ?? null,
            sortOrder: e.sortOrder,
          })),
        });
      }

      return await tx.routines.findUnique({
        where: { id: routine.id },
        include: {
          routineExercises: {
            orderBy: { sortOrder: 'asc' },
            include: { exercise: true },
          },
        },
      });
    });
  }

  async updateRoutine(id: number, userId: string, input: UpdateRoutineInput) {
    const existing = await prisma.routines.findFirst({
      where: { id, userId, deletedAt: null },
    });

    if (!existing) {
      throw new NotFoundError('Routine not found');
    }

    return await prisma.$transaction(async (tx) => {
      await tx.routines.update({
        where: { id },
        data: {
          ...(input.name ? { name: input.name.trim() } : {}),
          ...(input.description !== undefined ? { description: input.description } : {}),
          ...(input.profileId !== undefined ? { profileId: input.profileId } : {}),
        },
      });

      if (input.exercises) {
        await tx.routineExercises.deleteMany({
          where: { routineId: id },
        });

        if (input.exercises.length > 0) {
          await tx.routineExercises.createMany({
            data: input.exercises.map((e) => ({
              routineId: id,
              exerciseId: e.exerciseId,
              targetSets: e.targetSets,
              targetReps: e.targetReps,
              targetWeight: e.targetWeight,
              targetDistance: e.targetDistance ?? null,
              targetDurationSeconds: e.targetDurationSeconds ?? null,
              targetIncline: e.targetIncline ?? null,
              sortOrder: e.sortOrder,
            })),
          });
        }
      }

      return await tx.routines.findUnique({
        where: { id },
        include: {
          routineExercises: {
            orderBy: { sortOrder: 'asc' },
            include: { exercise: true },
          },
        },
      });
    });
  }

  async deleteRoutine(id: number, userId: string) {
    const existing = await prisma.routines.findFirst({
      where: { id, userId, deletedAt: null },
    });

    if (!existing) {
      throw new NotFoundError('Routine not found');
    }

    await prisma.routines.update({
      where: { id },
      data: { deletedAt: new Date() },
    });

    return { success: true };
  }
}
