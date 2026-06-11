import { existsSync } from 'fs';
import { join } from 'path';
import { config as loadEnv } from 'dotenv';
import * as Sentry from '@sentry/nestjs';

for (const envPath of [
  join(process.cwd(), 'data', 'config.env'),
  join(process.cwd(), '.env'),
]) {
  if (existsSync(envPath)) {
    loadEnv({ path: envPath });
    break;
  }
}

const dsn = process.env.SENTRY_DSN?.trim();

if (dsn) {
  Sentry.init({
    dsn,
    environment: process.env.NODE_ENV ?? 'development',
    tracesSampleRate: Number(process.env.SENTRY_TRACES_SAMPLE_RATE ?? '0.1'),
  });
}
