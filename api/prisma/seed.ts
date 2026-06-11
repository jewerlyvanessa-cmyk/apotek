import { BranchStockMode, PrismaClient, UserRole } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import {
  applyBranchStockModeChange,
  ensureBranchStockLocations,
  resolveInboundLocationId,
} from '../src/common/utils/stock-location.util';
import { ensureDefaultProductTypes } from '../src/common/utils/product-type-defaults.util';

const prisma = new PrismaClient();

async function backfillStockLocationIds() {
  const rows = await prisma.$queryRaw<Array<{ id: string; branch_id: string }>>`
    SELECT id, branch_id::text AS branch_id FROM stocks WHERE location_id IS NULL
  `;
  for (const row of rows) {
    const branch = await prisma.branch.findUnique({ where: { id: row.branch_id } });
    if (!branch) continue;
    const locations = await ensureBranchStockLocations(prisma, branch);
    const inbound = await resolveInboundLocationId(prisma, branch);
    await prisma.stock.update({
      where: { id: row.id },
      data: { locationId: inbound },
    });
    void locations;
  }
}

async function main() {
  const tenant = await prisma.tenant.upsert({
    where: { code: 'DEMO' },
    update: {},
    create: {
      name: 'Apotik Demo Sehat',
      code: 'DEMO',
      email: 'demo@apotikflow.com',
      phone: '081234567890',
      subscriptionPlan: 'trial',
    },
  });

  await ensureDefaultProductTypes(prisma, tenant.id);

  let branch = await prisma.branch.findFirst({
    where: { tenantId: tenant.id, code: 'PUSAT' },
  });
  if (!branch) {
    branch = await prisma.branch.create({
      data: {
        tenantId: tenant.id,
        name: 'Gudang Pusat',
        code: 'PUSAT',
        address: 'Jl. Kesehatan No. 1',
        isCentralWarehouse: true,
      },
    });
  } else {
    branch = await prisma.branch.update({
      where: { id: branch.id },
      data: { isCentralWarehouse: true, name: 'Gudang Pusat' },
    });
  }
  await ensureBranchStockLocations(prisma, branch);

  let branchCabang = await prisma.branch.findFirst({
    where: { tenantId: tenant.id, code: 'CAB01' },
  });
  if (!branchCabang) {
    branchCabang = await prisma.branch.create({
      data: {
        tenantId: tenant.id,
        name: 'Cabang Utama',
        code: 'CAB01',
        address: 'Jl. Raya No. 10',
        stockMode: BranchStockMode.WAREHOUSE_ETALASE,
      },
    });
  }
  if (branchCabang.stockMode !== BranchStockMode.WAREHOUSE_ETALASE) {
    await applyBranchStockModeChange(
      prisma,
      branchCabang.id,
      BranchStockMode.WAREHOUSE_ETALASE,
      { moveExistingTo: 'BACK' },
    );
    branchCabang = (await prisma.branch.findUnique({
      where: { id: branchCabang.id },
    }))!;
  } else {
    await ensureBranchStockLocations(prisma, branchCabang);
  }

  const passwordHash = await bcrypt.hash('password123', 10);

  await prisma.user.upsert({
    where: { email: 'superadmin@apotikflow.com' },
    update: {
      role: UserRole.SUPER_ADMIN,
      roles: [UserRole.SUPER_ADMIN],
      tenantId: null,
      branchId: null,
      mustChangePassword: true,
    },
    create: {
      tenantId: null,
      branchId: null,
      fullName: 'Super Admin',
      email: 'superadmin@apotikflow.com',
      passwordHash,
      role: UserRole.SUPER_ADMIN,
      roles: [UserRole.SUPER_ADMIN],
      mustChangePassword: true,
    },
  });

  const users = [
    {
      email: 'owner@apotikflow.com',
      fullName: 'Owner Demo',
      role: UserRole.OWNER,
      branchId: null as string | null,
    },
    {
      email: 'kasir@apotikflow.com',
      fullName: 'Kasir Demo',
      role: UserRole.CASHIER,
      roles: [UserRole.CASHIER, UserRole.STAFF],
      branchId: branch.id,
    },
    {
      email: 'pelayan@apotikflow.com',
      fullName: 'Asisten Demo',
      role: UserRole.STAFF,
      branchId: branch.id,
    },
    {
      email: 'gudang@apotikflow.com',
      fullName: 'Gudang Demo',
      role: UserRole.WAREHOUSE,
      branchId: branch.id,
    },
    {
      email: 'manager@apotikflow.com',
      fullName: 'Kepala Cabang',
      role: UserRole.MANAGER,
      branchId: branchCabang!.id,
    },
    {
      email: 'pusat@apotikflow.com',
      fullName: 'Manajer Pusat',
      role: UserRole.MANAGER,
      branchId: null as string | null,
    },
    {
      email: 'apoteker@apotikflow.com',
      fullName: 'Apoteker Demo',
      role: UserRole.PHARMACIST,
      branchId: branchCabang!.id,
    },
  ];

  for (const u of users) {
    const roles = 'roles' in u && u.roles ? u.roles : [u.role];
    const globalRoles = u.branchId
      ? []
      : roles.filter((r) => r === UserRole.OWNER || r === UserRole.MANAGER);
    const forcePasswordChange = u.email === 'owner@apotikflow.com';
    const saved = await prisma.user.upsert({
      where: { email: u.email },
      update: {
        role: u.role,
        roles,
        globalRoles,
        branchId: u.branchId,
        ...(forcePasswordChange ? { mustChangePassword: true } : {}),
      },
      create: {
        tenantId: tenant.id,
        branchId: u.branchId,
        fullName: u.fullName,
        email: u.email,
        passwordHash,
        role: u.role,
        roles,
        globalRoles,
        mustChangePassword: forcePasswordChange,
      },
    });
    if (u.branchId) {
      await prisma.userBranch.upsert({
        where: {
          userId_branchId: { userId: saved.id, branchId: u.branchId },
        },
        update: { roles },
        create: { userId: saved.id, branchId: u.branchId, roles },
      });
    }
  }

  const categories = [
    'Analgesik',
    'Antibiotik',
    'Vitamin',
    'Antasida',
    'Alat Kesehatan',
    'Minuman',
  ];
  const categoryMap: Record<string, string> = {};
  for (const name of categories) {
    let cat = await prisma.medicineCategory.findFirst({
      where: { tenantId: tenant.id, name },
    });
    if (!cat) {
      cat = await prisma.medicineCategory.create({
        data: { tenantId: tenant.id, name },
      });
    }
    categoryMap[name] = cat.id;
  }

  let supplier = await prisma.supplier.findFirst({
    where: { tenantId: tenant.id, name: 'PT Farmasi Nusantara' },
  });
  if (!supplier) {
    supplier = await prisma.supplier.create({
      data: {
        tenantId: tenant.id,
        name: 'PT Farmasi Nusantara',
        phone: '021-1234567',
        address: 'Jakarta',
      },
    });
  }

  const demoCustomers = [
    { name: 'Budi Santoso', phone: '0811111111' },
    { name: 'Siti Aminah', phone: '0822222222' },
    { name: 'Walk-in Umum', phone: null as string | null },
  ];
  for (const c of demoCustomers) {
    const existing = await prisma.customer.findFirst({
      where: {
        tenantId: tenant.id,
        name: { equals: c.name, mode: 'insensitive' },
      },
    });
    if (!existing) {
      await prisma.customer.create({
        data: {
          tenantId: tenant.id,
          name: c.name,
          phone: c.phone,
        },
      });
    }
  }

  const medicines = [
    {
      name: 'Paracetamol 500mg',
      barcode: '8991231230001',
      sku: 'PCM-500',
      unit: 'STRIP',
      buyPrice: 3000,
      sellPrice: 5000,
      minStock: 10,
      category: 'Analgesik',
      batch: 'BATCH-001',
      stockQty: 100,
      productType: 'DRUG' as const,
    },
    {
      name: 'Amoxicillin 500mg',
      barcode: '8991231230002',
      sku: 'AMX-500',
      unit: 'STRIP',
      buyPrice: 15000,
      sellPrice: 22000,
      minStock: 5,
      category: 'Antibiotik',
      batch: 'BATCH-002',
      stockQty: 50,
      productType: 'DRUG' as const,
      requiresPrescription: true,
    },
    {
      name: 'Vitamin C 1000mg',
      barcode: '8991231230003',
      sku: 'VITC-1000',
      unit: 'BOTOL',
      buyPrice: 25000,
      sellPrice: 35000,
      minStock: 8,
      category: 'Vitamin',
      batch: 'BATCH-003',
      stockQty: 30,
      productType: 'HEALTH' as const,
    },
    {
      name: 'Antasida Tablet',
      barcode: '8991231230004',
      sku: 'ANT-001',
      unit: 'STRIP',
      buyPrice: 8000,
      sellPrice: 12000,
      minStock: 10,
      category: 'Antasida',
      batch: 'BATCH-004',
      stockQty: 75,
      productType: 'DRUG' as const,
    },
    {
      name: 'Masker Medis (50 pcs)',
      barcode: '8991231230005',
      sku: 'MSK-50',
      unit: 'BOX',
      buyPrice: 12000,
      sellPrice: 18000,
      minStock: 5,
      category: 'Alat Kesehatan',
      batch: 'BATCH-005',
      stockQty: 40,
      productType: 'HEALTH' as const,
    },
    {
      name: 'Air Mineral 600ml',
      barcode: '8991231230006',
      sku: 'H2O-600',
      unit: 'BOTOL',
      buyPrice: 2000,
      sellPrice: 4000,
      minStock: 20,
      category: 'Minuman',
      batch: 'BATCH-006',
      stockQty: 120,
      productType: 'COMMERCIAL' as const,
    },
  ];

  for (const m of medicines) {
    const existing = await prisma.medicine.findFirst({
      where: { tenantId: tenant.id, barcode: m.barcode },
    });
    if (existing) continue;

    const typeCode = m.productType ?? 'DRUG';
    const productType = await prisma.productTypeDefinition.findFirst({
      where: { tenantId: tenant.id, code: typeCode },
    });
    if (!productType) {
      throw new Error(`Tipe produk ${typeCode} tidak ditemukan untuk tenant demo`);
    }

    const med = await prisma.medicine.create({
      data: {
        tenantId: tenant.id,
        categoryId: categoryMap[m.category],
        supplierId: supplier.id,
        name: m.name,
        barcode: m.barcode,
        sku: m.sku,
        unit: m.unit,
        buyPrice: m.buyPrice,
        sellPrice: m.sellPrice,
        minStock: m.minStock,
        productTypeId: productType.id,
        requiresPrescription: m.requiresPrescription ?? false,
      },
    });

    const batch = await prisma.medicineBatch.create({
      data: {
        medicineId: med.id,
        batchNumber: m.batch,
        expiredDate: new Date('2027-12-31'),
        buyPrice: m.buyPrice,
        sellPrice: m.sellPrice,
      },
    });

    const inboundId = await resolveInboundLocationId(prisma, branch);
    await prisma.stock.upsert({
      where: {
        branchId_locationId_medicineId_batchId: {
          branchId: branch.id,
          locationId: inboundId,
          medicineId: med.id,
          batchId: batch.id,
        },
      },
      create: {
        tenantId: tenant.id,
        branchId: branch.id,
        locationId: inboundId,
        medicineId: med.id,
        batchId: batch.id,
        quantity: m.stockQty,
        reservedQuantity: 0,
      },
      update: { quantity: m.stockQty },
    });
  }

  console.log('Seed completed.');
  console.log('Super Admin: superadmin@apotikflow.com / password123');
  console.log('Owner: owner@apotikflow.com / password123');
  console.log(`Medicines seeded: ${medicines.length}`);
  await backfillStockLocationIds();
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
