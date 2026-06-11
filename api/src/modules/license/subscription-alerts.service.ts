import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { MailService } from '../../infrastructure/mail/mail.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeService } from '../realtime/realtime.service';
import { LicenseService } from './license.service';

/** Peringatan langganan SaaS — log server + notifikasi realtime ke tenant. */
@Injectable()
export class SubscriptionAlertsService {
  private readonly logger = new Logger(SubscriptionAlertsService.name);

  constructor(
    private prisma: PrismaService,
    private license: LicenseService,
    private realtime: RealtimeService,
    private mail: MailService,
    private notifications: NotificationsService,
  ) {}

  @Cron(process.env.SUBSCRIPTION_CRON ?? '0 0 7 * * *')
  async checkTenantSubscriptions() {
    if (!this.license.isSaas()) return;

    const now = new Date();
    const warnBefore = new Date(now.getTime() + 14 * 86_400_000);

    const tenants = await this.prisma.tenant.findMany({
      where: {
        isActive: true,
        subscriptionExpiredAt: { not: null, lte: warnBefore },
      },
      select: {
        id: true,
        code: true,
        name: true,
        subscriptionPlan: true,
        subscriptionExpiredAt: true,
      },
    });

    for (const t of tenants) {
      const exp = t.subscriptionExpiredAt!;
      const days = Math.ceil((exp.getTime() - now.getTime()) / 86_400_000);
      if (days < 0) {
        this.logger.warn(
          `[Langganan] ${t.code} (${t.name}) kedaluwarsa ${Math.abs(days)} hari lalu · paket ${t.subscriptionPlan ?? '-'}`,
        );
      } else {
        this.logger.log(
          `[Langganan] ${t.code} (${t.name}) berakhir dalam ${days} hari · paket ${t.subscriptionPlan ?? '-'}`,
        );
      }

      this.realtime.emitSubscriptionWarning(t.id, {
        tenant_code: t.code,
        tenant_name: t.name,
        subscription_plan: t.subscriptionPlan,
        subscription_expired_at: exp.toISOString(),
        days_left: days,
      });
    }

    if (tenants.length > 0) {
      await this.notifySuperAdminsByEmail(
        tenants.filter(
          (t): t is typeof t & { subscriptionExpiredAt: Date } =>
            t.subscriptionExpiredAt != null,
        ),
        now,
      );
    }
  }

  private async notifySuperAdminsByEmail(
    tenants: Array<{
      code: string;
      name: string;
      subscriptionPlan: string | null;
      subscriptionExpiredAt: Date;
    }>,
    now: Date,
  ) {
    const admins = await this.prisma.user.findMany({
      where: { role: 'SUPER_ADMIN', isActive: true },
      select: { email: true },
    });
    const emails = admins
      .map((a) => a.email?.trim())
      .filter((e): e is string => Boolean(e));
    if (emails.length === 0) return;

    const lines = tenants.map((t) => {
      const exp = t.subscriptionExpiredAt;
      const days = Math.ceil((exp.getTime() - now.getTime()) / 86_400_000);
      const status =
        days < 0
          ? `kedaluwarsa ${Math.abs(days)} hari lalu`
          : `berakhir dalam ${days} hari`;
      return `• ${t.code} (${t.name}) — ${status} · paket ${t.subscriptionPlan ?? '-'}`;
    });

    const subject = `[ApotikFlow] Peringatan langganan (${tenants.length} tenant)`;
    const text = [
      'Ringkasan tenant yang perlu perhatian langganan:',
      '',
      ...lines,
      '',
      'Login ke Platform Admin untuk detail.',
    ].join('\n');

    await this.mail.send({ to: emails, subject, text });

    const superAdmins = await this.prisma.user.findMany({
      where: { role: 'SUPER_ADMIN', isActive: true },
      select: { id: true, tenantId: true },
    });
    for (const admin of superAdmins) {
      if (!admin.tenantId) continue;
      await this.notifications.sendToUser({
        tenantId: admin.tenantId,
        userId: admin.id,
        title: subject,
        body: `${tenants.length} tenant perlu perhatian langganan`,
        data: { type: 'subscription' },
      });
    }
  }
}
