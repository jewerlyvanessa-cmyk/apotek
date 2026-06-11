import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { BranchStockMode, Prisma } from '@prisma/client';
import { JwtPayloadUser } from '../../common/decorators/current-user.decorator';
import {
  assertBranchAccess,
  resolveBranchIdForWrite,
} from '../../common/utils/branch-scope.util';
import { requireTenantId } from '../../common/utils/require-tenant-id';
import {
  STOCK_LOCATION_CODE,
  applyBranchStockModeChange,
  ensureBranchStockLocations,
  findOrCreateStockRow,
  getLocationByCode,
  loadBranchForStock,
} from '../../common/utils/stock-location.util';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';
import { InternalMoveQueryDto } from './dto/internal-move-query.dto';
import { ReplenishStockDto } from './dto/replenish-stock.dto';

@Injectable()
export class StockInternalMovesService {
  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeService,
  ) {}

  private available(qty: number, reserved: number) {
    return Math.max(0, qty - reserved);
  }

  async listLocations(user: JwtPayloadUser, branchId: string) {
    const tenantId = requireTenantId(user);
    assertBranchAccess(user, branchId);
    const branch = await loadBranchForStock(this.prisma, tenantId, branchId);
    const locations = await ensureBranchStockLocations(this.prisma, branch);
    return locations.map((l) => ({
      id: l.id,
      code: l.code,
      name: l.name,
      is_sellable: l.isSellable,
      sort_order: l.sortOrder,
    }));
  }

  async updateBranchStockMode(
    user: JwtPayloadUser,
    branchId: string,
    stockMode: BranchStockMode,
    moveExistingTo?: 'BACK' | 'FRONT',
  ) {
    const tenantId = requireTenantId(user);
    assertBranchAccess(user, branchId);
    await loadBranchForStock(this.prisma, tenantId, branchId);
    return applyBranchStockModeChange(this.prisma, branchId, stockMode, {
      moveExistingTo: moveExistingTo,
    });
  }

  async list(user: JwtPayloadUser, query: InternalMoveQueryDto) {
    const tenantId = requireTenantId(user);
    const branchId = query.branch_id
      ? resolveBranchIdForWrite(user, query.branch_id)
      : user.branchId;
    if (!branchId) {
      throw new BadRequestException('branch_id wajib');
    }
    assertBranchAccess(user, branchId);

    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where: Prisma.StockInternalMoveWhereInput = {
      tenantId,
      branchId,
    };

    const [items, total] = await Promise.all([
      this.prisma.stockInternalMove.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          fromLocation: { select: { id: true, code: true, name: true } },
          toLocation: { select: { id: true, code: true, name: true } },
          items: {
            include: {
              medicine: { select: { id: true, name: true, unit: true } },
            },
          },
          createdBy: { select: { id: true, fullName: true } },
        },
      }),
      this.prisma.stockInternalMove.count({ where }),
    ]);

    return {
      items: items.map((m) => ({
        id: m.id,
        created_at: m.createdAt.toISOString(),
        status: m.status,
        notes: m.notes,
        from_location: m.fromLocation,
        to_location: m.toLocation,
        created_by: m.createdBy,
        items: m.items.map((i) => ({
          medicine_id: i.medicineId,
          medicine_name: i.medicine.name,
          unit: i.medicine.unit,
          batch_id: i.batchId,
          quantity: i.quantity,
        })),
      })),
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async replenish(user: JwtPayloadUser, dto: ReplenishStockDto) {
    const tenantId = requireTenantId(user);
    const branchId = resolveBranchIdForWrite(user, dto.branch_id);
    const branch = await loadBranchForStock(this.prisma, tenantId, branchId);

    if (branch.stockMode !== BranchStockMode.WAREHOUSE_ETALASE) {
      throw new BadRequestException(
        'Isi etalase hanya untuk cabang mode gudang + etalase',
      );
    }

    await ensureBranchStockLocations(this.prisma, branch);
    const fromLoc = await getLocationByCode(
      this.prisma,
      branchId,
      STOCK_LOCATION_CODE.BACK,
    );
    const toLoc = await getLocationByCode(
      this.prisma,
      branchId,
      STOCK_LOCATION_CODE.FRONT,
    );

    const batchId = dto.batch_id ?? null;

    const result = await this.prisma.$transaction(async (tx) => {
      const fromStock = await tx.stock.findFirst({
        where: {
          tenantId,
          branchId,
          locationId: fromLoc.id,
          medicineId: dto.medicine_id,
          batchId,
        },
        include: { medicine: { select: { name: true, minStock: true } } },
      });
      if (!fromStock) throw new NotFoundException('Stok gudang cabang tidak ditemukan');

      await tx.$queryRaw`
        SELECT id FROM stocks WHERE id = ${fromStock.id}::uuid FOR UPDATE
      `;

      const fresh = await tx.stock.findUnique({ where: { id: fromStock.id } });
      if (!fresh) throw new NotFoundException('Stok tidak ditemukan');

      const avail = this.available(fresh.quantity, fresh.reservedQuantity);
      if (avail < dto.quantity) {
        throw new ConflictException('STOCK_NOT_ENOUGH');
      }

      await tx.stock.update({
        where: { id: fromStock.id },
        data: { quantity: { decrement: dto.quantity } },
      });

      let toStock = await tx.stock.findFirst({
        where: {
          tenantId,
          branchId,
          locationId: toLoc.id,
          medicineId: dto.medicine_id,
          batchId,
        },
        include: { medicine: { select: { name: true, minStock: true } } },
      });

      if (toStock) {
        toStock = await tx.stock.update({
          where: { id: toStock.id },
          data: { quantity: { increment: dto.quantity } },
          include: { medicine: { select: { name: true, minStock: true } } },
        });
      } else {
        toStock = await findOrCreateStockRow(tx, {
          tenantId,
          branchId,
          locationId: toLoc.id,
          medicineId: dto.medicine_id,
          batchId,
          initialQuantity: dto.quantity,
        });
      }

      const move = await tx.stockInternalMove.create({
        data: {
          tenantId,
          branchId,
          fromLocationId: fromLoc.id,
          toLocationId: toLoc.id,
          status: 'COMPLETED',
          notes: dto.notes ?? 'Isi etalase',
          createdById: user.sub,
          items: {
            create: {
              medicineId: dto.medicine_id,
              batchId,
              quantity: dto.quantity,
            },
          },
        },
        include: {
          items: true,
          fromLocation: true,
          toLocation: true,
        },
      });

      await tx.stockMovement.create({
        data: {
          tenantId,
          branchId,
          medicineId: dto.medicine_id,
          batchId,
          movementType: 'INTERNAL_OUT',
          quantity: -dto.quantity,
          referenceType: 'INTERNAL_MOVE',
          referenceId: move.id,
          notes: dto.notes ?? 'Keluar gudang cabang → etalase',
          createdById: user.sub,
        },
      });

      await tx.stockMovement.create({
        data: {
          tenantId,
          branchId,
          medicineId: dto.medicine_id,
          batchId,
          movementType: 'INTERNAL_IN',
          quantity: dto.quantity,
          referenceType: 'INTERNAL_MOVE',
          referenceId: move.id,
          notes: dto.notes ?? 'Masuk etalase dari gudang cabang',
          createdById: user.sub,
        },
      });

      return { move, toStock };
    });

    this.realtime.emitStockUpdated(tenantId, branchId, {
      medicine_id: dto.medicine_id,
      branch_id: branchId,
      batch_id: batchId,
      medicine_name: result.toStock.medicine?.name,
      quantity: result.toStock.quantity,
      reserved_quantity: result.toStock.reservedQuantity,
      available_quantity: this.available(
        result.toStock.quantity,
        result.toStock.reservedQuantity,
      ),
    });

    return {
      id: result.move.id,
      status: result.move.status,
      quantity: dto.quantity,
      from_location: result.move.fromLocation,
      to_location: result.move.toLocation,
    };
  }
}
