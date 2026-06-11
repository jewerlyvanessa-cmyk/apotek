import { Module } from '@nestjs/common';
import { PrismaModule } from '../../infrastructure/prisma/prisma.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { ExpiredAlertsService } from './expired-alerts.service';

@Module({
  imports: [PrismaModule, RealtimeModule, NotificationsModule],
  providers: [ExpiredAlertsService],
  exports: [ExpiredAlertsService],
})
export class ExpiredAlertsModule {}

