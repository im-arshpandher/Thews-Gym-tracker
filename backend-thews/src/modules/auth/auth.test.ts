import { describe, it, expect, vi, beforeEach } from 'vitest';
import { buildApp } from '../../app.js';
import { prisma } from '../../core/database/prisma.js';
import { HashUtil } from '../../core/utils/hash.js';

vi.mock('../../core/database/prisma.js', () => ({
  prisma: {
    $transaction: vi.fn(),
    user: {
      findUnique: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
    profiles: {
      create: vi.fn(),
      upsert: vi.fn(),
    },
    refreshToken: {
      create: vi.fn(),
      findUnique: vi.fn(),
      update: vi.fn(),
      updateMany: vi.fn(),
    },
  },
}));

describe('Auth Module Integration Tests', () => {
  const app = buildApp();

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('POST /api/v1/auth/register', () => {
    it('should register a new user and return user info + profile + JWT tokens (201)', async () => {
      const mockUser = {
        id: 'user-uuid-1',
        email: 'athlete@thews.app',
        name: 'Thews Athlete',
        avatarUrl: null,
        role: 'USER',
        createdAt: new Date(),
        profile: {
          id: 'profile-uuid-1',
          username: null,
          displayName: 'Thews Athlete',
          avatarUrl: null,
          bio: null,
          gender: null,
          birthDate: null,
          heightCm: null,
          weightKg: null,
          unitPreference: 'kg',
          distanceUnit: 'km',
          fitnessGoal: null,
          experienceLevel: null,
        },
      };

      (prisma.user.findUnique as any).mockResolvedValue(null);
      (prisma.$transaction as any).mockImplementation(async (cb: any) => {
        const tx = {
          user: {
            create: vi.fn().mockResolvedValue({
              id: 'user-uuid-1',
              email: 'athlete@thews.app',
              name: 'Thews Athlete',
              role: 'USER',
              createdAt: new Date(),
            }),
          },
          profiles: {
            create: vi.fn().mockResolvedValue({
              id: 'profile-uuid-1',
              userId: 'user-uuid-1',
              displayName: 'Thews Athlete',
              username: null,
              unitPreference: 'kg',
              distanceUnit: 'km',
            }),
          },
        };
        return await cb(tx);
      });
      (prisma.refreshToken.create as any).mockResolvedValue({ id: 'token-id-1' });

      const response = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/register',
        payload: {
          email: 'athlete@thews.app',
          password: 'Password123!',
          name: 'Thews Athlete',
        },
      });

      expect(response.statusCode).toBe(201);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.user.email).toBe('athlete@thews.app');
      expect(body.data.user.profile.id).toBe('profile-uuid-1');
      expect(body.data.tokens.accessToken).toBeDefined();
      expect(body.data.tokens.refreshToken).toBeDefined();
    });

    it('should reject registration if email is already in use (409 Conflict)', async () => {
      (prisma.user.findUnique as any).mockResolvedValue({ id: 'existing-id' });

      const response = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/register',
        payload: {
          email: 'existing@thews.app',
          password: 'Password123!',
          name: 'Existing User',
        },
      });

      expect(response.statusCode).toBe(409);
      const body = response.json();
      expect(body.success).toBe(false);
      expect(body.message).toContain('already exists');
    });

    it('should reject registration with invalid payload schema (422)', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/register',
        payload: {
          email: 'invalid-email',
          password: '123', // Too short (< 8)
          name: 'A', // Too short (< 2)
        },
      });

      expect(response.statusCode).toBe(422);
      const body = response.json();
      expect(body.success).toBe(false);
      expect(body.message).toBe('Validation Failed');
      expect(body.errors.length).toBeGreaterThan(0);
    });
  });

  describe('POST /api/v1/auth/login', () => {
    it('should authenticate user and return tokens when credentials match (200)', async () => {
      const hashedPassword = await HashUtil.hashPassword('CorrectPassword123!');
      const mockUser = {
        id: 'user-uuid-1',
        email: 'athlete@thews.app',
        name: 'Thews Athlete',
        passwordHash: hashedPassword,
        avatarUrl: null,
        role: 'USER',
        createdAt: new Date(),
        profile: {
          id: 'profile-uuid-1',
          displayName: 'Thews Athlete',
          username: null,
          unitPreference: 'kg',
          distanceUnit: 'km',
        },
      };

      (prisma.user.findUnique as any).mockResolvedValue(mockUser);
      (prisma.refreshToken.create as any).mockResolvedValue({ id: 'token-id-1' });

      const response = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/login',
        payload: {
          email: 'athlete@thews.app',
          password: 'CorrectPassword123!',
        },
      });

      expect(response.statusCode).toBe(200);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.tokens.accessToken).toBeDefined();
      expect(body.data.tokens.refreshToken).toBeDefined();
      expect(body.data.user.profile.id).toBe('profile-uuid-1');
    });

    it('should reject login when password is wrong (401 Unauthorized)', async () => {
      const hashedPassword = await HashUtil.hashPassword('CorrectPassword123!');
      const mockUser = {
        id: 'user-uuid-1',
        email: 'athlete@thews.app',
        passwordHash: hashedPassword,
        profile: null,
      };

      (prisma.user.findUnique as any).mockResolvedValue(mockUser);

      const response = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/login',
        payload: {
          email: 'athlete@thews.app',
          password: 'WrongPassword!',
        },
      });

      expect(response.statusCode).toBe(401);
      const body = response.json();
      expect(body.success).toBe(false);
    });
  });

  describe('POST /api/v1/auth/refresh (Token Rotation & Reuse Detection)', () => {
    it('should rotate refresh token and issue new token pair', async () => {
      const rawOldToken = 'valid-refresh-token-12345';
      const mockRecord = {
        id: 'record-id-1',
        userId: 'user-uuid-1',
        isRevoked: false,
        expiresAt: new Date(Date.now() + 1000000),
        user: {
          id: 'user-uuid-1',
          email: 'athlete@thews.app',
          role: 'USER',
          profile: { id: 'profile-uuid-1' },
        },
      };

      (prisma.refreshToken.findUnique as any).mockResolvedValue(mockRecord);
      (prisma.refreshToken.update as any).mockResolvedValue({ id: 'record-id-1' });
      (prisma.refreshToken.create as any).mockResolvedValue({ id: 'record-id-2' });

      const response = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/refresh',
        payload: { refreshToken: rawOldToken },
      });

      expect(response.statusCode).toBe(200);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.accessToken).toBeDefined();
      expect(body.data.refreshToken).toBeDefined();
      expect(prisma.refreshToken.update).toHaveBeenCalledWith(
        expect.objectContaining({ data: { isRevoked: true } })
      );
    });

    it('should detect token reuse, revoke all user tokens and reject with 401', async () => {
      const rawReusedToken = 'reused-compromised-token';
      const revokedRecord = {
        id: 'record-id-1',
        userId: 'user-uuid-1',
        isRevoked: true, // Already used token!
        expiresAt: new Date(Date.now() + 1000000),
        user: { id: 'user-uuid-1', email: 'athlete@thews.app', role: 'USER' },
      };

      (prisma.refreshToken.findUnique as any).mockResolvedValue(revokedRecord);

      const response = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/refresh',
        payload: { refreshToken: rawReusedToken },
      });

      expect(response.statusCode).toBe(401);
      // All user tokens revoked immediately for safety
      expect(prisma.refreshToken.updateMany).toHaveBeenCalledWith({
        where: { userId: 'user-uuid-1' },
        data: { isRevoked: true },
      });
    });
  });

  describe('GET /api/v1/auth/me (Protected Route)', () => {
    it('should reject unauthenticated request without token (401)', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/auth/me',
      });

      expect(response.statusCode).toBe(401);
    });

    it('should return user profile when valid JWT is provided (200)', async () => {
      const token = app.jwt.sign({ id: 'user-uuid-1', email: 'athlete@thews.app', role: 'USER', profileId: 'profile-uuid-1' });
      const mockProfile = {
        id: 'user-uuid-1',
        email: 'athlete@thews.app',
        name: 'Thews Athlete',
        avatarUrl: null,
        role: 'USER',
        createdAt: new Date(),
        updatedAt: new Date(),
        profile: {
          id: 'profile-uuid-1',
          userId: 'user-uuid-1',
          displayName: 'Thews Athlete',
        },
      };

      (prisma.user.findUnique as any).mockResolvedValue(mockProfile);

      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/auth/me',
        headers: {
          authorization: `Bearer ${token}`,
        },
      });

      expect(response.statusCode).toBe(200);
      const body = response.json();
      expect(body.success).toBe(true);
      expect(body.data.id).toBe('user-uuid-1');
      expect(body.data.profile.id).toBe('profile-uuid-1');
    });
  });
});
