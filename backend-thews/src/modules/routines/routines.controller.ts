import { FastifyReply, FastifyRequest } from 'fastify';
import { RoutinesService } from './routines.service.js';
import { CreateRoutineSchema, UpdateRoutineSchema } from './routines.schema.js';
import { UnauthorizedError } from '../../core/errors/app-error.js';

export class RoutinesController {
  constructor(private routinesService: RoutinesService) {}

  list = async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const data = await this.routinesService.listRoutines(request.user.id, request.user.profileId);
    return reply.status(200).send({ success: true, data });
  };

  getById = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const id = Number(request.params.id);
    const data = await this.routinesService.getRoutineById(id, request.user.id);
    return reply.status(200).send({ success: true, data });
  };

  create = async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const validated = CreateRoutineSchema.parse(request.body);
    const data = await this.routinesService.createRoutine(request.user.id, validated, request.user.profileId);
    return reply.status(201).send({ success: true, message: 'Routine created', data });
  };

  update = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const id = Number(request.params.id);
    const validated = UpdateRoutineSchema.parse(request.body);
    const data = await this.routinesService.updateRoutine(id, request.user.id, validated);
    return reply.status(200).send({ success: true, message: 'Routine updated', data });
  };

  delete = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const id = Number(request.params.id);
    await this.routinesService.deleteRoutine(id, request.user.id);
    return reply.status(200).send({ success: true, message: 'Routine deleted' });
  };
}
