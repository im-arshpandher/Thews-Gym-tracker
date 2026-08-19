import { describe, it, expect, vi, beforeEach, beforeAll } from 'vitest';
import { buildApp } from '../../app.js';
import { prisma } from '../../core/database/prisma.js';

vi.mock('../../core/database/prisma.js', () => ({
  prisma: {
    aICoachLog: {
      create: vi.fn(),
    },
    workoutExercises: {
      findMany: vi.fn(),
    },
  },
}));

describe('AI Coach Module Integration Tests', () => {
  const app = buildApp();
  let validToken: string;

  beforeAll(async () => {
    await app.ready();
    validToken = app.jwt.sign({ id: 'user-1', email: 'athlete@thews.app', role: 'USER' });
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('POST /api/v1/ai-coach/ask', () => {
    it('should generate an AI coach response and log interaction to database (200)', async () => {
      (prisma.aICoachLog.create as any).mockResolvedValue({ id: 'log-1' });

      const response = await app.inject({
        method: 'POST',
        url: '/api/v1/ai-coach/ask',
        headers: { authorization: `Bearer ${validToken}` },
        payload: {
          prompt: 'How do I break through a bench press plateau?',
          userContext: { targetGoal: 'Hypertrophy', fatigueScore: 35 },
        },
      });

      expect(response.statusCode).toBe(200);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.response).toBeDefined();
      expect(prisma.aICoachLog.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            userId: 'user-1',
            prompt: 'How do I break through a bench press plateau?',
          }),
        })
      );
    });
  });

  describe('GET /api/v1/ai-coach/overload/:exerciseId', () => {
    it('should calculate progressive overload recommendation based on historical working sets (200)', async () => {
      const mockHistory = [
        {
          id: 1,
          exerciseId: 1,
          workout: { date: new Date() },
          exercise: { name: 'Barbell Bench Press' },
          setEntries: [
            { setNumber: 1, weight: 100, reps: 10, type: 'normal' },
            { setNumber: 2, weight: 100, reps: 10, type: 'normal' },
            { setNumber: 3, weight: 100, reps: 10, type: 'failure' },
          ],
        },
      ];

      (prisma.workoutExercises.findMany as any).mockResolvedValue(mockHistory);

      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/ai-coach/overload/1',
        headers: { authorization: `Bearer ${validToken}` },
      });

      expect(response.statusCode).toBe(200);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.exerciseName).toBe('Barbell Bench Press');
      expect(body.data.lastRecordedWeight).toBe(100);
      expect(body.data.recommendedTargetWeight).toBe(102.5); // +2.5kg progression
      expect(body.data.advice).toContain('102.5kg');
    });

    it('should handle insufficient historical data gracefully', async () => {
      (prisma.workoutExercises.findMany as any).mockResolvedValue([]);

      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/ai-coach/overload/999',
        headers: { authorization: `Bearer ${validToken}` },
      });

      expect(response.statusCode).toBe(200);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.status).toBe('insufficient_data');
    });
  });
});
