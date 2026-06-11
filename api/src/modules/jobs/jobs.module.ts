import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { RedisOptions } from 'ioredis';
import { ExpiredAlertsModule } from '../expired-alerts/expired-alerts.module';
import { ReportsModule } from '../reports/reports.module';
import { JobsService } from './jobs.service';
import { NotificationsProcessor } from './processors/notifications.processor';
import { ReportsProcessor } from './processors/reports.processor';

function redisOptionsFromUrl(url: string): RedisOptions {
  const u = new URL(url);
  return {
    host: u.hostname,
    port: u.port ? parseInt(u.port, 10) : 6379,
    username: u.username || undefined,
    password: u.password || undefined,
    db: u.pathname && u.pathname !== '/' ? parseInt(u.pathname.slice(1), 10) : undefined,
    tls: u.protocol === 'rediss:' ? {} : undefined,
  };
}

@Module({
  imports: [
    ConfigModule,
    BullModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const url = config.get<string>('REDIS_URL');
        if (!url) {
          // BullMQ needs Redis. Keep app bootable in dev without jobs.
          // Queue operations will be effectively disabled since no connection.
          return { connection: undefined as any };
        }
        return { connection: redisOptionsFromUrl(url) };
      },
    }),
    BullModule.registerQueue(
      { name: 'reports' },
      { name: 'notifications' },
    ),
    ReportsModule,
    ExpiredAlertsModule,
  ],
  providers: [JobsService, ReportsProcessor, NotificationsProcessor],
  exports: [JobsService],
})
export class JobsModule {}

