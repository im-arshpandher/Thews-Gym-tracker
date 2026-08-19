import { FastifyInstance } from 'fastify';
import { ExercisesService } from './exercises.service.js';
import { ExercisesController } from './exercises.controller.js';
import { authenticate } from '../../core/middleware/auth.middleware.js';

export async function exercisesRoutes(fastify: FastifyInstance) {
  const service = new ExercisesService();
  const controller = new ExercisesController(service);

  fastify.addHook('preHandler', authenticate);

  fastify.get('/', controller.list);
  fastify.get('/:id', controller.getById);
  fastify.post('/', controller.create);
  fastify.patch('/:id', controller.update);
  fastify.delete('/:id', controller.delete);
}
