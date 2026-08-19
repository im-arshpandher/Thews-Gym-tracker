import { buildApp } from './app.js';
import { env } from './config/env.js';
import { prisma } from './core/database/prisma.js';

const app = buildApp();

const start = async () => {
  try {
    await app.listen({ port: env.PORT, host: env.HOST });
    console.log(`🚀 Thews Backend Server running on http://${env.HOST}:${env.PORT}`);
    console.log(`🩺 Health check available at http://${env.HOST}:${env.PORT}/health`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
};

// Graceful shutdown handlers
const shutdown = async (signal: string) => {
  console.log(`\n🛑 Received ${signal}. Shutting down gracefully...`);
  try {
    await app.close();
    await prisma.$disconnect();
    console.log('✅ Server and database connections closed safely.');
    process.exit(0);
  } catch (err) {
    console.error('Error during shutdown:', err);
    process.exit(1);
  }
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

start();
