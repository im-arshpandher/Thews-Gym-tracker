import { prisma } from '../../core/database/prisma.js';
import { HashUtil } from '../../core/utils/hash.js';
import { BadRequestError, ConflictError, UnauthorizedError } from '../../core/errors/app-error.js';
import { env } from '../../config/env.js';
import { RegisterInput, LoginInput, UpdateProfileInput } from './auth.schema.js';
import { FastifyInstance } from 'fastify';

export class AuthService {
  constructor(private fastify: FastifyInstance) {}

  private generateAccessToken(user: { id: string; email: string; role: 'USER' | 'ADMIN'; profileId?: string }): string {
    return this.fastify.jwt.sign(
      { id: user.id, email: user.email, role: user.role, profileId: user.profileId },
      { expiresIn: env.JWT_ACCESS_EXPIRES_IN }
    );
  }

  private async createRefreshToken(userId: string): Promise<string> {
    const rawToken = HashUtil.generateRandomToken(40);
    const tokenHash = HashUtil.hashToken(rawToken);
    const expiresAt = new Date(Date.now() + env.JWT_REFRESH_EXPIRES_IN_DAYS * 24 * 60 * 60 * 1000);

    await prisma.refreshToken.create({
      data: {
        userId,
        tokenHash,
        expiresAt,
      },
    });

    return rawToken;
  }

