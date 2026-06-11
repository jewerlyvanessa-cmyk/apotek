import { Injectable } from '@nestjs/common';
import { requireTenantId } from '../../common/utils/require-tenant-id';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { JwtPayloadUser } from '../../common/decorators/current-user.decorator';
import { resolveBranchScopeForList } from '../../common/utils/branch-scope.util';
import { ReportRangeDto } from './dto/report-range.dto';
import { TopMedicinesDto } from './dto/top-medicines.dto';

function startOfDay(d: Date) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0);
}

function endOfDay(d: Date) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59, 999);
}

function resolveRange(query?: ReportRangeDto) {
  const now = new Date();
  const from = query?.date_from ? new Date(query.date_from) : now;
  const to = query?.date_to ? new Date(query.date_to) : from;
  return { from: startOfDay(from), to: endOfDay(to) };
}

@Injectable()
export class ReportsService {
  constructor(private prisma: PrismaService) {}

  /** User cabang hanya boleh filter cabang sendiri. */
  private resolveReportBranchId(
    user: JwtPayloadUser,
    queryBranchId?: string,
  ): string | undefined {
    const { branchId } = resolveBranchScopeForList(user, queryBranchId);
    return branchId;
  }

  async dashboard(user: JwtPayloadUser, query?: ReportRangeDto) {
    const today = resolveRange(
      query?.date_from || query?.date_to
        ? query
        : { date_from: new Date().toISOString() },
    );

    const branchId = this.resolveReportBranchId(user, query?.branch_id);

    const [todaySalesAgg, todayOrdersCount] = await Promise.all([
      this.prisma.payment.aggregate({
        where: {
          order: {
            tenantId: requireTenantId(user),
            ...(branchId ? { branchId } : {}),
            status: 'PAID',
            paidAt: { gte: today.from, lte: today.to },
          },
        },
        _sum: { amount: true },
      }),
      this.prisma.order.count({
        where: {
          tenantId: requireTenantId(user),
          ...(branchId ? { branchId } : {}),
          status: 'PAID',
          paidAt: { gte: today.from, lte: today.to },
        },
      }),
    ]);

    const lowStockAccurate = await this.prisma.$queryRaw<
      Array<{ low_stock: bigint }>
    >`
      SELECT COUNT(*)::bigint AS low_stock
      FROM stocks s
      JOIN medicines m ON m.id = s.medicine_id
      WHERE s.tenant_id = ${requireTenantId(user)}::uuid
        AND m.min_stock > 0
        ${branchId ? Prisma.sql`AND s.branch_id = ${branchId}::uuid` : Prisma.empty}
        AND (s.quantity - s.reserved_quantity) <= m.min_stock
    `;

    return {
      today_sales: Number(todaySalesAgg._sum.amount ?? 0),
      today_orders: todayOrdersCount,
      low_stock: Number(lowStockAccurate?.[0]?.low_stock ?? 0),
    };
  }

  async sales(user: JwtPayloadUser, query: ReportRangeDto) {
    const range = resolveRange(query);
    const branchId = this.resolveReportBranchId(user, query.branch_id);

    const where: Prisma.OrderWhereInput = {
      tenantId: requireTenantId(user),
      status: 'PAID',
      paidAt: { gte: range.from, lte: range.to },
      ...(branchId ? { branchId } : {}),
    };

    const paymentWhere = {
      order: where,
    };

    const [salesAgg, paymentAgg, orders] = await Promise.all([
      this.prisma.order.aggregate({
        where,
        _sum: { total: true, subtotal: true, discount: true, tax: true },
        _count: { _all: true },
      }),
      this.prisma.payment.aggregate({
        where: paymentWhere,
        _sum: { amount: true },
      }),
      this.prisma.order.findMany({
        where,
        orderBy: { paidAt: 'asc' },
        select: {
          id: true,
          orderNumber: true,
          branchId: true,
          total: true,
          paidAt: true,
        },
      }),
    ]);

    return {
      range: { from: range.from.toISOString(), to: range.to.toISOString() },
      branch_id: branchId ?? null,
      totals: {
        orders: salesAgg._count._all,
        subtotal: Number(salesAgg._sum.subtotal ?? 0),
        discount: Number(salesAgg._sum.discount ?? 0),
        tax: Number(salesAgg._sum.tax ?? 0),
        /** Selaras dengan dashboard (jumlah pembayaran aktual). */
        total: Number(paymentAgg._sum.amount ?? 0),
        order_total: Number(salesAgg._sum.total ?? 0),
      },
      orders: orders.map((o) => ({
        ...o,
        total: Number(o.total),
      })),
    };
  }

  async topMedicines(user: JwtPayloadUser, query: TopMedicinesDto) {
    const range = resolveRange(query);
    const branchId = this.resolveReportBranchId(user, query.branch_id);

    const limit = query.limit ?? 10;
    const orderBy = query.order_by ?? 'qty';

    const grouped = await this.prisma.orderItem.groupBy({
      by: ['medicineId'],
      where: {
        order: {
          tenantId: requireTenantId(user),
          status: 'PAID',
          paidAt: { gte: range.from, lte: range.to },
          ...(branchId ? { branchId } : {}),
        },
      },
      _sum: { quantity: true, subtotal: true },
      orderBy:
        orderBy === 'subtotal'
          ? { _sum: { subtotal: 'desc' } }
          : { _sum: { quantity: 'desc' } },
      take: limit,
    });

    const medicineIds = grouped.map((g) => g.medicineId);
    const medicines = await this.prisma.medicine.findMany({
      where: { id: { in: medicineIds }, tenantId: requireTenantId(user) },
      select: { id: true, name: true, unit: true },
    });
    const byId = new Map(medicines.map((m) => [m.id, m]));

    return {
      range: { from: range.from.toISOString(), to: range.to.toISOString() },
      branch_id: branchId ?? null,
      items: grouped.map((g) => ({
        medicine_id: g.medicineId,
        medicine_name: byId.get(g.medicineId)?.name ?? '-',
        unit: byId.get(g.medicineId)?.unit ?? null,
        qty: g._sum.quantity ?? 0,
        subtotal: Number(g._sum.subtotal ?? 0),
      })),
    };
  }

