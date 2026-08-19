import { FastifyError, FastifyReply, FastifyRequest } from 'fastify';
import { ZodError } from 'zod';
import { AppError } from '../errors/app-error.js';
import { env } from '../../config/env.js';

export function errorHandler(
  error: FastifyError | AppError | ZodError | Error,
  _request: FastifyRequest,
  reply: FastifyReply
) {
  // 1. Domain AppError
  if (error instanceof AppError) {
    return reply.status(error.statusCode).send({
      success: false,
      message: error.message,
      ...(error.details ? { errors: error.details } : {}),
    });
  }

  // 2. Zod Schema Validation Error
  if (error instanceof ZodError) {
    const formattedErrors = error.errors.map((e) => ({
      field: e.path.join('.'),
      message: e.message,
    }));

    return reply.status(422).send({
      success: false,
      message: 'Validation Failed',
      errors: formattedErrors,
    });
  }

  // 3. Fastify Built-in Errors (e.g., Rate Limiter 429, Body parsing)
  const statusCode = (error as FastifyError).statusCode || 500;

  if (statusCode === 429) {
    return reply.status(429).send({
      success: false,
      message: 'Too Many Requests. Please slow down.',
    });
  }

  // 4. Unknown internal server errors
  if (env.NODE_ENV === 'development') {
    console.error('💥 Uncaught Error:', error);
  }

  return reply.status(statusCode >= 500 ? 500 : statusCode).send({
    success: false,
    message: statusCode >= 500 ? 'Internal Server Error' : error.message,
  });
}
