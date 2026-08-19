import { FastifyReply, FastifyRequest } from 'fastify';
import { AuthService } from './auth.service.js';
import { RegisterSchema, LoginSchema, RefreshTokenSchema, UpdateProfileSchema } from './auth.schema.js';
import { UnauthorizedError } from '../../core/errors/app-error.js';

export class AuthController {
  constructor(private authService: AuthService) {}

  register = async (request: FastifyRequest, reply: FastifyReply) => {
    const validated = RegisterSchema.parse(request.body);
    const result = await this.authService.register(validated);
    return reply.status(201).send({
      success: true,
      message: 'User registered successfully',
      data: result,
    });
  };

  login = async (request: FastifyRequest, reply: FastifyReply) => {
    const validated = LoginSchema.parse(request.body);
    const result = await this.authService.login(validated);
    return reply.status(200).send({
      success: true,
      message: 'Login successful',
      data: result,
    });
  };

  refresh = async (request: FastifyRequest, reply: FastifyReply) => {
    const validated = RefreshTokenSchema.parse(request.body);
    const result = await this.authService.refreshTokens(validated.refreshToken);
    return reply.status(200).send({
      success: true,
      message: 'Token refreshed successfully',
      data: result,
    });
  };

  logout = async (request: FastifyRequest, reply: FastifyReply) => {
    const validated = RefreshTokenSchema.parse(request.body);
    await this.authService.logout(validated.refreshToken);
    return reply.status(200).send({
      success: true,
      message: 'Logged out successfully',
    });
  };

  getMe = async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const user = await this.authService.getProfile(request.user.id);
    return reply.status(200).send({
      success: true,
      data: user,
    });
  };

  updateMe = async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const validated = UpdateProfileSchema.parse(request.body);
    const updated = await this.authService.updateProfile(request.user.id, validated);
    return reply.status(200).send({
      success: true,
      message: 'Profile updated successfully',
      data: updated,
    });
  };
}
