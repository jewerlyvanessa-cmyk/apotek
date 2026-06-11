import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

const userSafeSelect = {
  id: true,
  tenantId: true,
  branchId: true,
  fullName: true,
  email: true,
  phone: true,
  role: true,
  roles: true,
  isActive: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.UserSelect;

@Injectable()
export class PlatformBackupService {
  constructor(private prisma: PrismaService) {}

  private async fetchInBatches<T>(
    fetchPage: (skip: number, take: number) => Promise<T[]>,
    batchSize = 500,
  ): Promise<T[]> {
    const all: T[] = [];
    let skip = 0;
    while (true) {
      const batch = await fetchPage(skip, batchSize);
      all.push(...batch);
      if (batch.length < batchSize) break;
      skip += batchSize;
    }
    return all;
  }

  private toJsonSafe<T>(data: T): T {
    return JSON.parse(
      JSON.stringify(data, (_key, value) => {
        if (typeof value === 'bigint') return value.toString();
        if (value instanceof Prisma.Decimal) return value.toString();
        return value;
      }),
    );
  }

  async exportTenantBackup(tenantId: string) {
    const tenant = await this.prisma.tenant.findUnique({ where: { id: tenantId } });
    if (!tenant) throw new NotFoundException('Tenant not found');

    const branchIds = (
      await this.prisma.branch.findMany({
        where: { tenantId },
        select: { id: true },
      })
    ).map((b) => b.id);

    const [
      branches,
      users,
      suppliers,
      customers,
      categories,
      medicines,
      batches,
      stocks,
      stockMovements,
      orders,
      opnames,
      transfers,
      auditLogs,
    ] = await Promise.all([
      this.prisma.branch.findMany({ where: { tenantId } }),
      this.prisma.user.findMany({
        where: { tenantId },
        select: userSafeSelect,
      }),
      this.prisma.supplier.findMany({ where: { tenantId } }),
      this.prisma.customer.findMany({ where: { tenantId } }),
      this.prisma.medicineCategory.findMany({ where: { tenantId } }),
      this.prisma.medicine.findMany({ where: { tenantId } }),
      this.prisma.medicineBatch.findMany({
        where: { medicine: { tenantId } },
      }),
      this.prisma.stock.findMany({ where: { tenantId } }),
      this.fetchInBatches((skip, take) =>
        this.prisma.stockMovement.findMany({
          where: { tenantId },
          orderBy: { createdAt: 'desc' },
          skip,
          take,
        }),
      ),
      this.fetchInBatches((skip, take) =>
        this.prisma.order.findMany({
          where: { tenantId },
          include: {
            items: true,
            payments: true,
          },
          orderBy: { createdAt: 'desc' },
          skip,
          take,
        }),
      ),
      this.prisma.stockOpname.findMany({
        where: { tenantId },
        include: { items: true },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.transferStock.findMany({
        where: { tenantId },
        include: { items: true },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.auditLog.findMany({
        where: { tenantId },
        orderBy: { createdAt: 'desc' },
        take: 5000,
      }),
    ]);

    return this.toJsonSafe({
      backup_version: '1.0',
      scope: 'tenant',
      exported_at: new Date().toISOString(),
      tenant,
      summary: {
        branches: branches.length,
        users: users.length,
        medicines: medicines.length,
        orders: orders.length,
        stocks: stocks.length,
        branch_ids: branchIds,
      },
      data: {
        branches,
        users,
        suppliers,
        customers,
        medicine_categories: categories,
        medicines,
        medicine_batches: batches,
        stocks,
        stock_movements: stockMovements,
        orders,
        stock_opnames: opnames,
        transfer_stocks: transfers,
        audit_logs: auditLogs,
      },
    });
  }

  async exportBranchBackup(tenantId: string, branchId: string) {
    const branch = await this.prisma.branch.findFirst({
      where: { id: branchId, tenantId },
    });
    if (!branch) throw new NotFoundException('Branch not found');

    const tenant = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: {
        id: true,
        name: true,
        code: true,
        phone: true,
        email: true,
        isActive: true,
      },
    });
    if (!tenant) throw new NotFoundException('Tenant not found');

    const [
      stocks,
      stockMovements,
      orders,
      opnames,
      transfers,
    ] = await Promise.all([
      this.prisma.stock.findMany({ where: { branchId } }),
      this.prisma.stockMovement.findMany({
        where: { branchId },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.order.findMany({
        where: { branchId },
        include: { items: true, payments: true },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.stockOpname.findMany({
        where: { branchId },
        include: { items: true },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.transferStock.findMany({
        where: {
          tenantId,
          OR: [{ fromBranchId: branchId }, { toBranchId: branchId }],
        },
        include: { items: true },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    const medicineIds = new Set<string>();
    const customerIds = new Set<string>();
    const userIds = new Set<string>();

    for (const s of stocks) medicineIds.add(s.medicineId);
    for (const m of stockMovements) {
      medicineIds.add(m.medicineId);
      if (m.createdById) userIds.add(m.createdById);
    }
    for (const o of orders) {
      if (o.customerId) customerIds.add(o.customerId);
      if (o.servedById) userIds.add(o.servedById);
      if (o.cashierId) userIds.add(o.cashierId);
      for (const item of o.items) medicineIds.add(item.medicineId);
      for (const p of o.payments) if (p.paidById) userIds.add(p.paidById);
    }
    for (const op of opnames) {
      if (op.createdById) userIds.add(op.createdById);
      if (op.approvedById) userIds.add(op.approvedById);
      for (const item of op.items) medicineIds.add(item.medicineId);
    }
    for (const t of transfers) {
      if (t.requestedById) userIds.add(t.requestedById);
      if (t.approvedById) userIds.add(t.approvedById);
      for (const item of t.items) medicineIds.add(item.medicineId);
    }

    const medIdList = [...medicineIds];
    const [medicines, batches, customers, users] = await Promise.all([
      medIdList.length > 0
        ? this.prisma.medicine.findMany({
            where: { id: { in: medIdList }, tenantId },
          })
        : [],
      medIdList.length > 0
        ? this.prisma.medicineBatch.findMany({
            where: { medicineId: { in: medIdList } },
          })
        : [],
      customerIds.size > 0
        ? this.prisma.customer.findMany({
            where: { id: { in: [...customerIds] }, tenantId },
          })
        : [],
      userIds.size > 0
        ? this.prisma.user.findMany({
            where: { id: { in: [...userIds] } },
            select: userSafeSelect,
          })
        : [],
    ]);

    const categoryIds = [
      ...new Set(
        medicines
          .map((m) => m.categoryId)
          .filter((id): id is string => id != null),
      ),
    ];
    const supplierIds = [
      ...new Set(
        medicines
          .map((m) => m.supplierId)
          .filter((id): id is string => id != null),
      ),
    ];

    const [categories, suppliers] = await Promise.all([
      categoryIds.length > 0
        ? this.prisma.medicineCategory.findMany({
            where: { id: { in: categoryIds } },
          })
        : [],
      supplierIds.length > 0
        ? this.prisma.supplier.findMany({
            where: { id: { in: supplierIds } },
          })
        : [],
    ]);

    return this.toJsonSafe({
      backup_version: '1.0',
      scope: 'branch',
      exported_at: new Date().toISOString(),
      tenant,
      branch,
      summary: {
        orders: orders.length,
        stocks: stocks.length,
        stock_movements: stockMovements.length,
        transfer_stocks: transfers.length,
      },
      data: {
        reference: {
          users,
          customers,
          suppliers,
          medicine_categories: categories,
          medicines,
          medicine_batches: batches,
        },
        stocks,
        stock_movements: stockMovements,
        orders,
        stock_opnames: opnames,
        transfer_stocks: transfers,
      },
    });
  }
}
