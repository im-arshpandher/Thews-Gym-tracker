import { FastifyInstance } from 'fastify';
import { WorkoutsService } from './workouts.service.js';
import { WorkoutsController } from './workouts.controller.js';
import { authenticate } from '../../core/middleware/auth.middleware.js';

export async function workoutsRoutes(fastify: FastifyInstance) {
  const service = new WorkoutsService();
  const controller = new WorkoutsController(service);

  fastify.addHook('preHandler', authenticate);

  fastify.get('/', controller.list);
  fastify.get('/:id', controller.getById);
  fastify.post('/', controller.create);
  fastify.patch('/:id', controller.update);
  fastify.delete('/:id', controller.delete);
}
