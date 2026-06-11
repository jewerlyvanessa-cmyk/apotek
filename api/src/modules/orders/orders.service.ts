import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { requireTenantId } from '../../common/utils/require-tenant-id';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { JwtPayloadUser } from '../../common/decorators/current-user.decorator';
import { AuditLogsService } from '../audit-logs/audit-logs.service';
import { CustomersService } from '../customers/customers.service';
import { RealtimeService } from '../realtime/realtime.service';
import {
  assertBranchAccess,
  canCancelOrder,
  isTenantWideUser,
  resolveBranchScopeForList,
} from '../../common/utils/branch-scope.util';
import { AppRole } from '../../common/constants/app-roles';
import { getSellableLocationIds } from '../../common/utils/stock-location.util';
import { userHasAnyRole, userHasRole } from '../../common/utils/user-roles.util';
import { ApprovePharmacyDto } from './dto/approve-pharmacy.dto';
import { CreateOrderDto } from './dto/create-order.dto';
import {
  assertPrescriptionComplete,
  resolvePrescription,
} from './dto/prescription.dto';
import { OrderQueryDto } from './dto/order-query.dto';
import { RefundOrderDto } from './dto/refund-order.dto';
import { UpdateOrderDto } from './dto/update-order.dto';

const orderListInclude = {
  customer: { select: { id: true, name: true, phone: true } },
  branch: { select: { id: true, name: true } },
  items: {
    include: { medicine: { select: { id: true, name: true } } },
  },
  servedBy: { select: { id: true, fullName: true } },
} as Prisma.OrderInclude;

const orderDetailInclude = {
  customer: { select: { id: true, name: true, phone: true, email: true } },
  items: {
    include: {
      medicine: {
        select: {
          id: true,
          name: true,
          unit: true,
          barcode: true,
          productType: {
            select: { id: true, code: true, name: true, allowsPrescription: true },
          },
          requiresPrescription: true,
        },
      },
      batch: { select: { batchNumber: true } },
    },
  },
  payments: true,
  servedBy: { select: { id: true, fullName: true } },
  cashier: { select: { id: true, fullName: true } },
} as Prisma.OrderInclude;

type OrderWithItems = Prisma.OrderGetPayload<{
  include: { items: true };
}>;

type OrderReservationPayload = {
  branchId: string;
  items: Array<{
    medicineId: string;
    batchId: string | null;
    quantity: number;
  }>;
};

