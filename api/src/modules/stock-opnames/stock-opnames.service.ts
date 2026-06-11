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
  findOrCreateStockRow,
  loadBranchForStock,
  resolveInboundLocationId,
} from '../../common/utils/stock-location.util';
import { CreateStockOpnameDto } from './dto/create-stock-opname.dto';
import { StockOpnameQueryDto } from './dto/opname-query.dto';
import { UpsertOpnameItemsDto } from './dto/upsert-opname-items.dto';

@Injectable()
export class StockOpnamesService {
  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeService,
  ) {}

  private available(quantity: number, reserved: number) {
    return Math.max(0, quantity - reserved);
  }

  private async generateNumber(tenantId: string) {
    const today = new Date();
    const prefix = `OPN-${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;
    const count = await this.prisma.stockOpname.count({
      where: { tenantId, opnameNumber: { startsWith: prefix } },
    });
    return `${prefix}-${String(count + 1).padStart(3, '0')}`;
  }

  async create(user: JwtPayloadUser, dto: CreateStockOpnameDto) {
    const branchId = dto.branch_id ?? user.branchId;
    if (!branchId) throw new BadRequestException('branch_id is required');

    const opnameNumber = await this.generateNumber(requireTenantId(user));
    return this.prisma.stockOpname.create({
      data: {
        tenantId: requireTenantId(user),
        branchId,
        opnameNumber,
        status: 'DRAFT',
        createdById: user.sub,
      },
      include: {
        items: {
          include: { medicine: { select: { id: true, name: true, unit: true } } },
        },
      },
    });
  }

  async findAll(user: JwtPayloadUser, query: StockOpnameQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;
    const branchId = query.branch_id ?? user.branchId;
    if (!branchId) throw new BadRequestException('branch_id is required');

    const where: Prisma.StockOpnameWhereInput = {
      tenantId: requireTenantId(user),
      branchId,
      ...(query.status ? { status: query.status } : {}),
      ...(query.search
        ? { opnameNumber: { contains: query.search, mode: 'insensitive' } }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.stockOpname.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          createdBy: { select: { id: true, fullName: true } },
          approvedBy: { select: { id: true, fullName: true } },
          _count: { select: { items: true } },
        },
      }),
      this.prisma.stockOpname.count({ where }),
    ]);

    return {
      items,
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async findOne(user: JwtPayloadUser, id: string) {
    const opname = await this.prisma.stockOpname.findFirst({
      where: { id, tenantId: requireTenantId(user) },
      include: {
        items: {
          include: { medicine: { select: { id: true, name: true, unit: true } } },
          orderBy: { medicineId: 'asc' },
        },
        createdBy: { select: { id: true, fullName: true } },
        approvedBy: { select: { id: true, fullName: true } },
      },
    });
    if (!opname) throw new NotFoundException('Stock opname not found');
    return opname;
  }

  async upsertItems(user: JwtPayloadUser, id: string, dto: UpsertOpnameItemsDto) {
    const opname = await this.findOne(user, id);
    if (opname.status !== 'DRAFT') {
      throw new BadRequestException('Only DRAFT opname can be edited');
    }

    return this.prisma.$transaction(async (tx) => {
      for (const item of dto.items) {
        const stocks = await tx.stock.findMany({
          where: {
            tenantId: requireTenantId(user),
            branchId: opname.branchId,
            medicineId: item.medicine_id,
          },
        });
        const systemQty = stocks.reduce((a, s) => a + s.quantity, 0);
        const reserved = stocks.reduce((a, s) => a + s.reservedQuantity, 0);
        const available = this.available(systemQty, reserved);
        if (item.actual_qty < reserved) {
          throw new ConflictException('ACTUAL_QTY_LESS_THAN_RESERVED');
        }
        const difference = item.actual_qty - systemQty;

        const existing = await tx.stockOpnameItem.findFirst({
          where: { opnameId: opname.id, medicineId: item.medicine_id },
        });
        if (existing) {
          await tx.stockOpnameItem.update({
            where: { id: existing.id },
            data: {
              systemQty,
              actualQty: item.actual_qty,
              differenceQty: difference,
              notes: item.notes,
            },
          });
        } else {
          await tx.stockOpnameItem.create({
            data: {
              opnameId: opname.id,
              medicineId: item.medicine_id,
              systemQty,
              actualQty: item.actual_qty,
              differenceQty: difference,
              notes: item.notes,
            },
          });
        }

        // keep available in case we want to show warning later
        void available;
      }

      return tx.stockOpname.findFirst({
        where: { id: opname.id },
        include: {
          items: {
            include: { medicine: { select: { id: true, name: true, unit: true } } },
          },
        },
      });
    });
  }

  async submit(user: JwtPayloadUser, id: string) {
    const opname = await this.findOne(user, id);
    if (opname.status !== 'DRAFT') {
      throw new BadRequestException('Only DRAFT opname can be submitted');
    }
    if (!opname.items.length) {
      throw new BadRequestException('Opname has no items');
    }

    await this.prisma.$transaction(async (tx) => {
      for (const item of opname.items) {
        // lock all stocks for this medicine in branch
        const stocks = await tx.stock.findMany({
          where: {
            tenantId: requireTenantId(user),
            branchId: opname.branchId,
            medicineId: item.medicineId,
          },
          orderBy: { updatedAt: 'asc' },
          include: { medicine: { select: { name: true, minStock: true } } },
        });

        // lock rows
        for (const s of stocks) {
          await tx.$queryRaw`
            SELECT id FROM stocks WHERE id = ${s.id}::uuid FOR UPDATE
          `;
        }

        const currentTotal = stocks.reduce((a, s) => a + s.quantity, 0);
        const reservedTotal = stocks.reduce((a, s) => a + s.reservedQuantity, 0);
        if (item.actualQty < reservedTotal) {
          throw new ConflictException('ACTUAL_QTY_LESS_THAN_RESERVED');
        }

        let diff = item.actualQty - currentTotal; // positive => add stock, negative => reduce
        if (diff === 0) continue;

        if (diff < 0) {
          // decrement across rows but never below reserved
          let remaining = -diff;
          for (const s of stocks) {
            if (remaining <= 0) break;
            const maxDecrement = Math.max(0, s.quantity - s.reservedQuantity);
            const dec = Math.min(remaining, maxDecrement);
            if (dec <= 0) continue;

            const updated = await tx.stock.update({
              where: { id: s.id },
              data: { quantity: { decrement: dec } },
              include: { medicine: { select: { name: true, minStock: true } } },
            });

            await tx.stockMovement.create({
              data: {
                tenantId: requireTenantId(user),
                branchId: opname.branchId,
                medicineId: item.medicineId,
                batchId: updated.batchId,
                movementType: 'ADJUSTMENT',
                quantity: -dec,
                referenceType: 'STOCK_OPNAME',
                referenceId: opname.id,
                createdById: user.sub,
                notes: `Opname ${opname.opnameNumber}`,
              },
            });

            this.realtime.emitStockUpdated(requireTenantId(user), opname.branchId, {
              medicine_id: updated.medicineId,
              branch_id: opname.branchId,
              batch_id: updated.batchId,
              medicine_name: updated.medicine.name,
              quantity: updated.quantity,
              reserved_quantity: updated.reservedQuantity,
              available_quantity: this.available(updated.quantity, updated.reservedQuantity),
            });

            remaining -= dec;
          }
          if (remaining > 0) {
            throw new ConflictException('STOCK_NOT_ENOUGH');
          }
        } else {
          // increment first row or create new stock row
          if (stocks.length) {
            const s0 = stocks[0];
            const updated = await tx.stock.update({
              where: { id: s0.id },
              data: { quantity: { increment: diff } },
              include: { medicine: { select: { name: true, minStock: true } } },
            });

            await tx.stockMovement.create({
              data: {
                tenantId: requireTenantId(user),
                branchId: opname.branchId,
                medicineId: item.medicineId,
                batchId: updated.batchId,
                movementType: 'ADJUSTMENT',
                quantity: diff,
                referenceType: 'STOCK_OPNAME',
                referenceId: opname.id,
                createdById: user.sub,
                notes: `Opname ${opname.opnameNumber}`,
              },
            });

            this.realtime.emitStockUpdated(requireTenantId(user), opname.branchId, {
              medicine_id: updated.medicineId,
              branch_id: opname.branchId,
              batch_id: updated.batchId,
              medicine_name: updated.medicine.name,
              quantity: updated.quantity,
              reserved_quantity: updated.reservedQuantity,
              available_quantity: this.available(updated.quantity, updated.reservedQuantity),
            });
          } else {
            const opnameBranch = await loadBranchForStock(
              tx,
              requireTenantId(user),
              opname.branchId,
            );
            const inboundLocationId = await resolveInboundLocationId(
              tx,
              opnameBranch,
            );
            const created = await findOrCreateStockRow(tx, {
              tenantId: requireTenantId(user),
              branchId: opname.branchId,
              locationId: inboundLocationId,
              medicineId: item.medicineId,
              batchId: null,
              initialQuantity: diff,
            });

            await tx.stockMovement.create({
              data: {
                tenantId: requireTenantId(user),
                branchId: opname.branchId,
                medicineId: item.medicineId,
                batchId: created.batchId,
                movementType: 'ADJUSTMENT',
                quantity: diff,
                referenceType: 'STOCK_OPNAME',
                referenceId: opname.id,
                createdById: user.sub,
                notes: `Opname ${opname.opnameNumber}`,
              },
            });

            this.realtime.emitStockUpdated(requireTenantId(user), opname.branchId, {
              medicine_id: created.medicineId,
              branch_id: opname.branchId,
              batch_id: created.batchId,
              medicine_name: created.medicine.name,
              quantity: created.quantity,
              reserved_quantity: created.reservedQuantity,
              available_quantity: this.available(created.quantity, created.reservedQuantity),
            });
          }
        }
      }

      await tx.stockOpname.update({
        where: { id: opname.id },
        data: {
          status: 'SUBMITTED',
          approvedById: user.sub,
        },
      });
    });

    return { id: opname.id, status: 'SUBMITTED' };
  }
}

