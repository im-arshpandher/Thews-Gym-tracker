import { FastifyInstance } from 'fastify';
import { AICoachService } from './ai-coach.service.js';
import { AICoachController } from './ai-coach.controller.js';
import { authenticate } from '../../core/middleware/auth.middleware.js';

export async function aiCoachRoutes(fastify: FastifyInstance) {
  const service = new AICoachService();
  const controller = new AICoachController(service);

  fastify.addHook('preHandler', authenticate);

  fastify.post('/ask', controller.ask);
  fastify.get('/overload/:exerciseId', controller.getOverload);
}
