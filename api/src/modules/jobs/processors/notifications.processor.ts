import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { ExpiredAlertsService } from '../../expired-alerts/expired-alerts.service';

@Processor('notifications')
export class NotificationsProcessor extends WorkerHost {
  constructor(private expiredAlerts: ExpiredAlertsService) {
    super();
  }

  async process(job: Job): Promise<any> {
    if (job.name === 'emit_expired_sweep') {
      await this.expiredAlerts.emitExpired();
      return { ok: true };
    }
    return null;
  }
}

