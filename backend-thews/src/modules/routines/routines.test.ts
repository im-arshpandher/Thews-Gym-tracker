import { describe, it, expect, vi, beforeEach, beforeAll } from 'vitest';
import { buildApp } from '../../app.js';
import { prisma } from '../../core/database/prisma.js';

vi.mock('../../core/database/prisma.js', () => ({
  prisma: {
    $transaction: vi.fn(),
    routines: {
      findMany: vi.fn(),
      findFirst: vi.fn(),
      findUnique: vi.fn(),
      update: vi.fn(),
    },
  },
}));

describe('Routines Module Integration Tests', () => {
  const app = buildApp();
  let validToken: string;

  beforeAll(async () => {
    await app.ready();
    validToken = app.jwt.sign({ id: 'user-1', email: 'athlete@thews.app', role: 'USER' });
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('POST /api/v1/routines', () => {
    it('should create a workout routine with target exercises (201)', async () => {
      const payload = {
        name: 'Upper Body Hypertrophy',
        description: 'Chest & Back focused routine',
        exercises: [
          { exerciseId: 1, targetSets: 4, targetReps: 8, targetWeight: 80, sortOrder: 0 },
        ],
      };

      const mockRoutine = {
        id: 50,
        userId: 'user-1',
        name: payload.name,
        description: payload.description,
        routineExercises: [
          { id: 1, routineId: 50, exerciseId: 1, targetSets: 4, targetReps: 8, targetWeight: 80 },
        ],
      };

      (prisma.$transaction as any).mockImplementation(async (callback: any) => {
        const txMock = {
          routines: {
            create: vi.fn().mockResolvedValue({ id: 50 }),
            findUnique: vi.fn().mockResolvedValue(mockRoutine),
          },
          routineExercises: {
            createMany: vi.fn().mockResolvedValue({ count: 1 }),
          },
        };
        return await callback(txMock);
      });

      const response = await app.inject({
        method: 'POST',
        url: '/api/v1/routines',
        headers: { authorization: `Bearer ${validToken}` },
        payload,
      });

      expect(response.statusCode).toBe(201);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.name).toBe('Upper Body Hypertrophy');
    });
  });

  describe('GET /api/v1/routines', () => {
    it('should list all routines for user (200)', async () => {
      const mockRoutines = [
        { id: 50, name: 'Upper Body Hypertrophy', routineExercises: [] },
      ];

      (prisma.routines.findMany as any).mockResolvedValue(mockRoutines);

      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/routines',
        headers: { authorization: `Bearer ${validToken}` },
      });

      expect(response.statusCode).toBe(200);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.length).toBe(1);
    });
  });
});