  async lowStock(user: JwtPayloadUser, query: ReportRangeDto) {
    const branchId = this.resolveReportBranchId(user, query.branch_id);

    const rows = await this.prisma.$queryRaw<
      Array<{
        branch_id: string;
        medicine_id: string;
        medicine_name: string;
        min_stock: number;
        quantity: number;
        reserved_quantity: number;
        available_quantity: number;
      }>
    >`
      SELECT
        s.branch_id::text AS branch_id,
        s.medicine_id::text AS medicine_id,
        m.name AS medicine_name,
        m.min_stock::int AS min_stock,
        s.quantity::int AS quantity,
        s.reserved_quantity::int AS reserved_quantity,
        (s.quantity - s.reserved_quantity)::int AS available_quantity
      FROM stocks s
      JOIN medicines m ON m.id = s.medicine_id
      WHERE s.tenant_id = ${requireTenantId(user)}::uuid
        ${branchId ? Prisma.sql`AND s.branch_id = ${branchId}::uuid` : Prisma.empty}
        AND m.min_stock > 0
        AND (s.quantity - s.reserved_quantity) <= m.min_stock
      ORDER BY available_quantity ASC, m.name ASC
      LIMIT 100
    `;

    return {
      branch_id: branchId ?? null,
      items: rows,
    };
  }

  async expired(user: JwtPayloadUser, query: ReportRangeDto) {
    const branchId = this.resolveReportBranchId(user, query.branch_id);

    const today = startOfDay(new Date());

    const rows = await this.prisma.$queryRaw<
      Array<{
        branch_id: string;
        medicine_id: string;
        medicine_name: string;
        batch_id: string;
        batch_number: string;
        expired_date: string;
        quantity: number;
      }>
    >`
      SELECT
        s.branch_id::text AS branch_id,
        m.id::text AS medicine_id,
        m.name AS medicine_name,
        b.id::text AS batch_id,
        b.batch_number AS batch_number,
        b.expired_date::text AS expired_date,
        s.quantity::int AS quantity
      FROM stocks s
      JOIN medicine_batches b ON b.id = s.batch_id
      JOIN medicines m ON m.id = s.medicine_id
      WHERE s.tenant_id = ${requireTenantId(user)}::uuid
        ${branchId ? Prisma.sql`AND s.branch_id = ${branchId}::uuid` : Prisma.empty}
        AND s.quantity > 0
        AND b.expired_date IS NOT NULL
        AND b.expired_date <= ${today}::date
      ORDER BY b.expired_date ASC, m.name ASC
      LIMIT 100
    `;

    return {
      branch_id: branchId ?? null,
      items: rows,
    };
  }

  async profitLoss(user: JwtPayloadUser, query: ReportRangeDto) {
    const range = resolveRange(query);
    const branchId = this.resolveReportBranchId(user, query.branch_id);

    const items = await this.prisma.orderItem.findMany({
      where: {
        order: {
          tenantId: requireTenantId(user),
          status: 'PAID',
          paidAt: { gte: range.from, lte: range.to },
          ...(branchId ? { branchId } : {}),
        },
      },
      include: {
        medicine: {
          select: { id: true, name: true, buyPrice: true, unit: true },
        },
        batch: { select: { buyPrice: true } },
      },
    });

    const grouped = new Map<
      string,
      {
        medicine_id: string;
        medicine_name: string;
        unit: string | null;
        qty: number;
        revenue: number;
        cost: number;
      }
    >();

    let revenue = 0;
    let cost = 0;

    for (const item of items) {
      const unitCost = Number(
        item.batch?.buyPrice ?? item.medicine.buyPrice ?? 0,
      );
      const rev = Number(item.subtotal);
      const c = unitCost * item.quantity;
      revenue += rev;
      cost += c;

      const existing = grouped.get(item.medicineId);
      if (existing) {
        existing.qty += item.quantity;
        existing.revenue += rev;
        existing.cost += c;
      } else {
        grouped.set(item.medicineId, {
          medicine_id: item.medicineId,
          medicine_name: item.medicine.name,
          unit: item.medicine.unit,
          qty: item.quantity,
          revenue: rev,
          cost: c,
        });
      }
    }

    const grossProfit = revenue - cost;
    const marginPercent =
      revenue > 0 ? Math.round((grossProfit / revenue) * 10000) / 100 : 0;

    return {
      range: { from: range.from.toISOString(), to: range.to.toISOString() },
      branch_id: branchId ?? null,
      totals: {
        revenue,
        cost,
        gross_profit: grossProfit,
        margin_percent: marginPercent,
      },
      items: [...grouped.values()]
        .map((row) => ({
          ...row,
          gross_profit: row.revenue - row.cost,
        }))
        .sort((a, b) => b.gross_profit - a.gross_profit),
    };
  }
}

