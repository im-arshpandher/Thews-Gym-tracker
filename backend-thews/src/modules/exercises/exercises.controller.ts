import { FastifyReply, FastifyRequest } from 'fastify';
import { ExercisesService } from './exercises.service.js';
import { CreateExerciseSchema, UpdateExerciseSchema, ExerciseQuerySchema } from './exercises.schema.js';
import { UnauthorizedError } from '../../core/errors/app-error.js';

export class ExercisesController {
  constructor(private exercisesService: ExercisesService) {}

  list = async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const query = ExerciseQuerySchema.parse(request.query);
    const data = await this.exercisesService.listExercises(request.user.id, query);
    return reply.status(200).send({ success: true, data });
  };

  getById = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const id = Number(request.params.id);
    const data = await this.exercisesService.getExerciseById(id, request.user.id);
    return reply.status(200).send({ success: true, data });
  };

  create = async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const validated = CreateExerciseSchema.parse(request.body);
    const data = await this.exercisesService.createCustomExercise(request.user.id, validated, request.user.profileId);
    return reply.status(201).send({ success: true, message: 'Custom exercise created', data });
  };

  update = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const id = Number(request.params.id);
    const validated = UpdateExerciseSchema.parse(request.body);
    const data = await this.exercisesService.updateCustomExercise(id, request.user.id, validated);
    return reply.status(200).send({ success: true, message: 'Exercise updated', data });
  };

  delete = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const id = Number(request.params.id);
    await this.exercisesService.deleteCustomExercise(id, request.user.id);
    return reply.status(200).send({ success: true, message: 'Exercise deleted' });
  };
}
