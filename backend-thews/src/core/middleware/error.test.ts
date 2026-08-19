import { describe, it, expect } from 'vitest';
import Fastify from 'fastify';
import { z } from 'zod';
import { errorHandler } from './error.middleware.js';
import {
  BadRequestError,
  UnauthorizedError,
  ForbiddenError,
  NotFoundError,
  ConflictError,
  ValidationError,
} from '../errors/app-error.js';

describe('Error Handling Middleware', () => {
  const buildTestApp = () => {
    const app = Fastify();
    app.setErrorHandler(errorHandler);

    app.get('/bad-request', async () => {
      throw new BadRequestError('Custom bad request message');
    });

    app.get('/unauthorized', async () => {
      throw new UnauthorizedError('Custom unauthorized message');
    });

    app.get('/forbidden', async () => {
      throw new ForbiddenError('Custom forbidden message');
    });

    app.get('/not-found', async () => {
      throw new NotFoundError('Custom not found message');
    });

    app.get('/conflict', async () => {
      throw new ConflictError('Custom conflict message');
    });

    app.get('/validation-error', async () => {
      throw new ValidationError('Validation failed', [{ field: 'email', message: 'Invalid email' }]);
    });

    app.post('/zod-validation', async (req) => {
      const Schema = z.object({
        email: z.string().email(),
        age: z.number().min(18),
      });
      Schema.parse(req.body);
      return { success: true };
    });

    app.get('/unknown-crash', async () => {
      throw new Error('Unexpected crash simulation');
    });

    return app;
  };

  it('should format BadRequestError with 400 status', async () => {
    const app = buildTestApp();
    const res = await app.inject({ method: 'GET', url: '/bad-request' });
    expect(res.statusCode).toBe(400);
    const body = res.json();
    expect(body.success).toBe(false);
    expect(body.message).toBe('Custom bad request message');
  });

  it('should format UnauthorizedError with 401 status', async () => {
    const app = buildTestApp();
    const res = await app.inject({ method: 'GET', url: '/unauthorized' });
    expect(res.statusCode).toBe(401);
    const body = res.json();
    expect(body.success).toBe(false);
    expect(body.message).toBe('Custom unauthorized message');
  });

  it('should format ForbiddenError with 403 status', async () => {
    const app = buildTestApp();
    const res = await app.inject({ method: 'GET', url: '/forbidden' });
    expect(res.statusCode).toBe(403);
    const body = res.json();
    expect(body.success).toBe(false);
    expect(body.message).toBe('Custom forbidden message');
  });

  it('should format NotFoundError with 404 status', async () => {
    const app = buildTestApp();
    const res = await app.inject({ method: 'GET', url: '/not-found' });
    expect(res.statusCode).toBe(404);
    const body = res.json();
    expect(body.success).toBe(false);
    expect(body.message).toBe('Custom not found message');
  });

  it('should format ConflictError with 409 status', async () => {
    const app = buildTestApp();
    const res = await app.inject({ method: 'GET', url: '/conflict' });
    expect(res.statusCode).toBe(409);
    const body = res.json();
    expect(body.success).toBe(false);
    expect(body.message).toBe('Custom conflict message');
  });

  it('should format Zod schema errors with 422 status and field detail array', async () => {
    const app = buildTestApp();
    const res = await app.inject({
      method: 'POST',
      url: '/zod-validation',
      payload: { email: 'not-an-email', age: 15 },
    });
    expect(res.statusCode).toBe(422);
    const body = res.json();
    expect(body.success).toBe(false);
    expect(body.message).toBe('Validation Failed');
    expect(Array.isArray(body.errors)).toBe(true);
    expect(body.errors.length).toBe(2);
  });

  it('should format unknown server errors safely as 500 without leaking stack traces', async () => {
    const app = buildTestApp();
    const res = await app.inject({ method: 'GET', url: '/unknown-crash' });
    expect(res.statusCode).toBe(500);
    const body = res.json();
    expect(body.success).toBe(false);
    expect(body.message).toBe('Internal Server Error');
    expect(body.stack).toBeUndefined();
  });
});
