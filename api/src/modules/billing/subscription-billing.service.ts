import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { AuditLogsService } from '../audit-logs/audit-logs.service';
import {
  resolveLicensePlan,
  SUBSCRIPTION_PLANS,
} from '../license/license-plans';
import { LicenseService } from '../license/license.service';
import { BillingWebhookDto } from './dto/billing-webhook.dto';

@Injectable()
export class SubscriptionBillingService {
  private readonly logger = new Logger(SubscriptionBillingService.name);

  constructor(
    private prisma: PrismaService,
    private license: LicenseService,
    private audit: AuditLogsService,
  ) {}

  private subscriptionExpiredFromPlan(planId?: string | null): Date | null {
    const plan = resolveLicensePlan(planId ?? undefined, 'subscription');
    if (!plan?.days) return null;
    return new Date(Date.now() + plan.days * 86_400_000);
  }

  private async extendTenantSubscription(
    tenantId: string,
    input: { plan?: string; extend_days?: number },
  ) {
    const tenant = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
    });
    if (!tenant) throw new NotFoundException('Tenant tidak ditemukan');

    const plan = input.plan ?? tenant.subscriptionPlan ?? undefined;
    let expiredAt: Date | null = null;

    if (input.extend_days) {
      const base = tenant.subscriptionExpiredAt;
      const start =
        base && base.getTime() > Date.now() ? base.getTime() : Date.now();
      expiredAt = new Date(start + input.extend_days * 86_400_000);
    } else if (plan) {
      expiredAt = this.subscriptionExpiredFromPlan(plan);
    }

    return this.prisma.tenant.update({
      where: { id: tenantId },
      data: {
        ...(plan ? { subscriptionPlan: plan } : {}),
        ...(expiredAt ? { subscriptionExpiredAt: expiredAt } : {}),
        isActive: true,
      },
    });
  }

  assertSaasBillingEnabled() {
    if (!this.license.isSaas()) {
      throw new BadRequestException(
        'Billing otomatis hanya tersedia di mode SaaS',
      );
    }
  }

  listSubscriptionPlans() {
    this.assertSaasBillingEnabled();
    return SUBSCRIPTION_PLANS;
  }

  async createRenewalIntent(tenantId: string, planId?: string) {
    this.assertSaasBillingEnabled();
    const tenant = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: {
        id: true,
        code: true,
        name: true,
        subscriptionPlan: true,
        subscriptionExpiredAt: true,
      },
    });
    if (!tenant) throw new NotFoundException('Tenant tidak ditemukan');

    const plan = planId ?? tenant.subscriptionPlan ?? 'starter';
    const planDef = resolveLicensePlan(plan, 'subscription');
    const extendDays = planDef?.days ?? 365;
    const reference = `RENEW-${tenant.code}-${randomUUID().slice(0, 8).toUpperCase()}`;

    return {
      reference,
      tenant_code: tenant.code,
      tenant_name: tenant.name,
      plan,
      plan_label: planDef?.label ?? plan,
      extend_days: extendDays,
      current_expired_at: tenant.subscriptionExpiredAt?.toISOString() ?? null,
      instructions:
        'Selesaikan pembayaran ke gateway Anda dengan reference di atas. ' +
        'Setelah PAID, gateway memanggil POST /billing/webhook.',
    };
  }

  async processWebhook(dto: BillingWebhookDto) {
    this.assertSaasBillingEnabled();

    if (dto.status !== 'PAID') {
      return { processed: false, reason: `Status ${dto.status} diabaikan` };
    }

    const tenant = await this.prisma.tenant.findUnique({
      where: { code: dto.tenant_code.trim().toUpperCase() },
    });
    if (!tenant) {
      throw new NotFoundException(`Tenant ${dto.tenant_code} tidak ditemukan`);
    }

    const plan = dto.plan ?? tenant.subscriptionPlan ?? 'starter';
    const planDef = resolveLicensePlan(plan, 'subscription');
    const extendDays = dto.extend_days ?? planDef?.days ?? 365;

    const updated = await this.extendTenantSubscription(tenant.id, {
      plan,
      extend_days: extendDays,
    });

    await this.audit.log({
      tenantId: tenant.id,
      userId: null,
      module: 'billing',
      action: 'SUBSCRIPTION_RENEWED',
      referenceId: dto.reference ?? null,
      newData: {
        plan,
        extend_days: extendDays,
        amount: dto.amount ?? null,
        subscription_expired_at: updated.subscriptionExpiredAt,
      },
    });

    this.logger.log(
      `[Billing] ${tenant.code} diperpanjang ${extendDays} hari · paket ${plan}`,
    );

    return {
      processed: true,
      tenant_id: tenant.id,
      tenant_code: tenant.code,
      plan,
      subscription_expired_at: updated.subscriptionExpiredAt?.toISOString(),
    };
  }

  @Cron(process.env.BILLING_SUSPEND_CRON ?? '0 30 7 * * *')
  async suspendExpiredTenants() {
    if (!this.license.isSaas()) return;

    const raw = process.env.LICENSE_GRACE_DAYS ?? '7';
    const graceDays = parseInt(raw, 10);
    const graceMs = (Number.isFinite(graceDays) ? graceDays : 7) * 86_400_000;
    const cutoff = new Date(Date.now() - graceMs);

    const tenants = await this.prisma.tenant.findMany({
      where: {
        isActive: true,
        subscriptionExpiredAt: { not: null, lt: cutoff },
      },
      select: { id: true, code: true, name: true, subscriptionExpiredAt: true },
    });

    for (const t of tenants) {
      await this.prisma.tenant.update({
        where: { id: t.id },
        data: { isActive: false },
      });
      this.logger.warn(
        `[Billing] Tenant ${t.code} dinonaktifkan — langganan habis sejak ${t.subscriptionExpiredAt?.toISOString()}`,
      );
      await this.audit.log({
        tenantId: t.id,
        userId: null,
        module: 'billing',
        action: 'SUBSCRIPTION_SUSPENDED',
        newData: { reason: 'expired_past_grace' },
      });
    }

    if (tenants.length > 0) {
      this.logger.log(
        `[Billing] ${tenants.length} tenant dinonaktifkan otomatis`,
      );
    }
  }
}
