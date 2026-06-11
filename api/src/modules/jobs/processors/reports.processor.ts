import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { RedisCacheService } from '../../../infrastructure/redis/redis.service';
import { ReportsService } from '../../reports/reports.service';

@Processor('reports')
export class ReportsProcessor extends WorkerHost {
  constructor(
    private reports: ReportsService,
    private cache: RedisCacheService,
  ) {
    super();
  }

  async process(
    job: Job<
      | {
          tenantId: string;
          branchId?: string;
          dateFromIso: string;
          dateToIso: string;
        }
      | Record<string, never>
    >,
  ): Promise<any> {
    if (job.name === 'warm_sales_report') {
      const { tenantId, branchId, dateFromIso, dateToIso } = job.data as any;

      // Minimal "user" payload to reuse existing ReportsService implementation.
      const user = {
        sub: 'job',
        email: 'job@local',
        tenantId,
        branchId: branchId ?? undefined,
        role: 'OWNER',
      };

      const data = await this.reports.sales(user as any, {
        date_from: dateFromIso,
        date_to: dateToIso,
        branch_id: branchId,
      } as any);

      // Cache snapshot for fast retrieval if needed later.
      const key = `reports:sales:${tenantId}:${branchId ?? 'all'}:${dateFromIso}:${dateToIso}`;
      await this.cache.setJson(key, data, 60, [`reports:${tenantId}`]);
      return { cached_key: key };
    }

    return null;
  }
}

