import { describe, it, expect, vi, beforeEach, beforeAll } from 'vitest';
import { buildApp } from '../../app.js';
import { prisma } from '../../core/database/prisma.js';

vi.mock('../../core/database/prisma.js', () => ({
  prisma: {
    $transaction: vi.fn(),
    workouts: {
      findFirst: vi.fn(),
      findUnique: vi.fn(),
      findMany: vi.fn(),
      count: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
    workoutExercises: {
      create: vi.fn(),
      deleteMany: vi.fn(),
    },
    setEntries: {
      createMany: vi.fn(),
    },
  },
}));

describe('Workouts Module Integration Tests', () => {
  const app = buildApp();
  let validToken: string;

  beforeAll(async () => {
    await app.ready();
    validToken = app.jwt.sign({ id: 'user-1', email: 'athlete@thews.app', role: 'USER' });
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('POST /api/v1/workouts (Log Workout Session)', () => {
    it('should create workout with exercises and set entries inside a transaction (201)', async () => {
      const payload = {
        date: new Date().toISOString(),
        notes: 'Great Push Day session',
        durationSeconds: 3600,
        exercises: [
          {
            exerciseId: 1,
            sortOrder: 0,
            sets: [
              { setNumber: 1, weight: 60, reps: 10, unit: 'kg', type: 'warmup' },
              { setNumber: 2, weight: 100, reps: 8, unit: 'kg', type: 'normal' },
              { setNumber: 3, weight: 100, reps: 6, unit: 'kg', type: 'failure' },
            ],
          },
        ],
      };

      const mockCreatedWorkout = {
        id: 101,
        userId: 'user-1',
        date: new Date(payload.date),
        notes: payload.notes,
        durationSeconds: 3600,
        workoutExercises: [
          {
            id: 201,
            workoutId: 101,
            exerciseId: 1,
            sortOrder: 0,
            setEntries: [
              { id: 301, setNumber: 1, weight: 60, reps: 10, unit: 'kg', type: 'warmup' },
              { id: 302, setNumber: 2, weight: 100, reps: 8, unit: 'kg', type: 'normal' },
              { id: 303, setNumber: 3, weight: 100, reps: 6, unit: 'kg', type: 'failure' },
            ],
          },
        ],
      };

      // Mock transaction execution
      (prisma.$transaction as any).mockImplementation(async (callback: any) => {
        if (typeof callback === 'function') {
          const txMock = {
            workouts: {
              create: vi.fn().mockResolvedValue({ id: 101 }),
              findUnique: vi.fn().mockResolvedValue(mockCreatedWorkout),
            },
            workoutExercises: {
              create: vi.fn().mockResolvedValue({ id: 201 }),
            },
            setEntries: {
              createMany: vi.fn().mockResolvedValue({ count: 3 }),
            },
          };
          return await callback(txMock);
        }
        return callback;
      });

      const response = await app.inject({
        method: 'POST',
        url: '/api/v1/workouts',
        headers: { authorization: `Bearer ${validToken}` },
        payload,
      });

      expect(response.statusCode).toBe(201);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.id).toBe(101);
      expect(body.data.workoutExercises[0].setEntries.length).toBe(3);
    });
  });

  describe('GET /api/v1/workouts (Paginated History)', () => {
    it('should return paginated workouts for user (200)', async () => {
      const mockList = [
        { id: 101, userId: 'user-1', date: new Date(), workoutExercises: [] },
      ];

      (prisma.$transaction as any).mockResolvedValue([1, mockList]);

      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/workouts?page=1&limit=10',
        headers: { authorization: `Bearer ${validToken}` },
      });

      expect(response.statusCode).toBe(200);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.length).toBe(1);
      expect(body.pagination.total).toBe(1);
      expect(body.pagination.page).toBe(1);
    });
  });

  describe('DELETE /api/v1/workouts/:id', () => {
    it('should soft delete workout (200)', async () => {
      (prisma.workouts.findFirst as any).mockResolvedValue({ id: 101, userId: 'user-1' });
      (prisma.workouts.update as any).mockResolvedValue({ id: 101, deletedAt: new Date() });

      const response = await app.inject({
        method: 'DELETE',
        url: '/api/v1/workouts/101',
        headers: { authorization: `Bearer ${validToken}` },
      });

      expect(response.statusCode).toBe(200);
      expect(prisma.workouts.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 101 },
          data: expect.objectContaining({ deletedAt: expect.any(Date) }),
        })
      );
    });
  });
});
