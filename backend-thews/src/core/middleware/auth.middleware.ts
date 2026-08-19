import { FastifyReply, FastifyRequest } from 'fastify';
import '@fastify/jwt';
import { UnauthorizedError, ForbiddenError } from '../errors/app-error.js';

export interface AuthUserPayload {
  id: string;
  email: string;
  role: 'USER' | 'ADMIN';
  profileId?: string;
}

declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: AuthUserPayload;
    user: AuthUserPayload;
  }
}

export async function authenticate(request: FastifyRequest, _reply: FastifyReply) {
  try {
    await request.jwtVerify();
  } catch {
    throw new UnauthorizedError('Missing, invalid, or expired authentication token');
  }
}

export function requireRole(...allowedRoles: Array<'USER' | 'ADMIN'>) {
  return async (request: FastifyRequest, _reply: FastifyReply) => {
    if (!request.user) {
      throw new UnauthorizedError('Authentication required');
    }
    if (!allowedRoles.includes(request.user.role)) {
      throw new ForbiddenError('Insufficient permissions to access this resource');
    }
  };
}
