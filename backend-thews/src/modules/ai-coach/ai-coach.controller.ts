import { FastifyReply, FastifyRequest } from 'fastify';
import { AICoachService } from './ai-coach.service.js';
import { AskAICoachSchema, OverloadAnalysisSchema } from './ai-coach.schema.js';
import { UnauthorizedError } from '../../core/errors/app-error.js';

export class AICoachController {
  constructor(private aiCoachService: AICoachService) {}

  ask = async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const validated = AskAICoachSchema.parse(request.body);
    const result = await this.aiCoachService.askCoach(request.user.id, validated, request.user.profileId);
    return reply.status(200).send({ success: true, data: result });
  };

  getOverload = async (request: FastifyRequest<{ Params: { exerciseId: string } }>, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError();
    const exerciseId = Number(request.params.exerciseId);
    const validated = OverloadAnalysisSchema.parse({ exerciseId });
    const result = await this.aiCoachService.getOverloadRecommendation(request.user.id, validated);
    return reply.status(200).send({ success: true, data: result });
  };
}
