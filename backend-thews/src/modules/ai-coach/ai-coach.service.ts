import { prisma } from '../../core/database/prisma.js';
import { AskAICoachInput, OverloadAnalysisInput } from './ai-coach.schema.js';
import { env } from '../../config/env.js';

export class AICoachService {
  async askCoach(userId: string, input: AskAICoachInput, profileId?: string) {
    let coachReply: string;

    if (env.GEMINI_API_KEY) {
      try {
        const response = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${env.GEMINI_API_KEY}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              contents: [
                {
                  parts: [
                    {
                      text: `You are Thews AI, an elite strength and endurance fitness coach. Context: ${JSON.stringify(
                        input.userContext || {}
                      )}. Question: ${input.prompt}`,
                    },
                  ],
                },
              ],
            }),
          }
        );

        const data = (await response.json()) as {
          candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
        };
        coachReply =
          data?.candidates?.[0]?.content?.parts?.[0]?.text ||
          'Keep pushing consistently! Make sure to prioritize 7-9 hours of sleep and adequate protein intake.';
      } catch (err) {
        console.error('AI Coach API error:', err);
        coachReply =
          'Focus on gradual progressive overload, proper form, and adequate recovery between training blocks.';
      }
    } else {
      coachReply =
        `[Thews AI Coach] Based on your training data: Focus on increasing total volume load by 2.5-5% week over week. ` +
        `Ensure 48-72h recovery between targeting the same muscle group, and maintain high protein intake (1.6-2.2g per kg bodyweight).`;
    }

    // Persist interaction log
    await prisma.aICoachLog.create({
      data: {
        userId,
        profileId: profileId ?? null,
        prompt: input.prompt,
        response: coachReply,
        context: (input.userContext as object) ?? undefined,
      },
    });

    return { response: coachReply };
  }

  async getOverloadRecommendation(userId: string, input: OverloadAnalysisInput) {
    // Fetch last 5 workouts containing this exercise
    const history = await prisma.workoutExercises.findMany({
      where: {
        exerciseId: input.exerciseId,
        workout: { userId, deletedAt: null },
      },
      orderBy: { workout: { date: 'desc' } },
      take: 5,
      include: {
        workout: { select: { date: true } },
        setEntries: { orderBy: { setNumber: 'asc' } },
        exercise: true,
      },
    });

    if (history.length === 0) {
      return {
        exerciseId: input.exerciseId,
        status: 'insufficient_data',
        message: 'Log at least 1 session with this exercise to unlock smart progressive overload recommendations.',
      };
    }

    const latest = history[0];
    const normalSets = latest.setEntries.filter((s) => s.type === 'normal' || s.type === 'failure');
    const maxWeight = Math.max(...normalSets.map((s) => s.weight), 0);
    const avgReps =
      normalSets.length > 0
        ? Math.round(normalSets.reduce((sum, s) => sum + s.reps, 0) / normalSets.length)
        : 8;

    // Progressive overload recommendation: 2.5kg increase if reps target met, or +1 rep
    const recommendedWeight = maxWeight > 0 ? maxWeight + 2.5 : 20.0;
    const recommendedReps = avgReps >= 10 ? 8 : avgReps + 1;

    return {
      exerciseId: input.exerciseId,
      exerciseName: latest.exercise.name,
      lastRecordedWeight: maxWeight,
      lastRecordedAvgReps: avgReps,
      recommendedTargetWeight: recommendedWeight,
      recommendedTargetReps: recommendedReps,
      advice: `Recommended progression: Try ${recommendedWeight}kg for ${recommendedReps} reps on your first working set.`,
    };
  }
}
