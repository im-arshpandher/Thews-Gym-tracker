import { describe, it, expect, vi, beforeEach, beforeAll } from 'vitest';
import { buildApp } from '../../app.js';
import { prisma } from '../../core/database/prisma.js';

vi.mock('../../core/database/prisma.js', () => ({
  prisma: {
    $transaction: vi.fn(),
    runActivities: {
      findMany: vi.fn(),
      findFirst: vi.fn(),
      count: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      aggregate: vi.fn(),
    },
  },
}));

describe('Running & GPS Module Integration Tests', () => {
  const app = buildApp();
  let validToken: string;

  beforeAll(async () => {
    await app.ready();
    validToken = app.jwt.sign({ id: 'user-1', email: 'athlete@thews.app', role: 'USER' });
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('POST /api/v1/running', () => {
    it('should log a completed run activity with GPS track (201)', async () => {
      const payload = {
        activityType: 'run',
        startTime: new Date().toISOString(),
        distanceMeters: 5240, // 5.24 km
        durationSeconds: 1572, // 26m 12s
        avgPaceSecondsPerKm: 300, // 5:00 min/km
        elevationGainMeters: 45.5,
        gpxData: '<gpx><trk><trkseg><trkpt lat="37.77" lon="-122.41"></trkpt></trkseg></trk></gpx>',
      };

      const mockCreated = {
        id: 77,
        userId: 'user-1',
        ...payload,
        startTime: new Date(payload.startTime),
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      (prisma.runActivities.create as any).mockResolvedValue(mockCreated);

      const response = await app.inject({
        method: 'POST',
        url: '/api/v1/running',
        headers: { authorization: `Bearer ${validToken}` },
        payload,
      });

      expect(response.statusCode).toBe(201);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.distanceMeters).toBe(5240);
    });
  });

  describe('GET /api/v1/running/stats', () => {
    it('should return aggregated running stats for user (200)', async () => {
      (prisma.runActivities.aggregate as any).mockResolvedValue({
        _count: { id: 12 },
        _sum: {
          distanceMeters: 62800,
          durationSeconds: 18840,
          elevationGainMeters: 520,
        },
      });

      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/running/stats',
        headers: { authorization: `Bearer ${validToken}` },
      });

      expect(response.statusCode).toBe(200);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.totalRuns).toBe(12);
      expect(body.data.totalDistanceMeters).toBe(62800);
    });
  });
});
