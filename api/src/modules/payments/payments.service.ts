import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { requireTenantId } from '../../common/utils/require-tenant-id';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { JwtPayloadUser } from '../../common/decorators/current-user.decorator';
import { assertBranchAccess, isTenantWideUser } from '../../common/utils/branch-scope.util';
import { AuditLogRequestMeta, AuditLogsService } from '../audit-logs/audit-logs.service';
import { RedisCacheService } from '../../infrastructure/redis/redis.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeService } from '../realtime/realtime.service';
import { PayOrderDto } from './dto/pay-order.dto';
import {
  resolvePaymentExtras,
  resolvePaymentLines,
  ResolvedPaymentLine,
} from './payment-validation.util';
import { QrisProviderService } from './qris-provider.service';
import { PaymentQueryDto } from './dto/payment-query.dto';
import { randomUUID } from 'crypto';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class PaymentsService {
  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeService,
    private auditLogs: AuditLogsService,
    private cache: RedisCacheService,
    private config: ConfigService,
    private qrisProvider: QrisProviderService,
    private notifications: NotificationsService,
  ) {}

  private async notifyPaymentPush(params: {
    tenantId: string;
    payerId: string;
    orderNumber: string;
    amount: number;
  }) {
    const recipients = await this.prisma.user.findMany({
      where: {
        tenantId: params.tenantId,
        isActive: true,
        id: { not: params.payerId },
        role: { in: ['OWNER', 'MANAGER'] },
      },
      select: { id: true },
    });

    for (const r of recipients) {
      await this.notifications.sendToUser({
        tenantId: params.tenantId,
        userId: r.id,
        title: 'Pembayaran selesai',
        body: `${params.orderNumber} · Rp ${params.amount.toLocaleString('id-ID')}`,
        data: {
          type: 'payment',
          order_number: params.orderNumber,
          amount: String(params.amount),
        },
      });
    }
  }

  private available(quantity: number, reserved: number) {
    return quantity - reserved;
  }

  private async finalizePaidOrder(params: {
    user: JwtPayloadUser;
    orderId: string;
    paymentLines: ResolvedPaymentLine[];
    meta?: AuditLogRequestMeta;
  }) {
    const { user, orderId, paymentLines, meta } = params;
    const totalPaid = paymentLines.reduce((s, l) => s + l.amount, 0);

    const order = await this.prisma.order.findFirst({
      where: { id: orderId, tenantId: requireTenantId(user) },
      include: { items: true },
    });
    if (!order) throw new NotFoundException('Order not found');
    if (order.status === 'PENDING_PHARMACY') {
      throw new BadRequestException(
        'Order menunggu persetujuan apoteker sebelum pembayaran',
      );
    }
    if (order.status !== 'WAITING_PAYMENT' && order.status !== 'WAITING_QRIS') {
      throw new BadRequestException('Order is not waiting for payment');
    }

    const orderTotal = Number(order.total);
    if (Math.abs(totalPaid - orderTotal) > 0.01) {
      throw new BadRequestException(
        `Total pembayaran (${totalPaid}) harus sama dengan tagihan (${orderTotal})`,
      );
    }

    const branchId = user.branchId ?? order.branchId;
    if (!isTenantWideUser(user)) {
      assertBranchAccess(user, order.branchId);
    } else if (order.branchId !== branchId) {
      throw new BadRequestException('Cannot pay order from another branch');
    }

    const payment = await this.prisma.$transaction(async (tx) => {
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

          const fresh = await tx.stock.findUnique({
            where: { id: stock.id },
            include: { medicine: { select: { name: true, minStock: true } } },
          });
          if (!fresh) continue;

          const deduct = Math.min(remaining, fresh.reservedQuantity);
          if (deduct <= 0) continue;

          const updated = await tx.stock.update({
            where: { id: stock.id },
            data: {
              quantity: { decrement: deduct },
              reservedQuantity: { decrement: deduct },
            },
            include: { medicine: { select: { name: true, minStock: true } } },
          });

          await tx.stockMovement.create({
            data: {
              tenantId: requireTenantId(user),
              branchId: order.branchId,
              medicineId: item.medicineId,
              batchId: item.batchId,
              movementType: 'SALE',
              quantity: -deduct,
              referenceType: 'ORDER',
              referenceId: order.id,
              createdById: user.sub,
            },
          });

          this.realtime.emitStockUpdated(requireTenantId(user), order.branchId, {
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

          remaining -= deduct;
        }
      }

      let payments: Awaited<ReturnType<typeof tx.payment.create>>[] = [];
      if (order.status === 'WAITING_QRIS') {
        payments = await tx.payment.findMany({
          where: { orderId: order.id },
        });
      }
      if (payments.length === 0) {
        for (const line of paymentLines) {
          const pay = await tx.payment.create({
            data: {
              orderId: order.id,
              paymentMethod: line.paymentMethod,
              amount: line.amount,
              amountReceived: line.amountReceived ?? undefined,
              changeAmount: line.changeAmount ?? undefined,
              proofImageUrl: line.proofImageUrl ?? undefined,
              referenceNumber: line.referenceNumber,
              paidById: user.sub,
            },
          });
          payments.push(pay);
        }
      }

      await tx.order.update({
        where: { id: order.id },
        data: {
          status: 'PAID',
          cashierId: user.sub,
          paidAt: new Date(),
        },
      });

      return payments;
    });

    const primary = payment[0];
    this.realtime.emitPaymentCompleted(requireTenantId(user), order.branchId, {
      payment_id: primary.id,
      order_id: order.id,
      order_number: order.orderNumber,
      status: 'PAID',
      amount: totalPaid,
    });

    this.realtime.emitOrderUpdated(requireTenantId(user), order.branchId, {
      order_id: order.id,
      status: 'PAID',
    });

    await this.auditLogs.log({
      tenantId: requireTenantId(user),
      userId: user.sub,
      module: 'PAYMENTS',
      action: 'PAY_ORDER',
      referenceId: order.id,
      newData: {
        payment_ids: payment.map((p) => p.id),
        order_id: order.id,
        order_number: order.orderNumber,
        lines: paymentLines,
        total: totalPaid,
      },
      ...meta,
    });

    await this.cache.invalidateTags([`stocks:${requireTenantId(user)}:${order.branchId}`]);

    const tenantId = requireTenantId(user);
    this.notifyPaymentPush({
      tenantId,
      payerId: user.sub,
      orderNumber: order.orderNumber,
      amount: totalPaid,
    }).catch(() => undefined);

    return { payments: payment, order };
  }

  async pay(user: JwtPayloadUser, dto: PayOrderDto, meta?: AuditLogRequestMeta) {
    const lines = resolvePaymentLines(dto);
    const result = await this.finalizePaidOrder({
      user,
      orderId: dto.order_id,
      paymentLines: lines,
      meta,
    });
    const cashLine = lines.find((l) => l.paymentMethod === 'CASH');
    return {
      payment_id: result.payments[0].id,
      payment_ids: result.payments.map((p) => p.id),
      order_id: result.order.id,
      status: 'PAID',
      split_count: result.payments.length,
      amount_received: cashLine?.amountReceived ?? null,
      change_amount: cashLine?.changeAmount ?? null,
    };
  }

  async createQrisCharge(user: JwtPayloadUser, dto: PayOrderDto, meta?: AuditLogRequestMeta) {
    if (dto.payment_method !== 'QRIS') {
      throw new BadRequestException('payment_method must be QRIS');
    }
    if (dto.amount == null) {
      throw new BadRequestException('amount wajib untuk QRIS');
    }

    const order = await this.prisma.order.findFirst({
      where: { id: dto.order_id, tenantId: requireTenantId(user) },
      include: { items: true },
    });
    if (!order) throw new NotFoundException('Order not found');
    if (order.status !== 'WAITING_PAYMENT' && order.status !== 'WAITING_QRIS') {
      throw new BadRequestException('Order is not waiting for payment');
    }

    const reference = dto.reference_number ?? `QRIS-${randomUUID()}`;
    const charge = await this.qrisProvider.createCharge({
      reference,
      amount: dto.amount ?? 0,
      orderId: order.id,
      tenantId: requireTenantId(user),
    });
    const qrString = charge.qr_string;

    const payment = await this.prisma.payment.create({
      data: {
        orderId: order.id,
        paymentMethod: 'QRIS',
        amount: dto.amount,
        referenceNumber: charge.reference_number,
        paidById: user.sub,
      },
    });

    if (order.status !== 'WAITING_QRIS') {
      await this.prisma.order.update({
        where: { id: order.id },
        data: { status: 'WAITING_QRIS' },
      });
    }

    await this.auditLogs.log({
      tenantId: requireTenantId(user),
      userId: user.sub,
      module: 'PAYMENTS',
      action: 'CREATE_QRIS',
      referenceId: order.id,
      newData: {
        payment_id: payment.id,
        order_id: order.id,
        order_number: order.orderNumber,
        reference_number: reference,
      },
      ...meta,
    });

    return {
      payment_id: payment.id,
      order_id: order.id,
      status: 'WAITING_QRIS',
      qris: {
        reference_number: charge.reference_number,
        qr_string: qrString,
        provider: charge.provider,
      },
    };
  }

  async confirmQrisPaid(params: {
    tenantId: string;
    orderId: string;
    referenceNumber: string;
    amount: number;
  }) {
    // Minimal "system user" for audit trail
    const user: JwtPayloadUser = {
      sub: 'system',
      email: 'system@local',
      tenantId: params.tenantId,
      branchId: undefined,
      role: 'OWNER',
    };

    // Idempotency: if order already PAID, return ok
    const existing = await this.prisma.order.findFirst({
      where: { id: params.orderId, tenantId: params.tenantId },
    });
    if (!existing) throw new NotFoundException('Order not found');
    if (existing.status === 'PAID') {
      return { ok: true, status: 'PAID' };
    }

    const pendingPayment = await this.prisma.payment.findFirst({
      where: {
        orderId: params.orderId,
        referenceNumber: params.referenceNumber,
        paymentMethod: 'QRIS',
      },
      orderBy: { paidAt: 'desc' },
    });
    if (!pendingPayment) {
      throw new BadRequestException('Referensi QRIS tidak ditemukan');
    }

    const expectedAmount = Number(pendingPayment.amount);
    if (Math.abs(expectedAmount - params.amount) > 0.01) {
      throw new BadRequestException('Jumlah pembayaran QRIS tidak sesuai');
    }

    await this.finalizePaidOrder({
      user,
      orderId: params.orderId,
      paymentLines: [
        {
          paymentMethod: 'QRIS',
          amount: params.amount,
          amountReceived: null,
          changeAmount: null,
          proofImageUrl: null,
          referenceNumber: params.referenceNumber,
        },
      ],
      meta: { ipAddress: null, userAgent: 'qris-webhook' },
    });

    return { ok: true, status: 'PAID' };
  }

  async findAll(user: JwtPayloadUser, query: PaymentQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;
    const tenantId = requireTenantId(user);
    const branchId = query.branch_id ?? user.branchId;

    const paidAtFilter = (() => {
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

    const where = {
      ...(query.mine ? { paidById: user.sub } : {}),
      ...(paidAtFilter ? { paidAt: paidAtFilter } : {}),
      ...(query.payment_method
        ? { paymentMethod: query.payment_method.toUpperCase() }
        : {}),
      order: {
        tenantId,
        status: 'PAID',
        ...(branchId ? { branchId } : {}),
      },
    };

    const [items, total] = await Promise.all([
      this.prisma.payment.findMany({
        where,
        skip,
        take: limit,
        orderBy: { paidAt: 'desc' },
        include: {
          paidBy: { select: { id: true, fullName: true } },
          order: {
            select: {
              id: true,
              orderNumber: true,
              customerName: true,
              total: true,
              status: true,
              branchId: true,
            },
          },
        },
      }),
      this.prisma.payment.count({ where }),
    ]);

    return {
      items,
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async findOne(user: JwtPayloadUser, id: string) {
    const tenantId = requireTenantId(user);
    const payment = await this.prisma.payment.findFirst({
      where: {
        id,
        order: { tenantId },
      },
      include: {
        paidBy: { select: { id: true, fullName: true } },
        order: {
          include: {
            customer: { select: { id: true, name: true, phone: true } },
            items: {
              include: {
                medicine: { select: { id: true, name: true, unit: true } },
                batch: { select: { batchNumber: true } },
              },
            },
            servedBy: { select: { id: true, fullName: true } },
            cashier: { select: { id: true, fullName: true } },
          },
        },
      },
    });
    if (!payment) throw new NotFoundException('Payment not found');

    const branchId = user.branchId;
    if (
      branchId &&
      payment.order.branchId !== branchId &&
      !isTenantWideUser(user)
    ) {
      throw new ForbiddenException('Payment not in your branch');
    }

    return payment;
  }
}
