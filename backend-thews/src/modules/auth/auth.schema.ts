import { z } from 'zod';

export const RegisterSchema = z.object({
  email: z.string().email('Invalid email address').max(255),
  password: z.string().min(8, 'Password must be at least 8 characters').max(128),
  name: z.string().min(2, 'Name must be at least 2 characters').max(100),
  username: z.string().min(3).max(30).optional(),
});

export const LoginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(1, 'Password is required'),
});

export const RefreshTokenSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

export const UpdateProfileSchema = z.object({
  name: z.string().min(2).max(100).optional(),
  username: z.string().min(3).max(30).optional().nullable(),
  displayName: z.string().min(1).max(100).optional(),
  avatarUrl: z.string().url().optional().nullable(),
  bio: z.string().max(500).optional().nullable(),
  gender: z.enum(['male', 'female', 'other']).optional().nullable(),
  birthDate: z.coerce.date().optional().nullable(),
  heightCm: z.number().min(50).max(300).optional().nullable(),
  weightKg: z.number().min(20).max(500).optional().nullable(),
  unitPreference: z.enum(['kg', 'lbs']).optional(),
  distanceUnit: z.enum(['km', 'miles']).optional(),
  fitnessGoal: z.enum(['hypertrophy', 'strength', 'endurance', 'fat_loss', 'general_fitness']).optional().nullable(),
  experienceLevel: z.enum(['beginner', 'intermediate', 'advanced']).optional().nullable(),
});

export type RegisterInput = z.infer<typeof RegisterSchema>;
export type LoginInput = z.infer<typeof LoginSchema>;
export type RefreshTokenInput = z.infer<typeof RefreshTokenSchema>;
export type UpdateProfileInput = z.infer<typeof UpdateProfileSchema>;
