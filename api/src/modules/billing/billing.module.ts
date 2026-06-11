import { Module } from '@nestjs/common';
import { AuditLogsModule } from '../audit-logs/audit-logs.module';
import { LicenseModule } from '../license/license.module';
import { BillingController } from './billing.controller';
import { BillingWebhookGuard } from './billing-webhook.guard';
import { SubscriptionBillingService } from './subscription-billing.service';

@Module({
  imports: [LicenseModule, AuditLogsModule],
  controllers: [BillingController],
  providers: [SubscriptionBillingService, BillingWebhookGuard],
})
export class BillingModule {}
