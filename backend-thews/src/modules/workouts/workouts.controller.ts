import { FastifyReply, FastifyRequest } from 'fastify';
import { WorkoutsService } from './workouts.service.js';
import { CreateWorkoutSchema, UpdateWorkoutSchema, WorkoutQuerySchema } from './workouts.schema.js';
import { UnauthorizedError } from '../../core/errors/app-error.js';

export class WorkoutsController {
  constructor(private workoutsService: WorkoutsService) {}

  list = async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const query = WorkoutQuerySchema.parse(request.query);
    const result = await this.workoutsService.listWorkouts(request.user.id, query);
    return reply.status(200).send({ success: true, ...result });
  };

  getById = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const id = Number(request.params.id);
    const data = await this.workoutsService.getWorkoutById(id, request.user.id);
    return reply.status(200).send({ success: true, data });
  };

  create = async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const validated = CreateWorkoutSchema.parse(request.body);
    const data = await this.workoutsService.createWorkout(request.user.id, validated, request.user.profileId);
    return reply.status(201).send({ success: true, message: 'Workout logged successfully', data });
  };

  update = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const id = Number(request.params.id);
    const validated = UpdateWorkoutSchema.parse(request.body);
    const data = await this.workoutsService.updateWorkout(id, request.user.id, validated);
    return reply.status(200).send({ success: true, message: 'Workout updated successfully', data });
  };

  delete = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const id = Number(request.params.id);
    await this.workoutsService.deleteWorkout(id, request.user.id);
    return reply.status(200).send({ success: true, message: 'Workout deleted successfully' });
  };
}
