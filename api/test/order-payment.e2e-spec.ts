import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { existsSync, mkdtempSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { LicenseService } from '../src/modules/license/license.service';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';

const API = '/api/v1';

async function login(
  app: INestApplication,
  email: string,
): Promise<string> {
  const res = await request(app.getHttpServer())
    .post(`${API}/auth/login`)
    .send({ email, password: 'password123', device_name: 'e2e' })
    .expect(201);
  return res.body.data.access_token as string;
}

describe('Order → payment (e2e)', () => {
  let app: INestApplication;
  let licenseService: LicenseService;
  let tmpDir: string;
  let createdOrderId: string;
  let e2eMedicineId: string;

  beforeAll(async () => {
    tmpDir = mkdtempSync(join(tmpdir(), 'apotikflow-order-e2e-'));
    process.env.LICENSE_FILE_PATH = join(tmpDir, 'license.key');

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
    const generated = licenseService.generateLicenseKey({
      customer: 'E2E Order Flow',
      type: 'perpetual',
      plan: 'standard',
      tenant_code: 'DEMO',
    });
    await licenseService.activateLicenseKey(generated.license_key);

    const prisma = app.get(PrismaService);
    const staffUser = await prisma.user.findUnique({
      where: { email: 'pelayan@apotikflow.com' },
      select: { branchId: true, tenantId: true },
    });
    const medicine = await prisma.medicine.findFirst({
      where: { barcode: '8991231230001', tenantId: staffUser?.tenantId ?? undefined },
      select: { id: true },
    });
    if (!staffUser?.branchId || !medicine) {
      throw new Error('Seed DEMO/staff/Paracetamol tidak lengkap — jalankan db:seed');
    }

    e2eMedicineId = medicine.id;
    const batch = await prisma.medicineBatch.findFirst({
      where: { medicineId: medicine.id },
      orderBy: { createdAt: 'asc' },
    });
    if (!batch) {
      throw new Error('Batch Paracetamol tidak ditemukan — jalankan db:seed');
    }

    await prisma.stock.upsert({
      where: {
        branchId_medicineId_batchId: {
          branchId: staffUser.branchId,
          medicineId: medicine.id,
          batchId: batch.id,
        },
      },
      update: { quantity: 100, reservedQuantity: 0 },
      create: {
        tenantId: staffUser.tenantId!,
        branchId: staffUser.branchId,
        medicineId: medicine.id,
        batchId: batch.id,
        quantity: 100,
        reservedQuantity: 0,
      },
    });
  });

  afterAll(async () => {
    await app?.close();
    if (tmpDir && existsSync(tmpDir)) {
      rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  it('staff membuat order, kasir membayar tunai', async () => {
    const staffToken = await login(app, 'pelayan@apotikflow.com');

    const orderRes = await request(app.getHttpServer())
      .post(`${API}/orders`)
      .set('Authorization', `Bearer ${staffToken}`)
      .send({
        customer_name: 'E2E Walk-in',
        items: [{ medicine_id: e2eMedicineId, quantity: 1 }],
      })
      .expect(201);

    createdOrderId = orderRes.body.data.id as string;
    expect(orderRes.body.data.status).toBe('WAITING_PAYMENT');

    const cashierToken = await login(app, 'kasir@apotikflow.com');
    const total = Number(orderRes.body.data.total);

    const payRes = await request(app.getHttpServer())
      .post(`${API}/payments`)
      .set('Authorization', `Bearer ${cashierToken}`)
      .send({
        order_id: createdOrderId,
        payment_method: 'CASH',
        amount: total,
        amount_received: total + 10000,
      })
      .expect(201);

    expect(payRes.body.data.status).toBe('PAID');

    const detail = await request(app.getHttpServer())
      .get(`${API}/orders/${createdOrderId}`)
      .set('Authorization', `Bearer ${cashierToken}`)
      .expect(200);

    expect(detail.body.data.status).toBe('PAID');
  });

  it('kasir tidak bisa akses platform admin', async () => {
    const cashierToken = await login(app, 'kasir@apotikflow.com');
    await request(app.getHttpServer())
      .get(`${API}/platform/tenants`)
      .set('Authorization', `Bearer ${cashierToken}`)
      .expect(403);
  });
});
