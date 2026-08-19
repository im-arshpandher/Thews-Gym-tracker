import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import jwt from '@fastify/jwt';
import { env } from './config/env.js';
import { errorHandler } from './core/middleware/error.middleware.js';
import { authRoutes } from './modules/auth/auth.routes.js';
import { exercisesRoutes } from './modules/exercises/exercises.routes.js';
import { workoutsRoutes } from './modules/workouts/workouts.routes.js';
import { routinesRoutes } from './modules/routines/routines.routes.js';
import { runningRoutes } from './modules/running/running.routes.js';
import { syncRoutes } from './modules/sync/sync.routes.js';
import { aiCoachRoutes } from './modules/ai-coach/ai-coach.routes.js';

export function buildApp() {
  const fastify = Fastify({
    logger:
      env.NODE_ENV === 'development'
        ? {
            transport: {
              target: 'pino-pretty',
              options: {
                translateTime: 'HH:MM:ss Z',
                ignore: 'pid,hostname',
              },
            },
          }
        : true,
  });

  // 1. Security Headers (Helmet)
  fastify.register(helmet, {
    contentSecurityPolicy: false,
  });

  // 2. CORS Support
  fastify.register(cors, {
    origin: env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN.split(','),
    credentials: true,
  });

  // 3. Rate Limiting Defense
  fastify.register(rateLimit, {
    max: env.RATE_LIMIT_MAX,
    timeWindow: env.RATE_LIMIT_TIME_WINDOW,
  });

  // 4. JWT Authentication Plugin
  fastify.register(jwt, {
    secret: env.JWT_ACCESS_SECRET,
  });

  // 5. Global Error Handler
  fastify.setErrorHandler(errorHandler);

  // 6. Health Check Endpoint
  fastify.get('/health', async () => {
    return {
      status: 'ok',
      service: 'thews-backend',
      timestamp: new Date().toISOString(),
    };
  });

  // 7. Register API Modules under /api/v1 prefix
  fastify.register(authRoutes, { prefix: '/api/v1/auth' });
  fastify.register(exercisesRoutes, { prefix: '/api/v1/exercises' });
  fastify.register(workoutsRoutes, { prefix: '/api/v1/workouts' });
  fastify.register(routinesRoutes, { prefix: '/api/v1/routines' });
  fastify.register(runningRoutes, { prefix: '/api/v1/running' });
  fastify.register(syncRoutes, { prefix: '/api/v1/sync' });
  fastify.register(aiCoachRoutes, { prefix: '/api/v1/ai-coach' });

  return fastify;
}
