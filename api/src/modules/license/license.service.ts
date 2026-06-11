import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { join } from 'path';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import {
  resolveLicensePlan,
  resolveTenantSubscriptionPlan,
} from './license-plans';
import { signLicensePayload, verifyLicenseToken } from './license-token.util';
import {
  DeploymentMode,
  InstallationLicenseStatus,
  LicensePayload,
  LicenseStatusResponse,
  TenantSubscriptionStatus,
} from './license.types';

@Injectable()
export class LicenseService implements OnModuleInit {
  private cachedPayload: LicensePayload | null | undefined;

  constructor(
    private config: ConfigService,
    private prisma: PrismaService,
  ) {}

  async onModuleInit() {
    this.cachedPayload = undefined;
    this.assertLicenseSecretConfigured();
    if (!this.isOnPrem()) return;

    const payload = this.getInstallationPayload();
    if (payload) {
      try {
        await this.syncTenantsFromLicensePayload(payload);
      } catch (err) {
        console.error('Gagal sinkron tenant dari lisensi:', err);
      }
    }
  }

  getDeploymentMode(): DeploymentMode {
    const raw = (this.config.get<string>('DEPLOYMENT_MODE') ?? 'saas')
      .trim()
      .toLowerCase();
    return raw === 'on_prem' || raw === 'onprem' || raw === 'on-prem'
      ? 'on_prem'
      : 'saas';
  }

  isOnPrem(): boolean {
    return this.getDeploymentMode() === 'on_prem';
  }

  isSaas(): boolean {
    return !this.isOnPrem();
  }

  isPlatformEnabled(): boolean {
    const flag = this.config.get<string>('ENABLE_PLATFORM', 'true');
    if (flag === 'true' || flag === '1') return true;
    if (this.isOnPrem()) return false;
    return flag !== 'false' && flag !== '0';
  }

  private assertLicenseSecretConfigured() {
    if (!this.isOnPrem()) return;
    const nodeEnv = (this.config.get<string>('NODE_ENV') ?? 'development').trim();
    if (nodeEnv !== 'production') return;

    const secret = this.config.get<string>('LICENSE_SECRET')?.trim();
    const weak = new Set(['', 'change-me', 'change-me-in-production']);
    if (!secret || weak.has(secret)) {
      throw new Error(
        'LICENSE_SECRET wajib di-set untuk deployment on-prem production',
      );
    }
  }

  private licenseSecret(): string {
    const license = this.config.get<string>('LICENSE_SECRET')?.trim();
    if (license) return license;

    const jwt = this.config.get<string>('JWT_SECRET')?.trim();
    if (jwt) return jwt;

    const nodeEnv = (this.config.get<string>('NODE_ENV') ?? 'development').trim();
    if (nodeEnv === 'production' && this.isOnPrem()) {
      throw new Error('LICENSE_SECRET tidak dikonfigurasi');
    }
    return 'change-me-in-production';
  }

  private licenseFilePath(): string {
    const custom = this.config.get<string>('LICENSE_FILE_PATH')?.trim();
    if (custom) return custom;
    return join(process.cwd(), 'data', 'license.key');
  }

  private readLicenseKeyFromSources(): string | null {
    const fromEnv = this.config.get<string>('LICENSE_KEY')?.trim();
    if (fromEnv) return fromEnv;

    const filePath = this.licenseFilePath();
    if (!existsSync(filePath)) return null;
    const content = readFileSync(filePath, 'utf8').trim();
    return content || null;
  }

  getInstallationPayload(): LicensePayload | null {
    if (this.cachedPayload !== undefined) return this.cachedPayload;

    const key = this.readLicenseKeyFromSources();
    if (!key) {
      this.cachedPayload = null;
      return null;
    }

    this.cachedPayload = verifyLicenseToken(key, this.licenseSecret(), {
      allowExpired: true,
    });
    return this.cachedPayload;
  }

  getInstallationStatus(): InstallationLicenseStatus {
    const payload = this.getInstallationPayload();
    if (!payload) {
      return {
        valid: false,
        message: 'Lisensi instalasi belum diaktifkan',
      };
    }

    const expiresAt = payload.exp
      ? new Date(payload.exp * 1000).toISOString()
      : null;

    if (payload.exp) {
      const now = Date.now();
      const expMs = payload.exp * 1000;
      const graceMs = this.graceDays() * 86_400_000;

      if (expMs < now) {
        if (expMs + graceMs > now) {
          return {
            valid: true,
            type: payload.type,
            customer: payload.customer,
            plan: payload.plan,
            tenant_code: payload.tenant_code,
            max_branches: payload.max_branches,
            expires_at: expiresAt,
            message: `Masa tenggang lisensi (${this.graceDays()} hari)`,
          };
        }
        return {
          valid: false,
          type: payload.type,
          customer: payload.customer,
          plan: payload.plan,
          tenant_code: payload.tenant_code,
          max_branches: payload.max_branches,
          expires_at: expiresAt,
          message: 'Lisensi instalasi telah kedaluwarsa',
        };
      }
    }

    return {
      valid: true,
      type: payload.type,
      customer: payload.customer,
      plan: payload.plan,
      tenant_code: payload.tenant_code,
      max_branches: payload.max_branches,
      expires_at: expiresAt,
    };
  }

