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
import { AuditLogRequestMeta, AuditLogsService } from '../audit-logs/audit-logs.service';
import { RedisCacheService } from '../../infrastructure/redis/redis.service';
import { RealtimeService, StockUpdatedPayload } from '../realtime/realtime.service';
import { StockAdjustmentDto, StockMutationDto } from './dto/stock-mutation.dto';
import { StockReceiveDto } from './dto/stock-receive.dto';
import { UpdateStockDto } from './dto/update-stock.dto';
import { StockMovementQueryDto } from './dto/stock-movement-query.dto';
import { StockQueryDto } from './dto/stock-query.dto';
import {
  assertBranchAccess,
  resolveBranchIdForWrite,
  resolveBranchScopeForList,
} from '../../common/utils/branch-scope.util';
import { assertBranchIsActive } from '../../common/utils/tenant-access.util';
import {
  ensureBranchStockLocations,
  findOrCreateStockRow,
  getLocationByCode,
  getSellableLocationIds,
  loadBranchForStock,
  resolveInboundLocationId,
  STOCK_LOCATION_CODE,
} from '../../common/utils/stock-location.util';
import { BranchStockMode } from '@prisma/client';

const stockListInclude = {
  medicine: {
    select: {
      id: true,
      name: true,
      barcode: true,
      unit: true,
      minStock: true,
      sellPrice: true,
    },
  },
  batch: {
    select: {
      id: true,
      batchNumber: true,
      expiredDate: true,
    },
  },
  branch: {
    select: { id: true, name: true, code: true, stockMode: true },
  },
  location: {
    select: { id: true, code: true, name: true, isSellable: true },
  },
} satisfies Prisma.StockInclude;

type StockListRow = Prisma.StockGetPayload<{ include: typeof stockListInclude }>;

