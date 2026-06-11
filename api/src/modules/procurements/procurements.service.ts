import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { JwtPayloadUser } from '../../common/decorators/current-user.decorator';
import { requireTenantId } from '../../common/utils/require-tenant-id';
import { getCentralWarehouseBranch } from '../../common/utils/central-warehouse';
import {
  findOrCreateStockRow,
  loadBranchForStock,
  resolveInboundLocationId,
} from '../../common/utils/stock-location.util';
import { isTenantWideUser } from '../../common/utils/branch-scope.util';
import { RealtimeService } from '../realtime/realtime.service';
import { CreateProcurementDto } from './dto/create-procurement.dto';
import { ProcurementQueryDto } from './dto/procurement-query.dto';

@Injectable()
export class ProcurementsService {
  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeService,
  ) {}

  private available(qty: number, reserved: number) {
    return Math.max(0, qty - reserved);
  }

  private async generateNumber(tenantId: string) {
    const today = new Date();
    const prefix = `PRC-${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;
    const count = await this.prisma.procurement.count({
      where: { tenantId, procurementNumber: { startsWith: prefix } },
    });
    return `${prefix}-${String(count + 1).padStart(3, '0')}`;
  }

  private assertCanManage(user: JwtPayloadUser) {
    if (!isTenantWideUser(user)) {
      throw new BadRequestException(
        'Hanya owner atau manajer pusat yang dapat mengelola pengadaan',
      );
    }
  }

  async create(user: JwtPayloadUser, dto: CreateProcurementDto) {
    this.assertCanManage(user);
    const tenantId = requireTenantId(user);
    const central = await getCentralWarehouseBranch(this.prisma, tenantId);

    if (dto.supplier_id) {
      const supplier = await this.prisma.supplier.findFirst({
        where: { id: dto.supplier_id, tenantId },
      });
      if (!supplier) throw new NotFoundException('Supplier not found');
    }

    for (const item of dto.items) {
      const med = await this.prisma.medicine.findFirst({
        where: { id: item.medicine_id, tenantId, isActive: true },
      });
      if (!med) throw new NotFoundException(`Medicine ${item.medicine_id} not found`);
    }

    const procurementNumber = await this.generateNumber(tenantId);

    return this.prisma.procurement.create({
      data: {
        tenantId,
        centralBranchId: central.id,
        procurementNumber,
        supplierId: dto.supplier_id,
        status: 'DRAFT',
        notes: dto.notes,
        createdById: user.sub,
        items: {
          create: dto.items.map((i) => ({
            medicineId: i.medicine_id,
            batchNumber: i.batch_number?.trim() || null,
            expiredDate: i.expired_date ? new Date(i.expired_date) : null,
            quantity: i.quantity,
            buyPrice: i.buy_price ?? 0,
            sellPrice: i.sell_price ?? 0,
          })),
        },
      },
      include: this.includeDetail(),
    });
  }

  async findAll(user: JwtPayloadUser, query: ProcurementQueryDto) {
    const tenantId = requireTenantId(user);
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where: Prisma.ProcurementWhereInput = {
      tenantId,
      ...(query.status ? { status: query.status } : {}),
      ...(query.search
        ? {
            procurementNumber: {
              contains: query.search,
              mode: 'insensitive',
            },
          }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.procurement.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          supplier: { select: { id: true, name: true } },
          centralBranch: { select: { id: true, name: true, code: true } },
          _count: { select: { items: true } },
        },
      }),
      this.prisma.procurement.count({ where }),
    ]);

    return {
      items,
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async findOne(user: JwtPayloadUser, id: string) {
    const row = await this.prisma.procurement.findFirst({
      where: { id, tenantId: requireTenantId(user) },
      include: this.includeDetail(),
    });
    if (!row) throw new NotFoundException('Procurement not found');
    return row;
  }

  async complete(user: JwtPayloadUser, id: string) {
    this.assertCanManage(user);
    const tenantId = requireTenantId(user);
    const procurement = await this.findOne(user, id);
    if (procurement.status !== 'DRAFT') {
      throw new BadRequestException('Hanya pengadaan DRAFT yang dapat diselesaikan');
    }

    await this.prisma.$transaction(async (tx) => {
      for (const item of procurement.items) {
        let batchId: string | null = null;
        if (item.batchNumber) {
          let batch = await tx.medicineBatch.findFirst({
            where: {
              medicineId: item.medicineId,
              batchNumber: item.batchNumber,
            },
          });
          if (!batch) {
            batch = await tx.medicineBatch.create({
              data: {
                medicineId: item.medicineId,
                batchNumber: item.batchNumber,
                expiredDate: item.expiredDate,
                buyPrice: item.buyPrice,
                sellPrice: item.sellPrice,
              },
            });
          }
          batchId = batch.id;
        }

        const centralBranch = await loadBranchForStock(
          tx,
          tenantId,
          procurement.centralBranchId,
        );
        const inboundLocationId = await resolveInboundLocationId(
          tx,
          centralBranch,
        );

        let stock = await tx.stock.findFirst({
          where: {
            tenantId,
            branchId: procurement.centralBranchId,
            locationId: inboundLocationId,
            medicineId: item.medicineId,
            batchId,
          },
          include: { medicine: { select: { name: true, minStock: true } } },
        });

        if (!stock) {
          stock = await findOrCreateStockRow(tx, {
            tenantId,
            branchId: procurement.centralBranchId,
            locationId: inboundLocationId,
            medicineId: item.medicineId,
            batchId,
            initialQuantity: item.quantity,
          });
        } else {
          await tx.$queryRaw`
            SELECT id FROM stocks WHERE id = ${stock.id}::uuid FOR UPDATE
          `;
          stock = await tx.stock.update({
            where: { id: stock.id },
            data: { quantity: { increment: item.quantity } },
            include: { medicine: { select: { name: true, minStock: true } } },
          });
        }

        await tx.stockMovement.create({
          data: {
            tenantId,
            branchId: procurement.centralBranchId,
            medicineId: item.medicineId,
            batchId: stock.batchId,
            movementType: 'PROCUREMENT',
            quantity: item.quantity,
            referenceType: 'PROCUREMENT',
            referenceId: procurement.id,
            notes: procurement.procurementNumber,
            createdById: user.sub,
          },
        });

        this.realtime.emitStockUpdated(tenantId, procurement.centralBranchId, {
          medicine_id: stock.medicineId,
          branch_id: procurement.centralBranchId,
          batch_id: stock.batchId,
          medicine_name: stock.medicine.name,
          quantity: stock.quantity,
          reserved_quantity: stock.reservedQuantity,
          available_quantity: this.available(
            stock.quantity,
            stock.reservedQuantity,
          ),
        });
      }

      await tx.procurement.update({
        where: { id: procurement.id },
        data: { status: 'COMPLETED', completedAt: new Date() },
      });
    });

    return this.findOne(user, id);
  }

  async cancel(user: JwtPayloadUser, id: string) {
    this.assertCanManage(user);
    const procurement = await this.findOne(user, id);
    if (procurement.status !== 'DRAFT') {
      throw new BadRequestException('Hanya pengadaan DRAFT yang dapat dibatalkan');
    }
    return this.prisma.procurement.update({
      where: { id },
      data: { status: 'CANCELLED' },
      include: this.includeDetail(),
    });
  }

  private includeDetail() {
    return {
      supplier: { select: { id: true, name: true } },
      centralBranch: { select: { id: true, name: true, code: true } },
      items: {
        include: {
          medicine: { select: { id: true, name: true, unit: true, sku: true } },
        },
      },
    } satisfies Prisma.ProcurementInclude;
  }
}
