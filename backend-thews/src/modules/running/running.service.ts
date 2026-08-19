import { prisma } from '../../core/database/prisma.js';
import { CreateRunActivityInput, RunQueryInput } from './running.schema.js';
import { NotFoundError } from '../../core/errors/app-error.js';

export class RunningService {
  async listActivities(userId: string, query: RunQueryInput) {
    const { activityType, page, limit, profileId } = query;
    const skip = (page - 1) * limit;

    const where = {
      userId,
      deletedAt: null,
      ...(profileId ? { profileId } : {}),
      ...(activityType ? { activityType } : {}),
    };

    const [total, activities] = await prisma.$transaction([
      prisma.runActivities.count({ where }),
      prisma.runActivities.findMany({
        where,
        skip,
        take: limit,
        orderBy: { startTime: 'desc' },
        include: {
          workout: {
            select: { id: true, date: true, notes: true },
          },
        },
      }),
    ]);

    return {
      data: activities,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getActivityById(id: number, userId: string) {
    const activity = await prisma.runActivities.findFirst({
      where: { id, userId, deletedAt: null },
      include: {
        workout: true,
      },
    });

    if (!activity) {
      throw new NotFoundError('Run activity not found');
    }

    return activity;
  }

  async createActivity(userId: string, input: CreateRunActivityInput, profileId?: string) {
    return await prisma.runActivities.create({
      data: {
        userId,
        profileId: input.profileId ?? profileId ?? null,
        workoutId: input.workoutId ?? null,
        activityType: input.activityType,
        startTime: input.startTime,
        distanceMeters: input.distanceMeters,
        durationSeconds: input.durationSeconds,
        avgPaceSecondsPerKm: input.avgPaceSecondsPerKm,
        elevationGainMeters: input.elevationGainMeters,
        gpxData: input.gpxData ?? null,
      },
    });
  }

  async deleteActivity(id: number, userId: string) {
    const existing = await prisma.runActivities.findFirst({
      where: { id, userId, deletedAt: null },
    });

    if (!existing) {
      throw new NotFoundError('Run activity not found');
    }

    await prisma.runActivities.update({
      where: { id },
      data: { deletedAt: new Date() },
    });

    return { success: true };
  }

  async getOverallStats(userId: string, profileId?: string) {
    const aggregations = await prisma.runActivities.aggregate({
      where: {
        userId,
        deletedAt: null,
        ...(profileId ? { profileId } : {}),
      },
      _sum: {
        distanceMeters: true,
        durationSeconds: true,
        elevationGainMeters: true,
      },
      _count: {
        id: true,
      },
    });

    return {
      totalRuns: aggregations._count.id,
      totalDistanceMeters: aggregations._sum.distanceMeters || 0,
      totalDurationSeconds: aggregations._sum.durationSeconds || 0,
      totalElevationGainMeters: aggregations._sum.elevationGainMeters || 0,
    };
  }
}
