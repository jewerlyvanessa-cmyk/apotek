import {
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { BranchStockMode, Prisma, PrismaClient } from '@prisma/client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

type StockDb = PrismaService | PrismaClient | Prisma.TransactionClient;

export const STOCK_LOCATION_CODE = {
  MAIN: 'MAIN',
  BACK: 'BACK',
  FRONT: 'FRONT',
} as const;

export async function ensureBranchStockLocations(
  db: StockDb,
  branch: { id: string; stockMode: BranchStockMode; isCentralWarehouse: boolean },
) {
  const existing = await db.stockLocation.findMany({
    where: { branchId: branch.id },
    orderBy: { sortOrder: 'asc' },
  });
  if (existing.length > 0) return existing;

  if (
    branch.isCentralWarehouse ||
    branch.stockMode === BranchStockMode.SIMPLE
  ) {
    return [
      await db.stockLocation.create({
        data: {
          branchId: branch.id,
          code: STOCK_LOCATION_CODE.MAIN,
          name: 'Stok Utama',
          isSellable: true,
          sortOrder: 0,
        },
      }),
    ];
  }

  return Promise.all([
    db.stockLocation.create({
      data: {
        branchId: branch.id,
        code: STOCK_LOCATION_CODE.BACK,
        name: 'Gudang Cabang',
        isSellable: false,
        sortOrder: 0,
      },
    }),
    db.stockLocation.create({
      data: {
        branchId: branch.id,
        code: STOCK_LOCATION_CODE.FRONT,
        name: 'Etalase',
        isSellable: true,
        sortOrder: 1,
      },
    }),
  ]);
}

export async function getLocationByCode(
  db: StockDb,
  branchId: string,
  code: string,
) {
  const loc = await db.stockLocation.findFirst({
    where: { branchId, code },
  });
  if (!loc) throw new NotFoundException(`Lokasi stok ${code} tidak ditemukan`);
  return loc;
}

/** Lokasi default saat barang masuk (terima stok, distribusi, pengadaan). */
export async function resolveInboundLocationId(
  db: StockDb,
  branch: { id: string; stockMode: BranchStockMode; isCentralWarehouse: boolean },
): Promise<string> {
  const locations = await ensureBranchStockLocations(db, branch);
  if (branch.isCentralWarehouse || branch.stockMode === BranchStockMode.SIMPLE) {
    return (
      locations.find((l) => l.code === STOCK_LOCATION_CODE.MAIN)?.id ??
      locations[0].id
    );
  }
  return (
    locations.find((l) => l.code === STOCK_LOCATION_CODE.BACK)?.id ??
    locations[0].id
  );
}

export async function getSellableLocationIds(
  db: StockDb,
  branch: { id: string; stockMode: BranchStockMode; isCentralWarehouse: boolean },
): Promise<string[]> {
  const locations = await ensureBranchStockLocations(db, branch);
  return locations.filter((l) => l.isSellable).map((l) => l.id);
}

export async function loadBranchForStock(
  db: StockDb,
  tenantId: string,
  branchId: string,
) {
  const branch = await db.branch.findFirst({
    where: { id: branchId, tenantId, isActive: true },
  });
  if (!branch) throw new NotFoundException('Cabang tidak ditemukan');
  return branch;
}

export async function mergeStockIntoLocation(
  tx: Prisma.TransactionClient,
  params: {
    tenantId: string;
    branchId: string;
    targetLocationId: string;
    medicineId: string;
    batchId: string | null;
  },
) {
  const { tenantId, branchId, targetLocationId, medicineId, batchId } = params;
  const existing = await tx.stock.findFirst({
    where: {
      tenantId,
      branchId,
      locationId: targetLocationId,
      medicineId,
      batchId,
    },
  });
  if (!existing) return;

  const others = await tx.stock.findMany({
    where: {
      tenantId,
      branchId,
      medicineId,
      batchId,
      NOT: { id: existing.id },
    },
  });

  let addQty = 0;
  let addReserved = 0;
  for (const row of others) {
    addQty += row.quantity;
    addReserved += row.reservedQuantity;
    await tx.stock.delete({ where: { id: row.id } });
  }

  if (addQty > 0 || addReserved > 0) {
    await tx.stock.update({
      where: { id: existing.id },
      data: {
        quantity: { increment: addQty },
        reservedQuantity: { increment: addReserved },
      },
    });
  }
}

/** Konversi mode stok cabang + migrasi saldo antar lokasi. */
export async function applyBranchStockModeChange(
  prisma: PrismaService | PrismaClient,
  branchId: string,
  newMode: BranchStockMode,
  options?: { moveExistingTo?: 'BACK' | 'FRONT' },
) {
  const branch = await prisma.branch.findUnique({ where: { id: branchId } });
  if (!branch) throw new NotFoundException('Cabang tidak ditemukan');
  if (branch.isCentralWarehouse && newMode === BranchStockMode.WAREHOUSE_ETALASE) {
    throw new BadRequestException(
      'Gudang pusat tidak mendukung mode gudang + etalase',
    );
  }
  if (branch.stockMode === newMode) return branch;

  await prisma.$transaction(async (tx: Prisma.TransactionClient) => {
    await ensureBranchStockLocations(tx, branch);

    if (newMode === BranchStockMode.WAREHOUSE_ETALASE) {
      const back = await getLocationByCode(tx, branchId, STOCK_LOCATION_CODE.BACK);
      const front = await getLocationByCode(tx, branchId, STOCK_LOCATION_CODE.FRONT);
      const main = await tx.stockLocation.findFirst({
        where: { branchId, code: STOCK_LOCATION_CODE.MAIN },
      });

      if (main) {
        const mainStocks = await tx.stock.findMany({
          where: { branchId, locationId: main.id },
        });
        const target =
          options?.moveExistingTo === 'FRONT' ? front.id : back.id;
        for (const row of mainStocks) {
          const dest = await tx.stock.findFirst({
            where: {
              branchId,
              locationId: target,
              medicineId: row.medicineId,
              batchId: row.batchId,
            },
          });
          if (dest) {
            await tx.stock.update({
              where: { id: dest.id },
              data: {
                quantity: { increment: row.quantity },
                reservedQuantity: { increment: row.reservedQuantity },
              },
            });
            await tx.stock.delete({ where: { id: row.id } });
          } else {
            await tx.stock.update({
              where: { id: row.id },
              data: { locationId: target },
            });
          }
        }
        await tx.stockLocation.delete({ where: { id: main.id } });
      }
    } else {
      const main = await getLocationByCode(tx, branchId, STOCK_LOCATION_CODE.MAIN);
      const others = await tx.stockLocation.findMany({
        where: {
          branchId,
          code: { in: [STOCK_LOCATION_CODE.BACK, STOCK_LOCATION_CODE.FRONT] },
        },
      });
      for (const loc of others) {
        const rows = await tx.stock.findMany({
          where: { branchId, locationId: loc.id },
        });
        for (const row of rows) {
          const dest = await tx.stock.findFirst({
            where: {
              branchId,
              locationId: main.id,
              medicineId: row.medicineId,
              batchId: row.batchId,
            },
          });
          if (dest) {
            await tx.stock.update({
              where: { id: dest.id },
              data: {
                quantity: { increment: row.quantity },
                reservedQuantity: { increment: row.reservedQuantity },
              },
            });
            await tx.stock.delete({ where: { id: row.id } });
          } else {
            await tx.stock.update({
              where: { id: row.id },
              data: { locationId: main.id },
            });
          }
        }
        await tx.stockLocation.delete({ where: { id: loc.id } });
      }
      await ensureBranchStockLocations(tx, {
        ...branch,
        stockMode: BranchStockMode.SIMPLE,
      });
    }

    await tx.branch.update({
      where: { id: branchId },
      data: { stockMode: newMode },
    });
  });

  return prisma.branch.findUnique({ where: { id: branchId } });
}

export async function findOrCreateStockRow(
  tx: Prisma.TransactionClient,
  params: {
    tenantId: string;
    branchId: string;
    locationId: string;
    medicineId: string;
    batchId: string | null;
    rackPosition?: string | null;
    initialQuantity?: number;
  },
) {
  const existing = await tx.stock.findFirst({
    where: {
      tenantId: params.tenantId,
      branchId: params.branchId,
      locationId: params.locationId,
      medicineId: params.medicineId,
      batchId: params.batchId,
    },
    include: { medicine: { select: { name: true, minStock: true } } },
  });
  if (existing) return existing;

  return tx.stock.create({
    data: {
      tenantId: params.tenantId,
      branchId: params.branchId,
      locationId: params.locationId,
      medicineId: params.medicineId,
      batchId: params.batchId,
      quantity: params.initialQuantity ?? 0,
      reservedQuantity: 0,
      rackPosition: params.rackPosition?.trim() || null,
    },
    include: { medicine: { select: { name: true, minStock: true } } },
  });
}
