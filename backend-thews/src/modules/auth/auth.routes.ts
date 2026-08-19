import { FastifyInstance } from 'fastify';
import { AuthService } from './auth.service.js';
import { AuthController } from './auth.controller.js';
import { authenticate } from '../../core/middleware/auth.middleware.js';

export async function authRoutes(fastify: FastifyInstance) {
  const authService = new AuthService(fastify);
  const controller = new AuthController(authService);

  // Public authentication routes (rate limited by default)
  fastify.post('/register', controller.register);
  fastify.post('/login', controller.login);
  fastify.post('/refresh', controller.refresh);
  fastify.post('/logout', controller.logout);

  // Protected user profile routes
  fastify.get('/me', { preHandler: [authenticate] }, controller.getMe);
  fastify.patch('/me', { preHandler: [authenticate] }, controller.updateMe);
}
