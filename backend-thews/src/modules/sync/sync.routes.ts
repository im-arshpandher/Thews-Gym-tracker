import { FastifyInstance } from 'fastify';
import { SyncService } from './sync.service.js';
import { SyncController } from './sync.controller.js';
import { authenticate } from '../../core/middleware/auth.middleware.js';

export async function syncRoutes(fastify: FastifyInstance) {
  const service = new SyncService();
  const controller = new SyncController(service);

  fastify.post('/', { preHandler: [authenticate] }, controller.sync);
}