  private graceDays(): number {
    const raw = this.config.get<string>('LICENSE_GRACE_DAYS', '7');
    const n = parseInt(raw, 10);
    return Number.isFinite(n) && n >= 0 ? n : 7;
  }

  async getTenantSubscriptionStatus(
    tenantId: string,
  ): Promise<TenantSubscriptionStatus> {
    const tenant = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: {
        isActive: true,
        subscriptionPlan: true,
        subscriptionExpiredAt: true,
        code: true,
      },
    });

    if (!tenant) {
      return { valid: false, message: 'Tenant tidak ditemukan' };
    }

    if (!tenant.isActive) {
      return {
        valid: false,
        plan: tenant.subscriptionPlan,
        message: 'Tenant dinonaktifkan',
      };
    }

    const expiresAt = tenant.subscriptionExpiredAt;
    if (!expiresAt) {
      return {
        valid: true,
        plan: tenant.subscriptionPlan,
        expires_at: null,
        days_remaining: null,
      };
    }

    const now = new Date();
    const msLeft = expiresAt.getTime() - now.getTime();
    const daysRemaining = Math.ceil(msLeft / (24 * 60 * 60 * 1000));
    const graceMs = this.graceDays() * 24 * 60 * 60 * 1000;

    if (msLeft > 0) {
      return {
        valid: true,
        plan: tenant.subscriptionPlan,
        expires_at: expiresAt.toISOString(),
        days_remaining: daysRemaining,
      };
    }

    if (msLeft + graceMs > 0) {
      return {
        valid: true,
        plan: tenant.subscriptionPlan,
        expires_at: expiresAt.toISOString(),
        days_remaining: daysRemaining,
        in_grace_period: true,
        message: `Masa tenggang langganan (${this.graceDays()} hari)`,
      };
    }

    return {
      valid: false,
      plan: tenant.subscriptionPlan,
      expires_at: expiresAt.toISOString(),
      days_remaining: daysRemaining,
      message: 'Langganan tenant telah berakhir',
    };
  }

  assertInstallationLicense(): void {
    if (!this.isOnPrem()) return;

    const status = this.getInstallationStatus();
    if (!status.valid) {
      throw new ForbiddenException({
        message: status.message ?? 'Lisensi instalasi tidak valid',
        code: 'LICENSE_INVALID',
      });
    }
    if (status.message?.includes('tenggang')) {
      return;
    }
  }

  /** Batas cabang dari lisensi on-prem (null = tidak dibatasi). */
  getMaxBranchesLimit(): number | null {
    if (!this.isOnPrem()) return null;
    const payload = this.getInstallationPayload();
    return payload?.max_branches ?? null;
  }

  async assertBranchLimit(tenantId: string): Promise<void> {
    if (!this.isOnPrem()) return;

    const payload = this.getInstallationPayload();
    if (!payload?.max_branches) return;

    const tenant = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: { code: true },
    });
    if (
      payload.tenant_code &&
      tenant?.code &&
      payload.tenant_code !== tenant.code
    ) {
      return;
    }

    const count = await this.prisma.branch.count({ where: { tenantId } });
    if (count >= payload.max_branches) {
      throw new ForbiddenException({
        message: `Batas cabang lisensi (${payload.max_branches}) telah tercapai`,
        code: 'BRANCH_LIMIT_REACHED',
      });
    }
  }

  async assertTenantAccess(tenantId: string): Promise<void> {
    const tenantRow = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: { isActive: true, code: true },
    });
    if (!tenantRow?.isActive) {
      throw new ForbiddenException({
        message: 'Tenant dinonaktifkan',
        code: 'TENANT_INACTIVE',
      });
    }

    if (this.isOnPrem()) {
      this.assertInstallationLicense();
      const payload = this.getInstallationPayload();
      if (!payload) return;

      const tenant = tenantRow;
      if (
        payload.tenant_code &&
        tenant.code &&
        payload.tenant_code !== tenant.code
      ) {
        throw new ForbiddenException({
          message: 'Lisensi tidak berlaku untuk tenant ini',
          code: 'LICENSE_TENANT_MISMATCH',
        });
      }
      return;
    }

    const sub = await this.getTenantSubscriptionStatus(tenantId);
    if (!sub.valid) {
      throw new ForbiddenException({
        message: sub.message ?? 'Langganan tidak aktif',
        code: 'SUBSCRIPTION_EXPIRED',
      });
    }
  }

  async getPublicStatus(tenantId?: string): Promise<LicenseStatusResponse> {
    const mode = this.getDeploymentMode();
    const response: LicenseStatusResponse = { deployment_mode: mode };

    if (mode === 'on_prem') {
      response.installation = this.getInstallationStatus();
    }

    if (tenantId) {
      response.tenant = await this.getTenantSubscriptionStatus(tenantId);
    }

    return response;
  }

  /** Sinkronkan paket & masa berlaku lisensi ke baris tenant di database. */
  async syncTenantsFromLicensePayload(
    payload: LicensePayload,
  ): Promise<string[]> {
    const subscriptionPlan = resolveTenantSubscriptionPlan(payload);
    const subscriptionExpiredAt = payload.exp
      ? new Date(payload.exp * 1000)
      : null;

    if (payload.tenant_code) {
      const tenant = await this.prisma.tenant.findUnique({
        where: { code: payload.tenant_code },
        select: { code: true },
      });
      if (!tenant) {
        throw new BadRequestException(
          `Tenant dengan kode ${payload.tenant_code} tidak ditemukan`,
        );
      }
      await this.prisma.$executeRaw`
        UPDATE tenants
        SET subscription_plan = ${subscriptionPlan},
            subscription_expired_at = ${subscriptionExpiredAt},
            is_active = true
        WHERE code = ${payload.tenant_code}
      `;
      return [tenant.code];
    }

    const tenants = await this.prisma.tenant.findMany({
      select: { code: true },
    });
    if (tenants.length === 0) return [];

    await this.prisma.$executeRaw`
      UPDATE tenants
      SET subscription_plan = ${subscriptionPlan},
          subscription_expired_at = ${subscriptionExpiredAt},
          is_active = true
    `;
    return tenants.map((t) => t.code);
  }

  generateLicenseKey(input: {
    customer: string;
    type?: LicensePayload['type'];
    plan?: string;
    tenant_code?: string;
    max_branches?: number;
    days?: number;
  }) {
    const licenseType = input.type ?? 'perpetual';
    const planDef = resolveLicensePlan(input.plan, licenseType);
    let maxBranches = input.max_branches;
    let days = input.days;
    if (planDef && planDef.id !== 'custom') {
      if (planDef.max_branches) maxBranches = planDef.max_branches;
      if (licenseType === 'subscription' && planDef.days) {
        days = planDef.days;
      }
      if (licenseType === 'perpetual') {
        days = undefined;
      }
    }

    const payload: LicensePayload = {
      v: 1,
      type: licenseType,
      customer: input.customer.trim(),
      iat: Math.floor(Date.now() / 1000),
      ...(planDef && planDef.id !== 'custom' ? { plan: planDef.id } : {}),
      ...(input.tenant_code?.trim()
        ? { tenant_code: input.tenant_code.trim().toUpperCase() }
        : {}),
      ...(maxBranches ? { max_branches: maxBranches } : {}),
      ...(days
        ? { exp: Math.floor(Date.now() / 1000) + days * 86400 }
        : {}),
    };

    const licenseKey = signLicensePayload(payload, this.licenseSecret());

    return {
      license_key: licenseKey,
      payload: {
        type: payload.type,
        customer: payload.customer,
        tenant_locked: !!payload.tenant_code,
        ...(payload.plan ? { plan: payload.plan } : {}),
        ...(payload.tenant_code ? { tenant_code: payload.tenant_code } : {}),
        ...(payload.max_branches ? { max_branches: payload.max_branches } : {}),
        issued_at: new Date(payload.iat * 1000).toISOString(),
        ...(payload.exp
          ? { expires_at: new Date(payload.exp * 1000).toISOString() }
          : {}),
      },
    };
  }

  async activateLicenseKey(
    licenseKey: string,
  ): Promise<InstallationLicenseStatus> {
    if (!this.isOnPrem()) {
      throw new ForbiddenException(
        'Aktivasi lisensi hanya untuk mode on-prem',
      );
    }

    const payload = verifyLicenseToken(
      licenseKey.trim(),
      this.licenseSecret(),
    );
    if (!payload) {
      throw new ForbiddenException({
        message: 'Kode lisensi tidak valid',
        code: 'LICENSE_INVALID',
      });
    }

    const filePath = this.licenseFilePath();
    const dir = join(filePath, '..');
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
    writeFileSync(filePath, licenseKey.trim(), 'utf8');
    this.cachedPayload = payload;

    const tenantsUpdated = await this.syncTenantsFromLicensePayload(payload);
    const status = this.getInstallationStatus();
    return {
      ...status,
      tenants_updated: tenantsUpdated,
    };
  }
}
