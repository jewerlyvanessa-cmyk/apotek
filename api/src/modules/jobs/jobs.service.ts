import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

@Injectable()
export class JobsService {
  private readonly logger = new Logger(JobsService.name);
  private readonly jobsEnabled: boolean;

  constructor(
    @InjectQueue('reports') private reportsQueue: Queue,
    @InjectQueue('notifications') private notificationsQueue: Queue,
    config: ConfigService,
  ) {
    this.jobsEnabled = !!config.get<string>('REDIS_URL')?.trim();
    if (!this.jobsEnabled) {
      this.logger.log(
        'Background jobs disabled (set REDIS_URL to enable BullMQ queues)',
      );
    }
  }

  async enqueueWarmSalesReport(params: {
    tenantId: string;
    branchId?: string;
    dateFromIso: string;
    dateToIso: string;
  }) {
    if (!this.jobsEnabled) return;
    await this.reportsQueue.add('warm_sales_report', params, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 2000 },
      removeOnComplete: 50,
      removeOnFail: 200,
    });
  }

  async enqueueEmitExpiredSweep() {
    if (!this.jobsEnabled) return;
    await this.notificationsQueue.add(
      'emit_expired_sweep',
      {},
      {
        attempts: 2,
        backoff: { type: 'fixed', delay: 3000 },
        removeOnComplete: 20,
        removeOnFail: 50,
      },
    );
    this.logger.log('Enqueued notifications.emit_expired_sweep');
  }
}