  async register(input: RegisterInput) {
    const existing = await prisma.user.findUnique({
      where: { email: input.email.toLowerCase().trim() },
    });

    if (existing) {
      throw new ConflictError('A user with this email already exists');
    }

    const passwordHash = await HashUtil.hashPassword(input.password);

    const userWithProfile = await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          email: input.email.toLowerCase().trim(),
          name: input.name.trim(),
          passwordHash,
          role: 'USER',
        },
      });

      const profile = await tx.profiles.create({
        data: {
          userId: user.id,
          displayName: input.name.trim(),
          username: input.username?.trim().toLowerCase() ?? null,
        },
      });

      return {
        id: user.id,
        email: user.email,
        name: user.name,
        avatarUrl: user.avatarUrl,
        role: user.role,
        createdAt: user.createdAt,
        profile: {
          id: profile.id,
          username: profile.username,
          displayName: profile.displayName,
          avatarUrl: profile.avatarUrl,
          bio: profile.bio,
          gender: profile.gender,
          birthDate: profile.birthDate,
          heightCm: profile.heightCm,
          weightKg: profile.weightKg,
          unitPreference: profile.unitPreference,
          distanceUnit: profile.distanceUnit,
          fitnessGoal: profile.fitnessGoal,
          experienceLevel: profile.experienceLevel,
        },
      };
    });

    const accessToken = this.generateAccessToken({
      id: userWithProfile.id,
      email: userWithProfile.email,
      role: userWithProfile.role,
      profileId: userWithProfile.profile.id,
    });
    const refreshToken = await this.createRefreshToken(userWithProfile.id);

    return { user: userWithProfile, tokens: { accessToken, refreshToken } };
  }

  async login(input: LoginInput) {
    const user = await prisma.user.findUnique({
      where: { email: input.email.toLowerCase().trim() },
      include: { profile: true },
    });

    if (!user) {
      throw new UnauthorizedError('Invalid email or password');
    }

    const isValid = await HashUtil.verifyPassword(user.passwordHash, input.password);
    if (!isValid) {
      throw new UnauthorizedError('Invalid email or password');
    }

    // Auto-create profile if missing (backward-compatibility fallback)
    let profile = user.profile;
    if (!profile) {
      profile = await prisma.profiles.create({
        data: {
          userId: user.id,
          displayName: user.name,
        },
      });
    }

    const accessToken = this.generateAccessToken({
      id: user.id,
      email: user.email,
      role: user.role,
      profileId: profile.id,
    });
    const refreshToken = await this.createRefreshToken(user.id);

    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        avatarUrl: user.avatarUrl,
        role: user.role,
        createdAt: user.createdAt,
        profile: {
          id: profile.id,
          username: profile.username,
          displayName: profile.displayName,
          avatarUrl: profile.avatarUrl,
          bio: profile.bio,
          gender: profile.gender,
          birthDate: profile.birthDate,
          heightCm: profile.heightCm,
          weightKg: profile.weightKg,
          unitPreference: profile.unitPreference,
          distanceUnit: profile.distanceUnit,
          fitnessGoal: profile.fitnessGoal,
          experienceLevel: profile.experienceLevel,
        },
      },
      tokens: { accessToken, refreshToken },
    };
  }

  async refreshTokens(rawRefreshToken: string) {
    const tokenHash = HashUtil.hashToken(rawRefreshToken);

    const tokenRecord = await prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: {
        user: {
          include: { profile: true },
        },
      },
    });

    // Reuse detection: If token record does not exist or was already revoked or expired
    if (!tokenRecord || tokenRecord.isRevoked || tokenRecord.expiresAt < new Date()) {
      if (tokenRecord?.userId) {
        await prisma.refreshToken.updateMany({
          where: { userId: tokenRecord.userId },
          data: { isRevoked: true },
        });
      }
      throw new UnauthorizedError('Invalid or expired refresh token. Please sign in again.');
    }

    // Revoke old token
    await prisma.refreshToken.update({
      where: { id: tokenRecord.id },
      data: { isRevoked: true },
    });

    // Issue new token pair
    const accessToken = this.generateAccessToken({
      id: tokenRecord.user.id,
      email: tokenRecord.user.email,
      role: tokenRecord.user.role,
      profileId: tokenRecord.user.profile?.id,
    });
    const newRefreshToken = await this.createRefreshToken(tokenRecord.user.id);

    return {
      accessToken,
      refreshToken: newRefreshToken,
    };
  }

  async logout(rawRefreshToken: string) {
    const tokenHash = HashUtil.hashToken(rawRefreshToken);
    await prisma.refreshToken.updateMany({
      where: { tokenHash },
      data: { isRevoked: true },
    });
    return { success: true };
  }

  async getProfile(userId: string) {
    let user = await prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });

    if (!user) {
      throw new BadRequestError('User not found');
    }

    // Auto-create profile if missing
    if (!user.profile) {
      const createdProfile = await prisma.profiles.create({
        data: {
          userId: user.id,
          displayName: user.name,
        },
      });
      user = { ...user, profile: createdProfile };
    }

    return {
      id: user.id,
      email: user.email,
      name: user.name,
      avatarUrl: user.avatarUrl,
      role: user.role,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      profile: user.profile,
    };
  }

  async updateProfile(userId: string, input: UpdateProfileInput) {
    return await prisma.$transaction(async (tx) => {
      if (input.name !== undefined || input.avatarUrl !== undefined) {
        await tx.user.update({
          where: { id: userId },
          data: {
            ...(input.name !== undefined ? { name: input.name.trim() } : {}),
            ...(input.avatarUrl !== undefined ? { avatarUrl: input.avatarUrl } : {}),
          },
        });
      }

      const updatedProfile = await tx.profiles.upsert({
        where: { userId },
        create: {
          userId,
          displayName: input.displayName ?? input.name ?? 'Athlete',
          username: input.username ?? undefined,
          avatarUrl: input.avatarUrl ?? undefined,
          bio: input.bio ?? undefined,
          gender: input.gender ?? undefined,
          birthDate: input.birthDate ?? undefined,
          heightCm: input.heightCm ?? undefined,
          weightKg: input.weightKg ?? undefined,
          unitPreference: input.unitPreference ?? 'kg',
          distanceUnit: input.distanceUnit ?? 'km',
          fitnessGoal: input.fitnessGoal ?? undefined,
          experienceLevel: input.experienceLevel ?? undefined,
        },
        update: {
          ...(input.displayName !== undefined ? { displayName: input.displayName } : {}),
          ...(input.username !== undefined ? { username: input.username } : {}),
          ...(input.avatarUrl !== undefined ? { avatarUrl: input.avatarUrl } : {}),
          ...(input.bio !== undefined ? { bio: input.bio } : {}),
          ...(input.gender !== undefined ? { gender: input.gender } : {}),
          ...(input.birthDate !== undefined ? { birthDate: input.birthDate } : {}),
          ...(input.heightCm !== undefined ? { heightCm: input.heightCm } : {}),
          ...(input.weightKg !== undefined ? { weightKg: input.weightKg } : {}),
          ...(input.unitPreference !== undefined ? { unitPreference: input.unitPreference } : {}),
          ...(input.distanceUnit !== undefined ? { distanceUnit: input.distanceUnit } : {}),
          ...(input.fitnessGoal !== undefined ? { fitnessGoal: input.fitnessGoal } : {}),
          ...(input.experienceLevel !== undefined ? { experienceLevel: input.experienceLevel } : {}),
        },
      });

      const user = await tx.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          email: true,
          name: true,
          avatarUrl: true,
          role: true,
          updatedAt: true,
        },
      });

      return {
        ...user,
        profile: updatedProfile,
      };
    });
  }
}
