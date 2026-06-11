import { BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

export async function getCentralWarehouseBranch(
  prisma: PrismaService,
  tenantId: string,
) {
  const branch = await prisma.branch.findFirst({
    where: { tenantId, isCentralWarehouse: true, isActive: true },
  });
  if (!branch) {
    throw new NotFoundException(
      'Gudang pusat belum dikonfigurasi. Tandai satu cabang sebagai gudang pusat tenant.',
    );
  }
  return branch;
}

export async function setCentralWarehouseFlag(
  prisma: PrismaService,
  tenantId: string,
  branchId: string,
  isCentral: boolean,
) {
  const branch = await prisma.branch.findFirst({
    where: { id: branchId, tenantId },
  });
  if (!branch) throw new NotFoundException('Branch not found');

  if (isCentral) {
    await prisma.branch.updateMany({
      where: { tenantId, isCentralWarehouse: true },
      data: { isCentralWarehouse: false },
    });
    return prisma.branch.update({
      where: { id: branchId },
      data: { isCentralWarehouse: true },
    });
  }

  if (branch.isCentralWarehouse) {
    return prisma.branch.update({
      where: { id: branchId },
      data: { isCentralWarehouse: false },
    });
  }
  return branch;
}

export function assertNotCentralWarehouse(branch: { isCentralWarehouse: boolean }) {
  if (branch.isCentralWarehouse) {
    throw new BadRequestException(
      'Cabang gudang pusat tidak dapat menjadi tujuan distribusi penjualan',
    );
  }
}
