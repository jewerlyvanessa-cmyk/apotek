import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { existsSync, mkdtempSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { resolveTenantSubscriptionPlan } from '../src/modules/license/license-plans';
import {
  signLicensePayload,
  verifyLicenseToken,
} from '../src/modules/license/license-token.util';
import { LicenseService } from '../src/modules/license/license.service';
import { PlatformPrismaService } from '../src/infrastructure/prisma/platform-prisma.service';
import { PlatformService } from '../src/modules/platform/platform.service';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';

const API = '/api/v1';
const LICENSE_SECRET =
  process.env.LICENSE_SECRET ?? 'test-license-secret-e2e';

describe('License flows (e2e)', () => {
  let app: INestApplication;
  let licenseService: LicenseService;
  let platformService: PlatformService;
  let prisma: PrismaService;
  let platformPrisma: PlatformPrismaService;
  let licenseFilePath: string;
  let tmpDir: string;
  let demoTenantId: string;
  let demoSnapshot: {
    subscriptionPlan: string | null;
    subscriptionExpiredAt: Date | null;
    isActive: boolean;
  };

  beforeAll(async () => {
    tmpDir = mkdtempSync(join(tmpdir(), 'apotikflow-license-e2e-'));
    licenseFilePath = join(tmpDir, 'license.key');
    process.env.LICENSE_FILE_PATH = licenseFilePath;

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
        forbidNonWhitelisted: true,
      }),
    );
    await app.init();

    licenseService = app.get(LicenseService);
    platformService = app.get(PlatformService);
    prisma = app.get(PrismaService);
    platformPrisma = app.get(PlatformPrismaService);

    const demo = await platformPrisma.tenant.findUnique({
      where: { code: 'DEMO' },
      select: {
        id: true,
        subscriptionPlan: true,
        subscriptionExpiredAt: true,
        isActive: true,
      },
    });
    if (!demo) {
      throw new Error(
        'Tenant DEMO tidak ditemukan. Jalankan npm run db:seed terlebih dahulu.',
      );
    }
    demoTenantId = demo.id;
    demoSnapshot = {
      subscriptionPlan: demo.subscriptionPlan,
      subscriptionExpiredAt: demo.subscriptionExpiredAt,
      isActive: demo.isActive,
    };
  });

  afterAll(async () => {
    if (demoTenantId) {
      await platformPrisma.tenant.update({
        where: { id: demoTenantId },
        data: demoSnapshot,
      });
    }
    await app?.close();
    if (tmpDir && existsSync(tmpDir)) {
      rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  describe('token & katalog paket', () => {
    it('menandatangani dan memverifikasi token lisensi', () => {
      const payload = {
        v: 1 as const,
        type: 'perpetual' as const,
        customer: 'PT Test',
        plan: 'standard',
        iat: Math.floor(Date.now() / 1000),
      };
      const token = signLicensePayload(payload, LICENSE_SECRET);
      const verified = verifyLicenseToken(token, LICENSE_SECRET);
      expect(verified).toMatchObject({
        customer: 'PT Test',
        plan: 'standard',
        type: 'perpetual',
      });
    });

    it('resolveTenantSubscriptionPlan menyimpan id paket, bukan tipe lisensi', () => {
      expect(
        resolveTenantSubscriptionPlan({
          type: 'subscription',
          plan: 'starter',
        }),
      ).toBe('starter');
      expect(
        resolveTenantSubscriptionPlan({
          type: 'perpetual',
          plan: 'single',
        }),
      ).toBe('single');
      expect(
        resolveTenantSubscriptionPlan({ type: 'subscription' }),
      ).toBe('custom');
    });
  });

  describe('beli putus on-prem (perpetual)', () => {
    it('aktivasi perpetual menyinkronkan paket tanpa kedaluwarsa', async () => {
      const generated = licenseService.generateLicenseKey({
        customer: 'Apotik E2E Perpetual',
        type: 'perpetual',
        plan: 'standard',
        tenant_code: 'DEMO',
      });

      const status = await licenseService.activateLicenseKey(
        generated.license_key,
      );

      expect(status.valid).toBe(true);
      expect(status.type).toBe('perpetual');
      expect(status.plan).toBe('standard');
      expect(status.expires_at).toBeNull();

      const tenant = await platformPrisma.tenant.findUnique({
        where: { code: 'DEMO' },
        select: { subscriptionPlan: true, subscriptionExpiredAt: true },
      });
      expect(tenant?.subscriptionPlan).toBe('standard');
      expect(tenant?.subscriptionExpiredAt).toBeNull();
    });

    it('GET /license/status menampilkan instalasi valid', async () => {
      const generated = licenseService.generateLicenseKey({
        customer: 'Apotik E2E HTTP',
        type: 'perpetual',
        plan: 'single',
        tenant_code: 'DEMO',
      });
      await licenseService.activateLicenseKey(generated.license_key);

      const res = await request(app.getHttpServer())
        .get(`${API}/license/status`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.deployment_mode).toBe('on_prem');
      expect(res.body.data.installation.valid).toBe(true);
      expect(res.body.data.installation.type).toBe('perpetual');
    });
  });

  describe('berlangganan on-prem (subscription)', () => {
    it('aktivasi subscription menyinkronkan paket dan masa berlaku', async () => {
      const generated = licenseService.generateLicenseKey({
        customer: 'Apotik E2E Subscription',
        type: 'subscription',
        plan: 'professional',
        tenant_code: 'DEMO',
      });

      const status = await licenseService.activateLicenseKey(
        generated.license_key,
      );

      expect(status.valid).toBe(true);
      expect(status.type).toBe('subscription');
      expect(status.plan).toBe('professional');
      expect(status.expires_at).toBeTruthy();

      const tenant = await platformPrisma.tenant.findUnique({
        where: { code: 'DEMO' },
        select: { subscriptionPlan: true, subscriptionExpiredAt: true },
      });
      expect(tenant?.subscriptionPlan).toBe('professional');
      expect(tenant?.subscriptionExpiredAt).toBeInstanceOf(Date);
    });

    it('perpanjangan via kode lisensi baru memperbarui subscription_expired_at', async () => {
      const first = licenseService.generateLicenseKey({
        customer: 'Apotik E2E Renew',
        type: 'subscription',
        tenant_code: 'DEMO',
        days: 30,
        max_branches: 3,
      });
      await licenseService.activateLicenseKey(first.license_key);

      const before = await platformPrisma.tenant.findUnique({
        where: { code: 'DEMO' },
        select: { subscriptionExpiredAt: true },
      });

      const renewed = licenseService.generateLicenseKey({
        customer: 'Apotik E2E Renew',
        type: 'subscription',
        tenant_code: 'DEMO',
        days: 400,
        max_branches: 3,
      });
      await licenseService.activateLicenseKey(renewed.license_key);

      const after = await platformPrisma.tenant.findUnique({
        where: { code: 'DEMO' },
        select: { subscriptionExpiredAt: true },
      });

      expect(after?.subscriptionExpiredAt?.getTime()).toBeGreaterThan(
        before?.subscriptionExpiredAt?.getTime() ?? 0,
      );
    });
  });

  describe('enforce batas cabang (beli putus)', () => {
    it('menolak tambah cabang jika batas lisensi tercapai', async () => {
      const generated = licenseService.generateLicenseKey({
        customer: 'Apotik E2E Single',
        type: 'perpetual',
        plan: 'single',
        tenant_code: 'DEMO',
      });
      await licenseService.activateLicenseKey(generated.license_key);

      const branchCount = await prisma.branch.count({
        where: { tenantId: demoTenantId },
      });
      expect(branchCount).toBeGreaterThanOrEqual(1);

      await expect(
        licenseService.assertBranchLimit(demoTenantId),
      ).rejects.toMatchObject({
        response: { code: 'BRANCH_LIMIT_REACHED' },
      });
    });
  });

  describe('berlangganan SaaS (tenant subscription)', () => {
    afterEach(() => {
      jest.restoreAllMocks();
    });

    it('getPublicStatus mode SaaS tanpa lisensi instalasi', async () => {
      jest.spyOn(licenseService, 'getDeploymentMode').mockReturnValue('saas');

      const status = await licenseService.getPublicStatus();
      expect(status.deployment_mode).toBe('saas');
      expect(status.installation).toBeUndefined();
    });

    it('tenant aktif lolos assertTenantAccess di mode SaaS', async () => {
      await platformPrisma.tenant.update({
        where: { id: demoTenantId },
        data: {
          subscriptionPlan: 'starter',
          subscriptionExpiredAt: new Date(Date.now() + 30 * 86_400_000),
          isActive: true,
        },
      });
      jest.spyOn(licenseService, 'isOnPrem').mockReturnValue(false);

      await expect(
        licenseService.assertTenantAccess(demoTenantId),
      ).resolves.toBeUndefined();

      const sub = await licenseService.getTenantSubscriptionStatus(demoTenantId);
      expect(sub.valid).toBe(true);
    });

    it('tenant expired ditolak dengan SUBSCRIPTION_EXPIRED di mode SaaS', async () => {
      await platformPrisma.tenant.update({
        where: { id: demoTenantId },
        data: {
          subscriptionPlan: 'starter',
          subscriptionExpiredAt: new Date(Date.now() - 30 * 86_400_000),
          isActive: true,
        },
      });
      jest.spyOn(licenseService, 'isOnPrem').mockReturnValue(false);

      const sub = await licenseService.getTenantSubscriptionStatus(demoTenantId);
      expect(sub.valid).toBe(false);

      await expect(
        licenseService.assertTenantAccess(demoTenantId),
      ).rejects.toMatchObject({
        response: { code: 'SUBSCRIPTION_EXPIRED' },
      });
    });
  });

  describe('berlangganan SaaS (platform)', () => {
    let superAdminToken: string;

    beforeAll(async () => {
      const generated = licenseService.generateLicenseKey({
        customer: 'E2E Platform Admin',
        type: 'perpetual',
        plan: 'enterprise',
      });
      await licenseService.activateLicenseKey(generated.license_key);

      const login = await request(app.getHttpServer())
        .post(`${API}/auth/login`)
        .send({
          email: 'superadmin@apotikflow.com',
          password: 'password123',
        })
        .expect(201);

      superAdminToken = login.body.data.access_token;
    });

    it('GET /platform/licenses/plans mengembalikan katalog perpetual & subscription', async () => {
      const res = await request(app.getHttpServer())
        .get(`${API}/platform/licenses/plans`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.perpetual_plans.length).toBeGreaterThan(0);
      expect(res.body.data.subscription_plans.length).toBeGreaterThan(0);
    });

    it('perpanjang langganan tenant via platform service', async () => {
      const updated = await platformService.extendTenantSubscription(
        demoTenantId,
        { plan: 'enterprise', extend_days: 365 },
      );

      expect(updated.subscriptionPlan).toBe('enterprise');
      expect(updated.subscriptionExpiredAt).toBeInstanceOf(Date);
      expect(updated.subscriptionExpiredAt!.getTime()).toBeGreaterThan(
        Date.now(),
      );

      const sub = await licenseService.getTenantSubscriptionStatus(demoTenantId);
      expect(sub.valid).toBe(true);
      expect(sub.plan).toBe('enterprise');
    });

    it('POST /platform/licenses/generate menyinkronkan tenant terkait', async () => {
      const res = await request(app.getHttpServer())
        .post(`${API}/platform/licenses/generate`)
        .set('Authorization', `Bearer ${superAdminToken}`)
        .send({
          customer: 'Apotik E2E Generate',
          type: 'subscription',
          plan: 'starter',
          tenant_id: demoTenantId,
        })
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.data.license_key).toMatch(/^aflow_/);

      const tenant = await platformPrisma.tenant.findUnique({
        where: { id: demoTenantId },
        select: { subscriptionPlan: true, subscriptionExpiredAt: true },
      });
      expect(tenant?.subscriptionPlan).toBe('starter');
      expect(tenant?.subscriptionExpiredAt).toBeInstanceOf(Date);
    });
  });
});
