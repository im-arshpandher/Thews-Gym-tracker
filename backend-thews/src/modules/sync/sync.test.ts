import { describe, it, expect, vi, beforeEach, beforeAll } from 'vitest';
import { buildApp } from '../../app.js';
import { prisma } from '../../core/database/prisma.js';

vi.mock('../../core/database/prisma.js', () => ({
  prisma: {
    $transaction: vi.fn(),
    workouts: {
      findMany: vi.fn(),
      updateMany: vi.fn(),
      create: vi.fn(),
    },
    workoutExercises: {
      create: vi.fn(),
    },
    setEntries: {
      createMany: vi.fn(),
    },
    routines: {
      findMany: vi.fn(),
      updateMany: vi.fn(),
      create: vi.fn(),
    },
    routineExercises: {
      createMany: vi.fn(),
    },
    runActivities: {
      findMany: vi.fn(),
      updateMany: vi.fn(),
      create: vi.fn(),
    },
    exercises: {
      findMany: vi.fn(),
    },
  },
}));

describe('Sync Module Integration Tests', () => {
  const app = buildApp();
  let validToken: string;

  beforeAll(async () => {
    await app.ready();
    validToken = app.jwt.sign({ id: 'user-1', email: 'athlete@thews.app', role: 'USER' });
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('POST /api/v1/sync (Two-Way Delta Synchronization)', () => {
    it('should process client pushes and return server updates with synced timestamp (200)', async () => {
      const payload = {
        lastPulledAt: new Date(Date.now() - 86400000).toISOString(),
        workouts: [
          {
            date: new Date().toISOString(),
            notes: 'Offline logged workout',
            durationSeconds: 2400,
            exercises: [
              {
                exerciseId: 1,
                sortOrder: 0,
                sets: [{ setNumber: 1, weight: 80, reps: 10, unit: 'kg', type: 'normal' }],
              },
            ],
          },
        ],
        routines: [],
        runActivities: [],
      };

      (prisma.$transaction as any).mockImplementation(async (callback: any) => {
        const txMock = {
          workouts: {
            create: vi.fn().mockResolvedValue({ id: 99 }),
            updateMany: vi.fn(),
          },
          workoutExercises: {
            create: vi.fn().mockResolvedValue({ id: 199 }),
          },
          setEntries: {
            createMany: vi.fn().mockResolvedValue({ count: 1 }),
          },
          routines: { updateMany: vi.fn(), create: vi.fn() },
          routineExercises: { createMany: vi.fn() },
          runActivities: { updateMany: vi.fn(), create: vi.fn() },
        };
        return await callback(txMock);
      });

      (prisma.workouts.findMany as any).mockResolvedValue([]);
      (prisma.routines.findMany as any).mockResolvedValue([]);
      (prisma.runActivities.findMany as any).mockResolvedValue([]);
      (prisma.exercises.findMany as any).mockResolvedValue([]);

      const response = await app.inject({
        method: 'POST',
        url: '/api/v1/sync',
        headers: { authorization: `Bearer ${validToken}` },
        payload,
      });

      expect(response.statusCode).toBe(200);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.syncedAt).toBeDefined();
      expect(body.data.changes).toBeDefined();
      expect(body.data.changes.workouts).toBeDefined();
    });
  });
});
