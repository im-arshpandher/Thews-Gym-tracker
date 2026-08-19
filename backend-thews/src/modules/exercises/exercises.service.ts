import { Prisma } from '@prisma/client';
import { prisma } from '../../core/database/prisma.js';
import { CreateExerciseInput, UpdateExerciseInput, ExerciseQueryInput } from './exercises.schema.js';
import { ForbiddenError, NotFoundError } from '../../core/errors/app-error.js';

export class ExercisesService {
  async listExercises(userId: string, query: ExerciseQueryInput) {
    const where: Prisma.ExercisesWhereInput = {
      isDeleted: false,
      OR: [{ userId: null }, { userId }],
      ...(query.muscleGroup ? { muscleGroup: query.muscleGroup } : {}),
      ...(query.category ? { category: query.category } : {}),
      ...(query.profileId ? { profileId: query.profileId } : {}),
      ...(query.search
        ? {
            name: {
              contains: query.search,
              mode: 'insensitive',
            },
          }
        : {}),
    };

    return await prisma.exercises.findMany({
      where,
      orderBy: [{ isCustom: 'asc' }, { name: 'asc' }],
    });
  }

  async getExerciseById(id: number, userId: string) {
    const exercise = await prisma.exercises.findFirst({
      where: {
        id,
        isDeleted: false,
        OR: [{ userId: null }, { userId }],
      },
    });

    if (!exercise) {
      throw new NotFoundError('Exercise not found');
    }

    return exercise;
  }

  async createCustomExercise(userId: string, input: CreateExerciseInput, profileId?: string) {
    return await prisma.exercises.create({
      data: {
        userId,
        profileId: input.profileId ?? profileId ?? null,
        name: input.name.trim(),
        muscleGroup: input.muscleGroup.trim(),
        secondaryMuscleGroups: input.secondaryMuscleGroups ?? null,
        isCustom: true,
        videoUrl: input.videoUrl ?? null,
        category: input.category,
        enabledMetrics: input.enabledMetrics,
      },
    });
  }

  async updateCustomExercise(id: number, userId: string, input: UpdateExerciseInput) {
    const existing = await prisma.exercises.findUnique({
      where: { id },
    });

    if (!existing || existing.isDeleted) {
      throw new NotFoundError('Exercise not found');
    }

    if (existing.userId !== userId) {
      throw new ForbiddenError('Cannot edit system default exercises or another user’s exercises');
    }

    return await prisma.exercises.update({
      where: { id },
      data: {
        ...(input.name ? { name: input.name.trim() } : {}),
        ...(input.muscleGroup ? { muscleGroup: input.muscleGroup.trim() } : {}),
        ...(input.secondaryMuscleGroups !== undefined ? { secondaryMuscleGroups: input.secondaryMuscleGroups } : {}),
        ...(input.videoUrl !== undefined ? { videoUrl: input.videoUrl } : {}),
        ...(input.category ? { category: input.category } : {}),
        ...(input.enabledMetrics ? { enabledMetrics: input.enabledMetrics } : {}),
        ...(input.profileId !== undefined ? { profileId: input.profileId } : {}),
      },
    });
  }

  async deleteCustomExercise(id: number, userId: string) {
    const existing = await prisma.exercises.findUnique({
      where: { id },
    });

    if (!existing || existing.isDeleted) {
      throw new NotFoundError('Exercise not found');
    }

    if (existing.userId !== userId) {
      throw new ForbiddenError('Cannot delete system default exercises or another user’s exercises');
    }

    // Soft delete so historical workouts preserve relations
    await prisma.exercises.update({
      where: { id },
      data: { isDeleted: true },
    });

    return { success: true };
  }
}
