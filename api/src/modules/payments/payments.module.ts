import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { QrisProviderService } from './qris-provider.service';
import { QrisWebhookGuard } from './qris-webhook.guard';

@Module({
  imports: [RealtimeModule, NotificationsModule],
  controllers: [PaymentsController],
  providers: [PaymentsService, QrisProviderService, QrisWebhookGuard],
})
export class PaymentsModule {}
