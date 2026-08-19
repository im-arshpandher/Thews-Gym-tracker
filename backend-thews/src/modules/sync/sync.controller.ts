import { FastifyReply, FastifyRequest } from 'fastify';
import { SyncService } from './sync.service.js';
import { SyncPushSchema } from './sync.schema.js';
import { UnauthorizedError } from '../../core/errors/app-error.js';

export class SyncController {
  constructor(private syncService: SyncService) {}

  sync = async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const validated = SyncPushSchema.parse(request.body);
    const result = await this.syncService.performDeltaSync(request.user.id, validated, request.user.profileId);
    return reply.status(200).send({
      success: true,
      message: 'Delta sync completed successfully',
      data: result,
    });
  };
}