@Injectable()
export class StocksService {
  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeService,
    private auditLogs: AuditLogsService,
    private cache: RedisCacheService,
  ) {}

  private availableQty(quantity: number, reserved: number) {
    return Math.max(0, quantity - reserved);
  }

  private stockListCacheTag(tenantId: string, branchId?: string) {
    return branchId
      ? `stocks:${tenantId}:${branchId}`
      : `stocks:${tenantId}:all`;
  }

  private mapStockRows(items: StockListRow[]) {
    return items.map((s) => ({
      ...s,
      available_quantity: this.availableQty(s.quantity, s.reservedQuantity),
      location_code: s.location?.code,
      location_name: s.location?.name,
      is_sellable: s.location?.isSellable,
    }));
  }

  private async resolveLocationFilter(
    tenantId: string,
    branchId: string | undefined,
    query: StockQueryDto,
  ): Promise<Prisma.StockWhereInput> {
    if (!branchId) return {};
    const branch = await loadBranchForStock(this.prisma, tenantId, branchId);

    if (query.location_id) {
      return { locationId: query.location_id };
    }
    if (query.location_code?.trim()) {
      const code = query.location_code.trim().toUpperCase();
      if (
        branch.stockMode === BranchStockMode.SIMPLE &&
        (code === STOCK_LOCATION_CODE.BACK ||
          code === STOCK_LOCATION_CODE.FRONT)
      ) {
        throw new BadRequestException(
          'Cabang memakai mode stok sederhana. Aktifkan mode Gudang + Etalase di Admin → Daftar Cabang.',
        );
      }
      await ensureBranchStockLocations(this.prisma, branch);
      const loc = await getLocationByCode(this.prisma, branchId, code);
      return { locationId: loc.id };
    }
    if (query.sellable_only) {
      const ids = await getSellableLocationIds(this.prisma, branch);
      return { locationId: { in: ids } };
    }
    return {};
  }

  private async findLowStockPage(
    tenantId: string,
    branchId: string | undefined,
    skip: number,
    limit: number,
  ) {
    const branchClause = branchId
      ? Prisma.sql`AND s.branch_id = ${branchId}::uuid`
      : Prisma.empty;

    const [{ count }] = await this.prisma.$queryRaw<[{ count: bigint }]>`
      SELECT COUNT(*)::bigint AS count
      FROM stocks s
      INNER JOIN medicines m ON m.id = s.medicine_id
      WHERE s.tenant_id = ${tenantId}::uuid
      ${branchClause}
      AND (s.quantity - s.reserved_quantity) <= m.min_stock
    `;

    const idRows = await this.prisma.$queryRaw<{ id: string }[]>`
      SELECT s.id
      FROM stocks s
      INNER JOIN medicines m ON m.id = s.medicine_id
      WHERE s.tenant_id = ${tenantId}::uuid
      ${branchClause}
      AND (s.quantity - s.reserved_quantity) <= m.min_stock
      ORDER BY s.updated_at DESC
      LIMIT ${limit} OFFSET ${skip}
    `;

    const ids = idRows.map((r) => r.id);
    if (!ids.length) {
      return { items: [], total: Number(count) };
    }

    const rows = await this.prisma.stock.findMany({
      where: { id: { in: ids } },
      include: stockListInclude,
    });
    const order = new Map(ids.map((id, index) => [id, index]));
    rows.sort((a, b) => (order.get(a.id) ?? 0) - (order.get(b.id) ?? 0));

    return { items: rows, total: Number(count) };
  }

  private toPayload(
    stock: {
      medicineId: string;
      branchId: string;
      batchId: string | null;
      quantity: number;
      reservedQuantity: number;
      medicine?: { name: string; minStock: number };
    },
  ): StockUpdatedPayload {
    return {
      medicine_id: stock.medicineId,
      branch_id: stock.branchId,
      batch_id: stock.batchId,
      medicine_name: stock.medicine?.name,
      quantity: stock.quantity,
      reserved_quantity: stock.reservedQuantity,
      available_quantity: this.availableQty(
        stock.quantity,
        stock.reservedQuantity,
      ),
    };
  }

  async findAll(user: JwtPayloadUser, query: StockQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;
    const tenantId = requireTenantId(user);
    const { branchId } = resolveBranchScopeForList(user, query.branch_id);
    if (branchId) {
      await assertBranchIsActive(this.prisma, tenantId, branchId);
    }
    const branchKey = branchId ?? 'all';

    const locationFilter = await this.resolveLocationFilter(
      tenantId,
      branchId,
      query,
    );
    const cacheKey = `stocks:list:${tenantId}:${branchKey}:${query.medicine_id ?? ''}:${query.low_stock ?? false}:${query.search ?? ''}:${query.location_id ?? ''}:${query.location_code ?? ''}:${query.sellable_only ?? false}:${page}:${limit}`;
    const cached = await this.cache.getJson<{
      items: any[];
      meta: { page: number; limit: number; total: number; last_page: number };
    }>(cacheKey);
    if (cached) return cached as any;

    const where: Prisma.StockWhereInput = {
      tenantId,
      ...(branchId ? { branchId } : {}),
      ...locationFilter,
      ...(query.medicine_id ? { medicineId: query.medicine_id } : {}),
      ...(query.search
        ? {
            medicine: {
              name: { contains: query.search, mode: 'insensitive' },
            },
          }
        : {}),
    };

    let items: StockListRow[];
    let total: number;

    if (query.low_stock && !query.search && !query.medicine_id) {
      const pageResult = await this.findLowStockPage(
        tenantId,
        branchId,
        skip,
        limit,
      );
      items = pageResult.items;
      total = pageResult.total;
    } else {
      [total, items] = await Promise.all([
        this.prisma.stock.count({ where }),
        this.prisma.stock.findMany({
          where,
          include: stockListInclude,
          orderBy: { updatedAt: 'desc' },
          skip,
          take: limit,
        }),
      ]);

      if (query.low_stock) {
        items = items.filter(
          (s) =>
            this.availableQty(s.quantity, s.reservedQuantity) <=
            s.medicine.minStock,
        );
        total = items.length;
      }
    }

    const result = {
      items: this.mapStockRows(items),
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
    await this.cache.setJson(cacheKey, result, 30, [
      this.stockListCacheTag(tenantId, branchId),
    ]);
    return result;
  }

  async movements(user: JwtPayloadUser, query: StockMovementQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;
    const tenantId = requireTenantId(user);
    const { branchId } = resolveBranchScopeForList(user, query.branch_id);
    if (branchId) {
      await assertBranchIsActive(this.prisma, tenantId, branchId);
    }

    const from = query.date_from ? new Date(query.date_from) : undefined;
    const to = query.date_to ? new Date(query.date_to) : undefined;

    const where: Prisma.StockMovementWhereInput = {
      tenantId,
      ...(branchId ? { branchId } : {}),
      ...(query.medicine_id ? { medicineId: query.medicine_id } : {}),
      ...(query.movement_type ? { movementType: query.movement_type } : {}),
      ...(query.reference_type ? { referenceType: query.reference_type } : {}),
      ...(query.reference_id ? { referenceId: query.reference_id } : {}),
      ...(from || to
        ? {
            createdAt: {
              ...(from ? { gte: from } : {}),
              ...(to ? { lte: to } : {}),
            },
          }
        : {}),
      ...(query.search
        ? {
            OR: [
              { notes: { contains: query.search, mode: 'insensitive' } },
              { movementType: { contains: query.search, mode: 'insensitive' } },
              { referenceType: { contains: query.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.stockMovement.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          medicine: { select: { id: true, name: true, unit: true } },
          batch: { select: { id: true, batchNumber: true, expiredDate: true } },
          branch: { select: { id: true, name: true, code: true } },
          createdBy: { select: { id: true, fullName: true } },
        },
      }),
      this.prisma.stockMovement.count({ where }),
    ]);

    return {
      items: items.map((m) => ({
        id: m.id,
        created_at: m.createdAt.toISOString(),
        branch_id: m.branchId,
        branch_name: m.branch?.name,
        medicine_id: m.medicineId,
        medicine_name: m.medicine?.name,
        unit: m.medicine?.unit,
        batch_id: m.batchId,
        batch_number: m.batch?.batchNumber,
        expired_date: m.batch?.expiredDate ? m.batch.expiredDate.toISOString() : null,
        movement_type: m.movementType,
        quantity: m.quantity,
        reference_type: m.referenceType,
        reference_id: m.referenceId,
        notes: m.notes,
        created_by: m.createdBy ? { id: m.createdBy.id, full_name: m.createdBy.fullName } : null,
      })),
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async getRealtime(
    user: JwtPayloadUser,
    medicineId: string,
    branchId?: string,
    sellableOnly = true,
  ) {
    const tenantId = requireTenantId(user);
    const bid = resolveBranchIdForWrite(user, branchId);
    const branch = await loadBranchForStock(this.prisma, tenantId, bid);
    const sellableIds = sellableOnly
      ? await getSellableLocationIds(this.prisma, branch)
      : null;

    const cacheKey = `stocks:realtime:${tenantId}:${bid}:${medicineId}:${sellableOnly}`;
    const cached = await this.cache.getJson<any>(cacheKey);
    if (cached) return cached;

    const stocks = await this.prisma.stock.findMany({
      where: {
        tenantId,
        branchId: bid,
        medicineId,
        ...(sellableIds ? { locationId: { in: sellableIds } } : {}),
      },
      include: { medicine: { select: { name: true, minStock: true } } },
    });

    if (!stocks.length) {
      const empty = {
        medicine_id: medicineId,
        branch_id: bid,
        quantity: 0,
        reserved_quantity: 0,
        available_quantity: 0,
        batches: [],
      };
      await this.cache.setJson(cacheKey, empty, 2, [
        `stocks:${requireTenantId(user)}:${bid}`,
        `stocks:med:${requireTenantId(user)}:${bid}:${medicineId}`,
      ]);
      return empty;
    }

    const totalQty = stocks.reduce((a, s) => a + s.quantity, 0);
    const totalReserved = stocks.reduce((a, s) => a + s.reservedQuantity, 0);
    const rackPositions = [
      ...new Set(
        stocks
          .map((s) => s.rackPosition?.trim())
          .filter((r): r is string => !!r),
      ),
    ];

    const result = {
      medicine_id: medicineId,
      branch_id: bid,
      medicine_name: stocks[0].medicine.name,
      quantity: totalQty,
      reserved_quantity: totalReserved,
      available_quantity: this.availableQty(totalQty, totalReserved),
      rack_position: rackPositions.length > 0 ? rackPositions.join(', ') : null,
      batches: stocks.map((s) => ({
        stock_id: s.id,
        batch_id: s.batchId,
        quantity: s.quantity,
        reserved_quantity: s.reservedQuantity,
        available_quantity: this.availableQty(s.quantity, s.reservedQuantity),
      })),
    };
    await this.cache.setJson(cacheKey, result, 2, [
      `stocks:${requireTenantId(user)}:${bid}`,
      `stocks:med:${requireTenantId(user)}:${bid}:${medicineId}`,
    ]);
    return result;
  }

  async adjust(
    user: JwtPayloadUser,
    dto: StockAdjustmentDto,
    meta?: AuditLogRequestMeta,
  ) {
    const tenantId = requireTenantId(user);
    const branchId = resolveBranchIdForWrite(user, dto.branch_id);
    const branch = await loadBranchForStock(this.prisma, tenantId, branchId);
    const inboundLocationId = await resolveInboundLocationId(
      this.prisma,
      branch,
    );

    let before: { id: string; quantity: number; reservedQuantity: number } | null = null;
    const result = await this.prisma.$transaction(async (tx) => {
      let stock = await tx.stock.findFirst({
        where: {
          tenantId,
          branchId,
          medicineId: dto.medicine_id,
          batchId: dto.batch_id ?? null,
        },
        include: { medicine: { select: { name: true, minStock: true } } },
      });

      if (!stock && dto.batch_id) {
        throw new NotFoundException('Stock record not found');
      }

      if (!stock) {
        const batchId = dto.batch_id ?? null;
        stock = await findOrCreateStockRow(tx, {
          tenantId,
          branchId,
          locationId: inboundLocationId,
          medicineId: dto.medicine_id,
          batchId,
          initialQuantity: dto.quantity,
        });

        await tx.stockMovement.create({
          data: {
            tenantId: requireTenantId(user),
            branchId,
            medicineId: dto.medicine_id,
            batchId,
            movementType: 'ADJUSTMENT',
            quantity: dto.quantity,
            referenceType: 'STOCK',
            referenceId: stock.id,
            notes: dto.notes,
            createdById: user.sub,
          },
        });

        return stock;
      }

      before = {
        id: stock.id,
        quantity: stock.quantity,
        reservedQuantity: stock.reservedQuantity,
      };

      const locked = await tx.$queryRaw<
        Array<{ id: string; quantity: number; reserved_quantity: number }>
      >`
        SELECT id, quantity, reserved_quantity
        FROM stocks
        WHERE id = ${stock.id}::uuid
        FOR UPDATE
      `;

      if (!locked.length) throw new NotFoundException('Stock not found');

      const diff = dto.quantity - stock.quantity;
      const updated = await tx.stock.update({
        where: { id: stock.id },
        data: { quantity: dto.quantity },
        include: { medicine: { select: { name: true, minStock: true } } },
      });

      await tx.stockMovement.create({
        data: {
          tenantId: requireTenantId(user),
          branchId,
          medicineId: dto.medicine_id,
          batchId: stock.batchId,
          movementType: 'ADJUSTMENT',
          quantity: diff,
          referenceType: 'STOCK',
          referenceId: stock.id,
          notes: dto.notes ?? `Adjust to ${dto.quantity}`,
          createdById: user.sub,
        },
      });

      return updated;
    });

    const payload = this.toPayload(result);
    this.realtime.emitStockUpdated(requireTenantId(user), branchId, payload);

    const available = payload.available_quantity;
    if (available <= (result.medicine?.minStock ?? 0)) {
      this.realtime.emitStockLow(requireTenantId(user), branchId, payload);
    }

    await this.auditLogs.log({
      tenantId: requireTenantId(user),
      userId: user.sub,
      module: 'STOCKS',
      action: 'ADJUST',
      referenceId: (result as any).id,
      oldData: before,
      newData: {
        id: (result as any).id,
        medicine_id: dto.medicine_id,
        branch_id: branchId,
        batch_id: dto.batch_id ?? null,
        quantity: (result as any).quantity,
        reserved_quantity: (result as any).reservedQuantity,
        notes: dto.notes,
      },
      ...meta,
    });

    await this.cache.invalidateTags([
      this.stockListCacheTag(tenantId, branchId),
      this.stockListCacheTag(tenantId),
      `stocks:med:${tenantId}:${branchId}:${dto.medicine_id}`,
    ]);

    return payload;
  }

  async mutate(user: JwtPayloadUser, dto: StockMutationDto, meta?: AuditLogRequestMeta) {
    const tenantId = requireTenantId(user);
    const branchId = resolveBranchIdForWrite(user, dto.branch_id);

    const delta = dto.quantity;
    if (delta === 0) throw new BadRequestException('quantity cannot be zero');

    let before: { id: string; quantity: number; reservedQuantity: number } | null = null;
    const result = await this.prisma.$transaction(async (tx) => {
      const stock = await tx.stock.findFirst({
        where: {
          tenantId,
          branchId,
          medicineId: dto.medicine_id,
          batchId: dto.batch_id ?? null,
        },
        orderBy: { updatedAt: 'desc' },
        include: { medicine: { select: { name: true, minStock: true } } },
      });

      if (!stock) throw new NotFoundException('Stock not found');

      before = {
        id: stock.id,
        quantity: stock.quantity,
        reservedQuantity: stock.reservedQuantity,
      };

      await tx.$queryRaw`
        SELECT id FROM stocks WHERE id = ${stock.id}::uuid FOR UPDATE
      `;

      const newQty = stock.quantity + delta;
      if (newQty < 0 || newQty < stock.reservedQuantity) {
        throw new ConflictException('STOCK_NOT_ENOUGH');
      }

      const updated = await tx.stock.update({
        where: { id: stock.id },
        data: { quantity: newQty },
        include: { medicine: { select: { name: true, minStock: true } } },
      });

      await tx.stockMovement.create({
        data: {
          tenantId: requireTenantId(user),
          branchId,
          medicineId: dto.medicine_id,
          batchId: stock.batchId,
          movementType: dto.movement_type,
          quantity: delta,
          referenceType: 'STOCK',
          referenceId: stock.id,
          notes: dto.notes,
          createdById: user.sub,
        },
      });

      return updated;
    });

    const payload = this.toPayload(result);
    this.realtime.emitStockUpdated(requireTenantId(user), branchId, payload);

    if (payload.available_quantity <= (result.medicine?.minStock ?? 0)) {
      this.realtime.emitStockLow(requireTenantId(user), branchId, payload);
    }

    await this.auditLogs.log({
      tenantId: requireTenantId(user),
      userId: user.sub,
      module: 'STOCKS',
      action: 'MUTATE',
      referenceId: (result as any).id,
      oldData: before,
      newData: {
        id: (result as any).id,
        medicine_id: dto.medicine_id,
        branch_id: branchId,
        batch_id: dto.batch_id ?? null,
        movement_type: dto.movement_type,
        quantity_delta: dto.quantity,
        quantity: (result as any).quantity,
        reserved_quantity: (result as any).reservedQuantity,
        notes: dto.notes,
      },
      ...meta,
    });

    await this.cache.invalidateTags([
      this.stockListCacheTag(tenantId, branchId),
      this.stockListCacheTag(tenantId),
      `stocks:med:${tenantId}:${branchId}:${dto.medicine_id}`,
    ]);

    return payload;
  }

  async receive(
    user: JwtPayloadUser,
    dto: StockReceiveDto,
    meta?: AuditLogRequestMeta,
  ) {
    const branchId = resolveBranchIdForWrite(user, dto.branch_id);
    const tenantId = requireTenantId(user);
    const branch = await loadBranchForStock(this.prisma, tenantId, branchId);
    const inboundLocationId = await resolveInboundLocationId(
      this.prisma,
      branch,
    );
    const medicine = await this.prisma.medicine.findFirst({
      where: { id: dto.medicine_id, tenantId, isActive: true },
      select: { id: true, name: true, minStock: true },
    });
    if (!medicine) throw new NotFoundException('Medicine not found');

    const result = await this.prisma.$transaction(async (tx) => {
      let batchId: string | null = dto.batch_id ?? null;

      if (batchId) {
        const batch = await tx.medicineBatch.findFirst({
          where: { id: batchId, medicineId: dto.medicine_id },
        });
        if (!batch) throw new NotFoundException('Batch not found');
      } else if (dto.batch_number?.trim()) {
        const batchNumber = dto.batch_number.trim();
        let batch = await tx.medicineBatch.findFirst({
          where: { medicineId: dto.medicine_id, batchNumber },
        });
        if (!batch) {
          batch = await tx.medicineBatch.create({
            data: {
              medicineId: dto.medicine_id,
              batchNumber,
              expiredDate: dto.expired_date
                ? new Date(dto.expired_date)
                : null,
            },
          });
        } else if (dto.expired_date) {
          batch = await tx.medicineBatch.update({
            where: { id: batch.id },
            data: { expiredDate: new Date(dto.expired_date) },
          });
        }
        batchId = batch.id;
      }

      let stock = await tx.stock.findFirst({
        where: {
          tenantId,
          branchId,
          locationId: inboundLocationId,
          medicineId: dto.medicine_id,
          batchId,
        },
        include: { medicine: { select: { name: true, minStock: true } } },
      });

      if (!stock) {
        const rack = dto.rack_position?.trim() || null;
        stock = await findOrCreateStockRow(tx, {
          tenantId,
          branchId,
          locationId: inboundLocationId,
          medicineId: dto.medicine_id,
          batchId,
          rackPosition: rack,
          initialQuantity: dto.quantity,
        });

        await tx.stockMovement.create({
          data: {
            tenantId,
            branchId,
            medicineId: dto.medicine_id,
            batchId,
            movementType: 'PURCHASE',
            quantity: dto.quantity,
            referenceType: 'STOCK',
            referenceId: stock.id,
            notes: dto.notes ?? 'Penerimaan stok',
            createdById: user.sub,
          },
        });

        return stock;
      }

      await tx.$queryRaw`
        SELECT id FROM stocks WHERE id = ${stock.id}::uuid FOR UPDATE
      `;

      const newQty = stock.quantity + dto.quantity;
      const updated = await tx.stock.update({
        where: { id: stock.id },
        data: {
          quantity: newQty,
          ...(dto.rack_position !== undefined
              ? { rackPosition: dto.rack_position.trim() || null }
              : {}),
        },
        include: { medicine: { select: { name: true, minStock: true } } },
      });

      await tx.stockMovement.create({
        data: {
          tenantId,
          branchId,
          medicineId: dto.medicine_id,
          batchId,
          movementType: 'PURCHASE',
          quantity: dto.quantity,
          referenceType: 'STOCK',
          referenceId: stock.id,
          notes: dto.notes ?? 'Penerimaan stok',
          createdById: user.sub,
        },
      });

      return updated;
    });

    const payload = this.toPayload(result);
    this.realtime.emitStockUpdated(tenantId, branchId, payload);

    if (payload.available_quantity <= (result.medicine?.minStock ?? 0)) {
      this.realtime.emitStockLow(tenantId, branchId, payload);
    }

    await this.auditLogs.log({
      tenantId,
      userId: user.sub,
      module: 'STOCKS',
      action: 'RECEIVE',
      referenceId: result.id,
      newData: {
        medicine_id: dto.medicine_id,
        branch_id: branchId,
        batch_id: result.batchId,
        quantity_added: dto.quantity,
        quantity: result.quantity,
        notes: dto.notes,
      },
      ...meta,
    });

    await this.cache.invalidateTags([
      this.stockListCacheTag(tenantId, branchId),
      this.stockListCacheTag(tenantId),
      `stocks:med:${tenantId}:${branchId}:${dto.medicine_id}`,
    ]);

    return payload;
  }

  async updateById(
    user: JwtPayloadUser,
    stockId: string,
    dto: UpdateStockDto,
    meta?: AuditLogRequestMeta,
  ) {
    if (dto.quantity === undefined && dto.rack_position === undefined) {
      throw new BadRequestException('quantity or rack_position is required');
    }

    const stock = await this.prisma.stock.findFirst({
      where: { id: stockId, tenantId: requireTenantId(user) },
      include: { medicine: { select: { name: true, minStock: true } } },
    });
    if (!stock) throw new NotFoundException('Stock not found');

    assertBranchAccess(user, stock.branchId);
    const branchId = stock.branchId;
    const tenantId = requireTenantId(user);

    const result = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`
        SELECT id FROM stocks WHERE id = ${stock.id}::uuid FOR UPDATE
      `;

      const data: Prisma.StockUpdateInput = {};
      if (dto.rack_position !== undefined) {
        const rack = dto.rack_position.trim();
        data.rackPosition = rack.length > 0 ? rack : null;
      }

      if (dto.quantity !== undefined) {
        const diff = dto.quantity - stock.quantity;
        if (diff !== 0) {
          await tx.stockMovement.create({
            data: {
              tenantId,
              branchId,
              medicineId: stock.medicineId,
              batchId: stock.batchId,
              movementType: 'ADJUSTMENT',
              quantity: diff,
              referenceType: 'STOCK',
              referenceId: stock.id,
              notes: 'Penyesuaian stok',
              createdById: user.sub,
            },
          });
        }
        data.quantity = dto.quantity;
      }

      return tx.stock.update({
        where: { id: stock.id },
        data,
        include: { medicine: { select: { name: true, minStock: true } } },
      });
    });

    const payload = this.toPayload(result);
    this.realtime.emitStockUpdated(tenantId, branchId, payload);

    await this.auditLogs.log({
      tenantId,
      userId: user.sub,
      module: 'STOCKS',
      action: 'UPDATE',
      referenceId: stock.id,
      newData: {
        quantity: result.quantity,
        rack_position: result.rackPosition,
      },
      ...meta,
    });

    await this.cache.invalidateTags([
      this.stockListCacheTag(tenantId, branchId),
      this.stockListCacheTag(tenantId),
      `stocks:med:${tenantId}:${branchId}:${stock.medicineId}`,
    ]);

    return payload;
  }
}
