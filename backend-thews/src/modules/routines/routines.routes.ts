import { FastifyInstance } from 'fastify';
import { RoutinesService } from './routines.service.js';
import { RoutinesController } from './routines.controller.js';
import { authenticate } from '../../core/middleware/auth.middleware.js';

export async function routinesRoutes(fastify: FastifyInstance) {
  const service = new RoutinesService();
  const controller = new RoutinesController(service);

  fastify.addHook('preHandler', authenticate);

  fastify.get('/', controller.list);
  fastify.get('/:id', controller.getById);
  fastify.post('/', controller.create);
  fastify.patch('/:id', controller.update);
  fastify.delete('/:id', controller.delete);
}
