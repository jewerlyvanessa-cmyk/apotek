import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { requireTenantId } from '../../common/utils/require-tenant-id';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { JwtPayloadUser } from '../../common/decorators/current-user.decorator';
import { RealtimeService } from '../realtime/realtime.service';
import {
  assertNotCentralWarehouse,
  getCentralWarehouseBranch,
} from '../../common/utils/central-warehouse';
import {
  findOrCreateStockRow,
  loadBranchForStock,
  resolveInboundLocationId,
} from '../../common/utils/stock-location.util';
import { CreateDistributionDto } from './dto/create-distribution.dto';
import { CreateTransferStockDto } from './dto/create-transfer-stock.dto';
import { TransferQueryDto } from './dto/transfer-query.dto';

@Injectable()
export class TransferStocksService {
  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeService,
  ) {}

  private available(qty: number, reserved: number) {
    return Math.max(0, qty - reserved);
  }

  private async generateNumber(tenantId: string) {
    const today = new Date();
    const prefix = `TRF-${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;
    const count = await this.prisma.transferStock.count({
      where: { tenantId, transferNumber: { startsWith: prefix } },
    });
    return `${prefix}-${String(count + 1).padStart(3, '0')}`;
  }

  async create(user: JwtPayloadUser, dto: CreateTransferStockDto) {
    if (dto.from_branch_id === dto.to_branch_id) {
      throw new BadRequestException('from_branch_id and to_branch_id must differ');
    }

    const transferNumber = await this.generateNumber(requireTenantId(user));
    return this.prisma.transferStock.create({
      data: {
        tenantId: requireTenantId(user),
        fromBranchId: dto.from_branch_id,
        toBranchId: dto.to_branch_id,
        transferNumber,
        transferType: 'TRANSFER',
        status: 'REQUESTED',
        requestedById: user.sub,
        items: {
          create: dto.items.map((i) => ({
            medicineId: i.medicine_id,
            batchId: i.batch_id,
            quantity: i.quantity,
          })),
        },
      },
      include: {
        items: {
          include: { medicine: { select: { id: true, name: true, unit: true } } },
        },
      },
    });
  }

  async findOne(user: JwtPayloadUser, id: string) {
    const transfer = await this.prisma.transferStock.findFirst({
      where: { id, tenantId: requireTenantId(user) },
      include: {
        items: {
          include: { medicine: { select: { id: true, name: true, unit: true } } },
        },
        fromBranch: { select: { id: true, name: true } },
        toBranch: { select: { id: true, name: true } },
      },
    });
    if (!transfer) throw new NotFoundException('Transfer not found');
    return transfer;
  }

  async findAll(user: JwtPayloadUser, query: TransferQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where: Prisma.TransferStockWhereInput = {
      tenantId: requireTenantId(user),
      ...(query.status ? { status: query.status } : {}),
      ...(query.transfer_type ? { transferType: query.transfer_type } : {}),
      ...(query.from_branch_id ? { fromBranchId: query.from_branch_id } : {}),
      ...(query.to_branch_id ? { toBranchId: query.to_branch_id } : {}),
      ...(query.search
        ? {
            transferNumber: { contains: query.search, mode: 'insensitive' },
          }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.transferStock.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          fromBranch: { select: { id: true, name: true } },
          toBranch: { select: { id: true, name: true } },
          _count: { select: { items: true } },
        },
      }),
      this.prisma.transferStock.count({ where }),
    ]);

    return {
      items,
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async submit(user: JwtPayloadUser, id: string) {
    const transfer = await this.findOne(user, id);
    if (transfer.status !== 'REQUESTED') {
      throw new BadRequestException('Only REQUESTED transfer can be submitted');
    }

    await this.prisma.$transaction(async (tx) => {
      for (const item of transfer.items) {
        let remaining = item.quantity;

        const fromStocks = await tx.stock.findMany({
          where: {
            tenantId: requireTenantId(user),
            branchId: transfer.fromBranchId,
            medicineId: item.medicineId,
            ...(item.batchId ? { batchId: item.batchId } : {}),
          },
          orderBy: { updatedAt: 'asc' },
          include: { medicine: { select: { name: true, minStock: true } } },
        });

        if (!fromStocks.length) throw new ConflictException('STOCK_NOT_ENOUGH');

        // lock all relevant rows
        for (const s of fromStocks) {
          await tx.$queryRaw`
            SELECT id FROM stocks WHERE id = ${s.id}::uuid FOR UPDATE
          `;
        }

        // decrement across rows (respect reserved)
        for (const s of fromStocks) {
          if (remaining <= 0) break;
          const fresh = await tx.stock.findUnique({
            where: { id: s.id },
            include: { medicine: { select: { name: true, minStock: true } } },
          });
          if (!fresh) continue;

          const avail = this.available(fresh.quantity, fresh.reservedQuantity);
          const take = Math.min(remaining, avail);
          if (take <= 0) continue;

          const updatedFrom = await tx.stock.update({
            where: { id: s.id },
            data: { quantity: { decrement: take } },
            include: { medicine: { select: { name: true, minStock: true } } },
          });

          await tx.stockMovement.create({
            data: {
              tenantId: requireTenantId(user),
              branchId: transfer.fromBranchId,
              medicineId: item.medicineId,
              batchId: updatedFrom.batchId,
              movementType: 'TRANSFER',
              quantity: -take,
              referenceType: 'TRANSFER',
              referenceId: transfer.id,
              createdById: user.sub,
              notes: transfer.transferNumber,
            },
          });

          this.realtime.emitStockUpdated(requireTenantId(user), transfer.fromBranchId, {
            medicine_id: updatedFrom.medicineId,
            branch_id: transfer.fromBranchId,
            batch_id: updatedFrom.batchId,
            medicine_name: updatedFrom.medicine.name,
            quantity: updatedFrom.quantity,
            reserved_quantity: updatedFrom.reservedQuantity,
            available_quantity: this.available(
              updatedFrom.quantity,
              updatedFrom.reservedQuantity,
            ),
          });

          const toBranch = await loadBranchForStock(
            tx,
            requireTenantId(user),
            transfer.toBranchId,
          );
          const inboundLocationId = await resolveInboundLocationId(
            tx,
            toBranch,
          );

          const toStock = await tx.stock.findFirst({
            where: {
              tenantId: requireTenantId(user),
              branchId: transfer.toBranchId,
              locationId: inboundLocationId,
              medicineId: item.medicineId,
              batchId: updatedFrom.batchId,
            },
            include: { medicine: { select: { name: true, minStock: true } } },
          });

          let updatedTo:
            | (typeof toStock & { medicine: { name: string; minStock: number } })
            | null = null;
          if (toStock) {
            await tx.$queryRaw`
              SELECT id FROM stocks WHERE id = ${toStock.id}::uuid FOR UPDATE
            `;
            updatedTo = await tx.stock.update({
              where: { id: toStock.id },
              data: { quantity: { increment: take } },
              include: { medicine: { select: { name: true, minStock: true } } },
            });
          } else {
            updatedTo = await findOrCreateStockRow(tx, {
              tenantId: requireTenantId(user),
              branchId: transfer.toBranchId,
              locationId: inboundLocationId,
              medicineId: item.medicineId,
              batchId: updatedFrom.batchId,
              initialQuantity: take,
            });
          }

          await tx.stockMovement.create({
            data: {
              tenantId: requireTenantId(user),
              branchId: transfer.toBranchId,
              medicineId: item.medicineId,
              batchId: updatedTo.batchId,
              movementType: 'TRANSFER',
              quantity: take,
              referenceType: 'TRANSFER',
              referenceId: transfer.id,
              createdById: user.sub,
              notes: transfer.transferNumber,
            },
          });

          this.realtime.emitStockUpdated(requireTenantId(user), transfer.toBranchId, {
            medicine_id: updatedTo.medicineId,
            branch_id: transfer.toBranchId,
            batch_id: updatedTo.batchId,
            medicine_name: updatedTo.medicine.name,
            quantity: updatedTo.quantity,
            reserved_quantity: updatedTo.reservedQuantity,
            available_quantity: this.available(
              updatedTo.quantity,
              updatedTo.reservedQuantity,
            ),
          });

          remaining -= take;
        }

        if (remaining > 0) throw new ConflictException('STOCK_NOT_ENOUGH');
      }

      await tx.transferStock.update({
        where: { id: transfer.id },
        data: {
          status: 'COMPLETED',
          approvedById: user.sub,
          sentAt: new Date(),
          receivedAt: new Date(),
        },
      });
    });

    return { id: transfer.id, status: 'COMPLETED' };
  }

  async createDistribution(user: JwtPayloadUser, dto: CreateDistributionDto) {
    const tenantId = requireTenantId(user);
    const central = await getCentralWarehouseBranch(this.prisma, tenantId);

    const toBranch = await this.prisma.branch.findFirst({
      where: { id: dto.to_branch_id, tenantId, isActive: true },
    });
    if (!toBranch) throw new NotFoundException('Branch not found');
    assertNotCentralWarehouse(toBranch);

    const transferNumber = await this.generateNumber(tenantId);
    return this.prisma.transferStock.create({
      data: {
        tenantId,
        fromBranchId: central.id,
        toBranchId: dto.to_branch_id,
        transferNumber,
        transferType: 'DISTRIBUTION',
        status: 'DRAFT',
        requestedById: user.sub,
        items: {
          create: dto.items.map((i) => ({
            medicineId: i.medicine_id,
            batchId: i.batch_id,
            quantity: i.quantity,
          })),
        },
      },
      include: {
        items: {
          include: { medicine: { select: { id: true, name: true, unit: true } } },
        },
        fromBranch: { select: { id: true, name: true, code: true } },
        toBranch: { select: { id: true, name: true, code: true } },
      },
    });
  }

  async sendDistribution(user: JwtPayloadUser, id: string) {
    const transfer = await this.findOne(user, id);
    if (transfer.transferType !== 'DISTRIBUTION') {
      throw new BadRequestException('Bukan dokumen distribusi');
    }
    if (transfer.status !== 'DRAFT') {
      throw new BadRequestException('Distribusi hanya bisa dikirim dari status DRAFT');
    }

    const tenantId = requireTenantId(user);
    await this.prisma.$transaction(async (tx) => {
      for (const item of transfer.items) {
        await this.decrementBranchStock(tx, user, transfer, item);
      }
      await tx.transferStock.update({
        where: { id: transfer.id },
        data: { status: 'SENT', sentAt: new Date(), approvedById: user.sub },
      });
    });

    return { id: transfer.id, status: 'SENT' };
  }

  async receiveDistribution(user: JwtPayloadUser, id: string) {
    const transfer = await this.findOne(user, id);
    if (transfer.transferType !== 'DISTRIBUTION') {
      throw new BadRequestException('Bukan dokumen distribusi');
    }
    if (transfer.status !== 'SENT') {
      throw new BadRequestException('Distribusi hanya bisa diterima dari status SENT');
    }

    const tenantId = requireTenantId(user);
    await this.prisma.$transaction(async (tx) => {
      for (const item of transfer.items) {
        await this.incrementBranchStock(tx, user, transfer, item);
      }
      await tx.transferStock.update({
        where: { id: transfer.id },
        data: { status: 'RECEIVED', receivedAt: new Date() },
      });
    });

    return { id: transfer.id, status: 'RECEIVED' };
  }

  private async decrementBranchStock(
    tx: Prisma.TransactionClient,
    user: JwtPayloadUser,
    transfer: {
      id: string;
      fromBranchId: string;
      transferNumber: string;
      items: Array<{
        medicineId: string;
        batchId: string | null;
        quantity: number;
      }>;
    },
    item: { medicineId: string; batchId: string | null; quantity: number },
  ) {
    const tenantId = requireTenantId(user);
    let remaining = item.quantity;

    const fromStocks = await tx.stock.findMany({
      where: {
        tenantId,
        branchId: transfer.fromBranchId,
        medicineId: item.medicineId,
        ...(item.batchId ? { batchId: item.batchId } : {}),
      },
      orderBy: { updatedAt: 'asc' },
      include: { medicine: { select: { name: true, minStock: true } } },
    });

    if (!fromStocks.length) throw new ConflictException('STOCK_NOT_ENOUGH');

    for (const s of fromStocks) {
      await tx.$queryRaw`
        SELECT id FROM stocks WHERE id = ${s.id}::uuid FOR UPDATE
      `;
    }

    for (const s of fromStocks) {
      if (remaining <= 0) break;
      const fresh = await tx.stock.findUnique({
        where: { id: s.id },
        include: { medicine: { select: { name: true, minStock: true } } },
      });
      if (!fresh) continue;

      const avail = this.available(fresh.quantity, fresh.reservedQuantity);
      const take = Math.min(remaining, avail);
      if (take <= 0) continue;

      const updatedFrom = await tx.stock.update({
        where: { id: s.id },
        data: { quantity: { decrement: take } },
        include: { medicine: { select: { name: true, minStock: true } } },
      });

      await tx.stockMovement.create({
        data: {
          tenantId,
          branchId: transfer.fromBranchId,
          medicineId: item.medicineId,
          batchId: updatedFrom.batchId,
          movementType: 'DISTRIBUTION_OUT',
          quantity: -take,
          referenceType: 'DISTRIBUTION',
          referenceId: transfer.id,
          createdById: user.sub,
          notes: transfer.transferNumber,
        },
      });

      this.realtime.emitStockUpdated(tenantId, transfer.fromBranchId, {
        medicine_id: updatedFrom.medicineId,
        branch_id: transfer.fromBranchId,
        batch_id: updatedFrom.batchId,
        medicine_name: updatedFrom.medicine.name,
        quantity: updatedFrom.quantity,
        reserved_quantity: updatedFrom.reservedQuantity,
        available_quantity: this.available(
          updatedFrom.quantity,
          updatedFrom.reservedQuantity,
        ),
      });

      remaining -= take;
    }

    if (remaining > 0) throw new ConflictException('STOCK_NOT_ENOUGH');
  }

  private async incrementBranchStock(
    tx: Prisma.TransactionClient,
    user: JwtPayloadUser,
    transfer: {
      id: string;
      toBranchId: string;
      transferNumber: string;
    },
    item: { medicineId: string; batchId: string | null; quantity: number },
  ) {
    const tenantId = requireTenantId(user);
    const toBranch = await loadBranchForStock(
      tx,
      tenantId,
      transfer.toBranchId,
    );
    const inboundLocationId = await resolveInboundLocationId(tx, toBranch);

    const toStock = await tx.stock.findFirst({
      where: {
        tenantId,
        branchId: transfer.toBranchId,
        locationId: inboundLocationId,
        medicineId: item.medicineId,
        batchId: item.batchId,
      },
      include: { medicine: { select: { name: true, minStock: true } } },
    });

    let updatedTo;
    if (toStock) {
      await tx.$queryRaw`
        SELECT id FROM stocks WHERE id = ${toStock.id}::uuid FOR UPDATE
      `;
      updatedTo = await tx.stock.update({
        where: { id: toStock.id },
        data: { quantity: { increment: item.quantity } },
        include: { medicine: { select: { name: true, minStock: true } } },
      });
    } else {
      updatedTo = await findOrCreateStockRow(tx, {
        tenantId,
        branchId: transfer.toBranchId,
        locationId: inboundLocationId,
        medicineId: item.medicineId,
        batchId: item.batchId,
        initialQuantity: item.quantity,
      });
    }

    await tx.stockMovement.create({
      data: {
        tenantId,
        branchId: transfer.toBranchId,
        medicineId: item.medicineId,
        batchId: updatedTo.batchId,
        movementType: 'DISTRIBUTION_IN',
        quantity: item.quantity,
        referenceType: 'DISTRIBUTION',
        referenceId: transfer.id,
        createdById: user.sub,
        notes: transfer.transferNumber,
      },
    });

    this.realtime.emitStockUpdated(tenantId, transfer.toBranchId, {
      medicine_id: updatedTo.medicineId,
      branch_id: transfer.toBranchId,
      batch_id: updatedTo.batchId,
      medicine_name: updatedTo.medicine.name,
      quantity: updatedTo.quantity,
      reserved_quantity: updatedTo.reservedQuantity,
      available_quantity: this.available(
        updatedTo.quantity,
        updatedTo.reservedQuantity,
      ),
    });
  }
}

