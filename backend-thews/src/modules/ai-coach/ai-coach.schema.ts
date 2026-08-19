import { z } from 'zod';

export const AskAICoachSchema = z.object({
  prompt: z.string().min(1).max(2000),
  userContext: z
    .object({
      targetGoal: z.string().optional(),
      fatigueScore: z.number().min(0).max(100).optional(),
      recentWorkoutsSummary: z.string().optional(),
    })
    .optional(),
});

export const OverloadAnalysisSchema = z.object({
  exerciseId: z.number().int().positive(),
});

export type AskAICoachInput = z.infer<typeof AskAICoachSchema>;
export type OverloadAnalysisInput = z.infer<typeof OverloadAnalysisSchema>;
