import { FastifyInstance } from 'fastify';
import { RunningService } from './running.service.js';
import { RunningController } from './running.controller.js';
import { authenticate } from '../../core/middleware/auth.middleware.js';

export async function runningRoutes(fastify: FastifyInstance) {
  const service = new RunningService();
  const controller = new RunningController(service);

  fastify.addHook('preHandler', authenticate);

  fastify.get('/', controller.list);
  fastify.get('/stats', controller.getStats);
  fastify.get('/:id', controller.getById);
  fastify.post('/', controller.create);
  fastify.delete('/:id', controller.delete);
}
