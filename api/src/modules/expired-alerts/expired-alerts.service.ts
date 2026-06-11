import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeService } from '../realtime/realtime.service';

@Injectable()
export class ExpiredAlertsService {
  private readonly logger = new Logger(ExpiredAlertsService.name);

  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeService,
    private notifications: NotificationsService,
    private config: ConfigService,
  ) {}

  private parseDays(value: string | undefined, fallback: number) {
    const n = Number(value);
    return Number.isFinite(n) && n >= 0 ? Math.floor(n) : fallback;
  }

  private daysLeft(from: Date, to: Date) {
    const ms = to.getTime() - from.getTime();
    return Math.ceil(ms / (24 * 60 * 60 * 1000));
  }

  // Default: run every day at 08:00 local server time
  @Cron(process.env.EXPIRED_CRON ?? '0 0 8 * * *')
  async emitExpired() {
    const thresholdDays = this.parseDays(
      this.config.get<string>('EXPIRED_THRESHOLD_DAYS'),
      30,
    );

    const now = new Date();
    const until = new Date(now);
    until.setDate(until.getDate() + thresholdDays);

    const stocks = await this.prisma.stock.findMany({
      where: {
        quantity: { gt: 0 },
        batch: {
          is: {
            expiredDate: { not: null, lte: until },
          },
        },
      },
      include: {
        medicine: { select: { id: true, name: true } },
        batch: { select: { id: true, batchNumber: true, expiredDate: true } },
      },
      orderBy: { updatedAt: 'desc' },
      take: 2000,
    });

    if (!stocks.length) return;

    const countByTenant = new Map<string, number>();
    for (const s of stocks) {
      countByTenant.set(s.tenantId, (countByTenant.get(s.tenantId) ?? 0) + 1);
    }

    for (const s of stocks) {
      const exp = s.batch?.expiredDate ?? null;
      const left = exp ? this.daysLeft(now, exp) : null;

      this.realtime.emitExpired(s.tenantId, s.branchId, {
        branch_id: s.branchId,
        medicine_id: s.medicineId,
        medicine_name: s.medicine?.name,
        batch_id: s.batchId,
        batch_number: s.batch?.batchNumber,
        expired_date: exp ? exp.toISOString() : null,
        quantity: s.quantity,
        days_left: left,
      });
    }

    for (const [tenantId, count] of countByTenant) {
      const admins = await this.prisma.user.findMany({
        where: {
          tenantId,
          isActive: true,
          role: { in: ['OWNER', 'MANAGER'] },
        },
        select: { id: true },
      });
      for (const admin of admins) {
        await this.notifications.sendToUser({
          tenantId,
          userId: admin.id,
          title: 'Alert obat kadaluarsa',
          body: `${count} batch perlu perhatian (≤${thresholdDays} hari)`,
          data: { type: 'batch_expired', count: String(count) },
        });
      }
    }

    this.logger.log(
      `Emitted expired alerts: count=${stocks.length} thresholdDays=${thresholdDays}`,
    );
  }
}