@Injectable()
export class OrdersService {
  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeService,
    private customers: CustomersService,
    private auditLogs: AuditLogsService,
  ) {}

  private available(quantity: number, reserved: number) {
    return quantity - reserved;
  }

  private normalizeBranchCode(
    code: string | null | undefined,
    branchId: string,
  ): string {
    const trimmed = code?.trim();
    if (trimmed) {
      return trimmed.toUpperCase().replace(/[^A-Z0-9_-]/g, '');
    }
    return branchId.replace(/-/g, '').slice(0, 6).toUpperCase();
  }

  private async generateOrderNumber(
    tx: Prisma.TransactionClient,
    tenantId: string,
    branchId: string,
  ) {
    const branch = await tx.branch.findFirst({
      where: { id: branchId, tenantId },
      select: { code: true },
    });
    if (!branch) throw new NotFoundException('Branch not found');

    const branchCode = this.normalizeBranchCode(branch.code, branchId);
    const today = new Date();
    const datePart = `${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;
    const prefix = `${branchCode}-${datePart}`;
    const lockKey = `order:${tenantId}:${branchId}:${datePart}`;
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${lockKey}))`;

    const count = await tx.order.count({
      where: {
        tenantId,
        branchId,
        orderNumber: { startsWith: prefix },
      },
    });
    return `${prefix}-${String(count + 1).padStart(3, '0')}`;
  }

  async create(user: JwtPayloadUser, dto: CreateOrderDto) {
    const branchId = user.branchId;
    if (!branchId) {
      throw new BadRequestException('branch_id is required for orders');
    }

    const result = await this.prisma.$transaction(async (tx) => {
      let needsPharmacyReview =
        !!dto.has_prescription || !!dto.prescription || !!dto.prescription_notes?.trim();

      const prescriptionOrderHint =
        !!dto.has_prescription ||
        !!dto.prescription ||
        !!dto.prescription_notes?.trim();

      const { lineItems, subtotal, needsPharmacyReview: fromItems } =
        await this.buildLineItems(tx, user, branchId, dto.items, {
          prescriptionOrder: prescriptionOrderHint,
        });
      needsPharmacyReview = needsPharmacyReview || fromItems;

      const rx = resolvePrescription(dto.prescription, dto.prescription_notes);
      assertPrescriptionComplete(rx, needsPharmacyReview);

      const orderNumber = await this.generateOrderNumber(
        tx,
        requireTenantId(user),
        branchId,
      );

      const tenantId = requireTenantId(user);
      const customer = await this.customers.resolveForOrder(tenantId, {
        customer_id: dto.customer_id,
        customer_name: dto.customer_name,
        customer_phone: dto.customer_phone,
      }, tx);

      const order = await tx.order.create({
        data: {
          tenantId,
          branchId,
          orderNumber,
          customerId: customer?.id,
          customerName: customer?.name ?? (dto.customer_name?.trim() || null),
          prescriptionNotes: rx.prescriptionNotes,
          prescriptionNumber: rx.prescriptionNumber,
          prescriptionDate: rx.prescriptionDate,
          doctorName: rx.doctorName,
          patientName: rx.patientName,
          patientAge: rx.patientAge,
          prescriptionInstructions: rx.prescriptionInstructions,
          status: needsPharmacyReview ? 'PENDING_PHARMACY' : 'WAITING_PAYMENT',
          subtotal,
          discount: 0,
          tax: 0,
          total: subtotal,
          servedById: user.sub,
          items: {
            create: lineItems.map((li) => ({
              medicineId: li.medicineId,
              batchId: li.batchId,
              quantity: li.quantity,
              price: li.price,
              subtotal: li.subtotal,
              notes: li.notes,
            })),
          },
        } as Prisma.OrderUncheckedCreateInput,
        include: {
          items: {
            include: {
              medicine: {
                select: {
                  id: true,
                  name: true,
                  unit: true,
                  productType: {
            select: { id: true, code: true, name: true, allowsPrescription: true },
          },
                  requiresPrescription: true,
                },
              },
            },
          },
        },
      });

      return order;
    });

    this.realtime.emitOrderCreated(requireTenantId(user), branchId!, {
      order_id: result.id,
      order_number: result.orderNumber,
      status: result.status,
      total: Number(result.total),
      customer_name: result.customerName,
    });

    return result;
  }

  async findAll(user: JwtPayloadUser, query: OrderQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;
    const { branchId } = resolveBranchScopeForList(user, query.branch_id);

    const createdAtFilter = (() => {
      if (!query.date_from && !query.date_to) return undefined;
      const from = query.date_from ? new Date(query.date_from) : undefined;
      const to = query.date_to ? new Date(query.date_to) : undefined;
      if (from) from.setHours(0, 0, 0, 0);
      if (to) to.setHours(23, 59, 59, 999);
      return {
        ...(from ? { gte: from } : {}),
        ...(to ? { lte: to } : {}),
      };
    })();

    const where: Prisma.OrderWhereInput = {
      tenantId: requireTenantId(user),
      ...(branchId ? { branchId } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(query.mine ? { servedById: user.sub } : {}),
      ...(query.reviewed_mine
        ? {
            pharmacistApprovedById: user.sub,
            pharmacistApprovedAt: { not: null },
          }
        : {}),
      ...(createdAtFilter
        ? query.reviewed_mine
          ? { pharmacistApprovedAt: createdAtFilter }
          : { createdAt: createdAtFilter }
        : {}),
      ...(query.search
        ? {
            OR: [
              { orderNumber: { contains: query.search, mode: 'insensitive' } },
              { customerName: { contains: query.search, mode: 'insensitive' } },
              {
                customer: {
                  name: {
                    contains: query.search,
                    mode: Prisma.QueryMode.insensitive,
                  },
                },
              },
            ],
          }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.order.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: orderListInclude,
      }),
      this.prisma.order.count({ where }),
    ]);

    return {
      items,
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async findOne(user: JwtPayloadUser, id: string): Promise<OrderWithItems> {
    const order = await this.prisma.order.findFirst({
      where: { id, tenantId: requireTenantId(user) },
      include: orderDetailInclude,
    });
    if (!order) throw new NotFoundException('Order not found');
    assertBranchAccess(user, order.branchId);
    return order;
  }

  async approvePharmacy(user: JwtPayloadUser, id: string, dto: ApprovePharmacyDto) {
    if (!userHasRole(user, AppRole.PHARMACIST) && !isTenantWideUser(user)) {
      throw new ForbiddenException('Hanya apoteker yang dapat menyetujui telaah farmasi');
    }

    const order = await this.findOne(user, id);
    if (order.status !== 'PENDING_PHARMACY') {
      throw new BadRequestException('Order tidak menunggu telaah apoteker');
    }

    const updated = await this.prisma.order.update({
      where: { id },
      data: {
        status: 'WAITING_PAYMENT',
        pharmacistApprovedById: user.sub,
        pharmacistApprovedAt: new Date(),
        pharmacistNotes: dto.pharmacist_notes?.trim() || null,
      } as Prisma.OrderUncheckedUpdateInput,
    });

    this.realtime.emitOrderUpdated(requireTenantId(user), order.branchId, {
      order_id: updated.id,
      order_number: updated.orderNumber,
      status: updated.status,
      total: Number(updated.total),
      customer_name: updated.customerName,
    });

    return updated;
  }

  async update(user: JwtPayloadUser, id: string, dto: UpdateOrderDto) {
    const existing = await this.findOne(user, id);
    this.assertCanEditOrder(user, existing);

    const result = await this.prisma.$transaction(async (tx) => {
      await this.releaseOrderReservations(
        tx,
        user,
        this.toReservationPayload(existing),
      );
      await tx.orderItem.deleteMany({ where: { orderId: id } });

      const prescriptionOrderHint =
        !!dto.has_prescription ||
        !!dto.prescription ||
        !!dto.prescription_notes?.trim() ||
        existing.status === 'PENDING_PHARMACY';

      const { lineItems, subtotal } = await this.buildLineItems(
        tx,
        user,
        existing.branchId,
        dto.items,
        { prescriptionOrder: prescriptionOrderHint },
      );

      const tenantId = requireTenantId(user);
      const customer = await this.customers.resolveForOrder(
        tenantId,
        {
          customer_id: dto.customer_id,
          customer_name: dto.customer_name,
          customer_phone: dto.customer_phone,
        },
        tx,
      );

      return tx.order.update({
        where: { id },
        data: {
          customerId: customer?.id,
          customerName: customer?.name ?? (dto.customer_name?.trim() || null),
          subtotal,
          discount: 0,
          tax: 0,
          total: subtotal,
          items: {
            create: lineItems.map((li) => ({
              medicineId: li.medicineId,
              batchId: li.batchId,
              quantity: li.quantity,
              price: li.price,
              subtotal: li.subtotal,
              notes: li.notes,
            })),
          },
        } as Prisma.OrderUncheckedUpdateInput,
        include: {
          items: {
            include: {
              medicine: {
                select: {
                  id: true,
                  name: true,
                  unit: true,
                  productType: {
            select: { id: true, code: true, name: true, allowsPrescription: true },
          },
                  requiresPrescription: true,
                },
              },
            },
          },
        },
      });
    });

    this.realtime.emitOrderUpdated(requireTenantId(user), existing.branchId, {
      order_id: result.id,
      order_number: result.orderNumber,
      status: result.status,
      total: Number(result.total),
      customer_name: result.customerName,
    });

    return result;
  }

  async cancel(user: JwtPayloadUser, id: string) {
    const order = await this.findOne(user, id);
    if (!canCancelOrder(user, order)) {
      throw new ForbiddenException('Tidak diizinkan membatalkan order ini');
    }

    await this.prisma.$transaction(async (tx) => {
      await this.releaseOrderReservations(
        tx,
        user,
        this.toReservationPayload(order),
      );
      await tx.order.update({
        where: { id },
        data: { status: 'CANCELLED' },
      });
    });

    this.realtime.emitOrderUpdated(requireTenantId(user), order.branchId, {
      order_id: id,
      status: 'CANCELLED',
    });

    return { id, status: 'CANCELLED' };
  }

  async refund(user: JwtPayloadUser, id: string, dto: RefundOrderDto) {
    if (
      !userHasAnyRole(user, [
        AppRole.CASHIER,
        AppRole.MANAGER,
        AppRole.OWNER,
      ])
    ) {
      throw new ForbiddenException('Tidak diizinkan memproses retur');
    }

    const order = await this.findOne(user, id);
    if (order.status !== 'PAID') {
      throw new BadRequestException('Hanya order lunas yang dapat diretur');
    }

    await this.prisma.$transaction(async (tx) => {
      for (const item of order.items) {
        let remaining = item.quantity;

        const stocks = await tx.stock.findMany({
          where: {
            tenantId: requireTenantId(user),
            branchId: order.branchId,
            medicineId: item.medicineId,
            batchId: item.batchId,
          },
        });

        for (const stock of stocks) {
          if (remaining <= 0) break;

          await tx.$queryRaw`
            SELECT id FROM stocks WHERE id = ${stock.id}::uuid FOR UPDATE
          `;

          const addQty = remaining;
          const updated = await tx.stock.update({
            where: { id: stock.id },
            data: { quantity: { increment: addQty } },
            include: { medicine: { select: { name: true, minStock: true } } },
          });

          await tx.stockMovement.create({
            data: {
              tenantId: requireTenantId(user),
              branchId: order.branchId,
              medicineId: item.medicineId,
              batchId: item.batchId,
              movementType: 'REFUND',
              quantity: addQty,
              referenceType: 'ORDER',
              referenceId: order.id,
              createdById: user.sub,
            },
          });

          this.realtime.emitStockUpdated(
            requireTenantId(user),
            order.branchId,
            {
              medicine_id: updated.medicineId,
              branch_id: order.branchId,
              batch_id: updated.batchId,
              medicine_name: updated.medicine.name,
              quantity: updated.quantity,
              reserved_quantity: updated.reservedQuantity,
              available_quantity: this.available(
                updated.quantity,
                updated.reservedQuantity,
              ),
            },
          );

          remaining -= addQty;
        }
      }

      await tx.payment.create({
        data: {
          orderId: order.id,
          paymentMethod: 'REFUND',
          amount: -Number(order.total),
          referenceNumber: dto.reason?.trim() || 'RETUR',
          paidById: user.sub,
        },
      });

      await tx.order.update({
        where: { id: order.id },
        data: { status: 'REFUNDED' },
      });
    });

    this.realtime.emitOrderUpdated(requireTenantId(user), order.branchId, {
      order_id: order.id,
      status: 'REFUNDED',
    });

    await this.auditLogs.log({
      tenantId: requireTenantId(user),
      userId: user.sub,
      module: 'ORDERS',
      action: 'REFUND',
      referenceId: order.id,
      newData: {
        order_number: order.orderNumber,
        reason: dto.reason?.trim() || null,
        total: Number(order.total),
      },
    });

    return {
      id: order.id,
      order_number: order.orderNumber,
      status: 'REFUNDED',
    };
  }

  private assertCanEditOrder(
    user: JwtPayloadUser,
    order: { status: string; servedById: string | null },
  ) {
    if (!['WAITING_PAYMENT', 'PENDING_PHARMACY'].includes(order.status)) {
      throw new BadRequestException('Order tidak dapat diedit');
    }
    if (isTenantWideUser(user)) return;
    if (userHasRole(user, AppRole.MANAGER) && user.branchId) return;
    if (order.servedById === user.sub) return;
    throw new ForbiddenException('Anda hanya dapat mengedit order sendiri');
  }

  private toReservationPayload(order: OrderWithItems): OrderReservationPayload {
    return {
      branchId: order.branchId,
      items: order.items.map((item) => ({
        medicineId: item.medicineId,
        batchId: item.batchId,
        quantity: item.quantity,
      })),
    };
  }

  private async releaseOrderReservations(
    tx: Prisma.TransactionClient,
    user: JwtPayloadUser,
    order: OrderReservationPayload,
  ) {
    const tenantId = requireTenantId(user);
    for (const item of order.items) {
      const stocks = await tx.stock.findMany({
        where: {
          tenantId,
          branchId: order.branchId,
          medicineId: item.medicineId,
          batchId: item.batchId,
        },
      });

      let remaining = item.quantity;
      for (const stock of stocks) {
        if (remaining <= 0) break;
        await tx.$queryRaw`
          SELECT id FROM stocks WHERE id = ${stock.id}::uuid FOR UPDATE
        `;
        const fresh = await tx.stock.findUnique({ where: { id: stock.id } });
        if (!fresh) continue;
        const release = Math.min(remaining, fresh.reservedQuantity);
        if (release <= 0) continue;

        const updated = await tx.stock.update({
          where: { id: stock.id },
          data: { reservedQuantity: { decrement: release } },
          include: { medicine: { select: { name: true, minStock: true } } },
        });

        this.realtime.emitStockUpdated(tenantId, order.branchId, {
          medicine_id: updated.medicineId,
          branch_id: order.branchId,
          batch_id: updated.batchId,
          medicine_name: updated.medicine.name,
          quantity: updated.quantity,
          reserved_quantity: updated.reservedQuantity,
          available_quantity: this.available(
            updated.quantity,
            updated.reservedQuantity,
          ),
        });
        remaining -= release;
      }
    }
  }

  private async buildLineItems(
    tx: Prisma.TransactionClient,
    user: JwtPayloadUser,
    branchId: string,
    items: CreateOrderDto['items'],
    options?: { prescriptionOrder?: boolean },
  ) {
    const tenantId = requireTenantId(user);
    const branch = await tx.branch.findFirst({
      where: { id: branchId, tenantId },
    });
    if (!branch) throw new NotFoundException('Cabang tidak ditemukan');
    const sellableLocationIds = await getSellableLocationIds(tx, branch);

    const lineItems: Array<{
      medicineId: string;
      batchId: string | null;
      quantity: number;
      price: Prisma.Decimal;
      subtotal: Prisma.Decimal;
      notes: string | null;
    }> = [];
    let needsPharmacyReview = false;

    const isPrescriptionOrder = !!options?.prescriptionOrder;

    for (const item of items) {
      const medicine = await tx.medicine.findFirst({
        where: { id: item.medicine_id, tenantId, isActive: true },
      });
      if (!medicine) {
        throw new NotFoundException(`Medicine ${item.medicine_id} not found`);
      }

      const usage = item.usage_instructions?.trim() || null;
      if (isPrescriptionOrder && !usage) {
        throw new BadRequestException(
          `Petunjuk penggunaan wajib untuk semua item order resep: ${medicine.name}`,
        );
      }

      const stocks = await tx.stock.findMany({
        where: {
          tenantId,
          branchId,
          medicineId: item.medicine_id,
          locationId: { in: sellableLocationIds },
        },
        orderBy: { updatedAt: 'asc' },
      });

      if (!stocks.length) throw new ConflictException('STOCK_NOT_ENOUGH');

      let remaining = item.quantity;
      const allocations: Array<{
        stockId: string;
        batchId: string | null;
        qty: number;
      }> = [];

      for (const stock of stocks) {
        if (remaining <= 0) break;

        await tx.$queryRaw`
          SELECT id FROM stocks WHERE id = ${stock.id}::uuid FOR UPDATE
        `;

        const fresh = await tx.stock.findUnique({ where: { id: stock.id } });
        if (!fresh) continue;

        const avail = this.available(fresh.quantity, fresh.reservedQuantity);
        if (avail <= 0) continue;

        const take = Math.min(remaining, avail);
        allocations.push({
          stockId: stock.id,
          batchId: stock.batchId,
          qty: take,
        });
        remaining -= take;
      }

      if (remaining > 0) throw new ConflictException('STOCK_NOT_ENOUGH');

      for (const alloc of allocations) {
        await tx.stock.update({
          where: { id: alloc.stockId },
          data: { reservedQuantity: { increment: alloc.qty } },
        });

        const updated = await tx.stock.findUnique({
          where: { id: alloc.stockId },
          include: { medicine: { select: { name: true, minStock: true } } },
        });

        if (updated) {
          this.realtime.emitStockUpdated(tenantId, branchId, {
            medicine_id: updated.medicineId,
            branch_id: branchId,
            batch_id: updated.batchId,
            medicine_name: updated.medicine.name,
            quantity: updated.quantity,
            reserved_quantity: updated.reservedQuantity,
            available_quantity: this.available(
              updated.quantity,
              updated.reservedQuantity,
            ),
          });
        }

        const price = medicine.sellPrice;
        const subtotal = new Prisma.Decimal(price.toString()).mul(alloc.qty);
        lineItems.push({
          medicineId: medicine.id,
          batchId: alloc.batchId,
          quantity: alloc.qty,
          price,
          subtotal,
          notes: usage,
        });
      }
    }

    const subtotal = lineItems.reduce(
      (sum, li) => sum.add(li.subtotal),
      new Prisma.Decimal(0),
    );

    if (isPrescriptionOrder) {
      needsPharmacyReview = true;
    }

    return { lineItems, subtotal, needsPharmacyReview };
  }
}
