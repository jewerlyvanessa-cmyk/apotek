import { Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { PrismaModule } from '../../infrastructure/prisma/prisma.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { LicenseController } from './license.controller';
import { LicenseInterceptor } from './license.interceptor';
import { LicenseService } from './license.service';
import { SubscriptionAlertsService } from './subscription-alerts.service';

@Module({
  imports: [PrismaModule, RealtimeModule, NotificationsModule],
  controllers: [LicenseController],
  providers: [
    LicenseService,
    SubscriptionAlertsService,
    {
      provide: APP_INTERCEPTOR,
      useClass: LicenseInterceptor,
    },
  ],
  exports: [LicenseService],
})
export class LicenseModule {}
