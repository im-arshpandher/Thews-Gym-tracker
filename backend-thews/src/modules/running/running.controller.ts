import { FastifyReply, FastifyRequest } from 'fastify';
import { RunningService } from './running.service.js';
import { CreateRunActivitySchema, RunQuerySchema } from './running.schema.js';
import { UnauthorizedError } from '../../core/errors/app-error.js';

export class RunningController {
  constructor(private runningService: RunningService) {}

  list = async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const query = RunQuerySchema.parse(request.query);
    const result = await this.runningService.listActivities(request.user.id, query);
    return reply.status(200).send({ success: true, ...result });
  };

  getStats = async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const stats = await this.runningService.getOverallStats(request.user.id, request.user.profileId);
    return reply.status(200).send({ success: true, data: stats });
  };

  getById = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const id = Number(request.params.id);
    const data = await this.runningService.getActivityById(id, request.user.id);
    return reply.status(200).send({ success: true, data });
  };

  create = async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const validated = CreateRunActivitySchema.parse(request.body);
    const data = await this.runningService.createActivity(request.user.id, validated, request.user.profileId);
    return reply.status(201).send({ success: true, message: 'Run activity saved', data });
  };

  delete = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const id = Number(request.params.id);
    await this.runningService.deleteActivity(id, request.user.id);
    return reply.status(200).send({ success: true, message: 'Run activity deleted' });
  };
}
