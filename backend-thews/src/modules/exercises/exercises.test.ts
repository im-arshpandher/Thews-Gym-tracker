import { describe, it, expect, vi, beforeEach, beforeAll } from 'vitest';
import { buildApp } from '../../app.js';
import { prisma } from '../../core/database/prisma.js';

vi.mock('../../core/database/prisma.js', () => ({
  prisma: {
    exercises: {
      findMany: vi.fn(),
      findFirst: vi.fn(),
      findUnique: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
  },
}));

describe('Exercises Module Integration Tests', () => {
  const app = buildApp();
  let validToken: string;

  beforeAll(async () => {
    await app.ready();
    validToken = app.jwt.sign({ id: 'user-1', email: 'athlete@thews.app', role: 'USER' });
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('GET /api/v1/exercises', () => {
    it('should list system and user exercises (200)', async () => {
      const mockExercises = [
        { id: 1, name: 'Barbell Bench Press', muscleGroup: 'Chest', isCustom: false },
        { id: 2, name: 'Custom Cable Fly', muscleGroup: 'Chest', isCustom: true, userId: 'user-1' },
      ];

      (prisma.exercises.findMany as any).mockResolvedValue(mockExercises);

      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/exercises?muscleGroup=Chest',
        headers: { authorization: `Bearer ${validToken}` },
      });

      expect(response.statusCode).toBe(200);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.length).toBe(2);
      expect(prisma.exercises.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ muscleGroup: 'Chest' }),
        })
      );
    });
  });

  describe('POST /api/v1/exercises', () => {
    it('should create a custom exercise for authenticated user (201)', async () => {
      const payload = {
        name: 'Incline Smith Press',
        muscleGroup: 'Chest',
        secondaryMuscleGroups: 'Triceps,Shoulders',
        category: 'weight_reps',
        enabledMetrics: 'weight,reps',
      };

      const createdExercise = {
        id: 10,
        userId: 'user-1',
        ...payload,
        isCustom: true,
        isDeleted: false,
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      (prisma.exercises.create as any).mockResolvedValue(createdExercise);

      const response = await app.inject({
        method: 'POST',
        url: '/api/v1/exercises',
        headers: { authorization: `Bearer ${validToken}` },
        payload,
      });

      expect(response.statusCode).toBe(201);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.name).toBe('Incline Smith Press');
      expect(body.data.isCustom).toBe(true);
    });
  });

  describe('PATCH /api/v1/exercises/:id', () => {
    it('should reject modifying a system default exercise with 403 Forbidden', async () => {
      (prisma.exercises.findUnique as any).mockResolvedValue({
        id: 1,
        name: 'Barbell Bench Press',
        userId: null, // System exercise
        isCustom: false,
        isDeleted: false,
      });

      const response = await app.inject({
        method: 'PATCH',
        url: '/api/v1/exercises/1',
        headers: { authorization: `Bearer ${validToken}` },
        payload: { name: 'New Name' },
      });

      expect(response.statusCode).toBe(403);
      const body = response.json();
      expect(body.success).toBe(false);
    });

    it('should update user owned custom exercise (200)', async () => {
      (prisma.exercises.findUnique as any).mockResolvedValue({
        id: 10,
        name: 'Incline Smith Press',
        userId: 'user-1',
        isCustom: true,
        isDeleted: false,
      });

      (prisma.exercises.update as any).mockResolvedValue({
        id: 10,
        name: 'Incline Smith Press (Updated)',
        userId: 'user-1',
        isCustom: true,
        isDeleted: false,
      });

      const response = await app.inject({
        method: 'PATCH',
        url: '/api/v1/exercises/10',
        headers: { authorization: `Bearer ${validToken}` },
        payload: { name: 'Incline Smith Press (Updated)' },
      });

      expect(response.statusCode).toBe(200);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.name).toBe('Incline Smith Press (Updated)');
    });
  });

  describe('DELETE /api/v1/exercises/:id', () => {
    it('should soft delete user custom exercise', async () => {
      (prisma.exercises.findUnique as any).mockResolvedValue({
        id: 10,
        userId: 'user-1',
        isCustom: true,
        isDeleted: false,
      });

      (prisma.exercises.update as any).mockResolvedValue({ id: 10, isDeleted: true });

      const response = await app.inject({
        method: 'DELETE',
        url: '/api/v1/exercises/10',
        headers: { authorization: `Bearer ${validToken}` },
      });

      expect(response.statusCode).toBe(200);
      expect(prisma.exercises.update).toHaveBeenCalledWith({
        where: { id: 10 },
        data: { isDeleted: true },
      });
    });
  });
});
