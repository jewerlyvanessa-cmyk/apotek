import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AppRole } from '../../common/constants/app-roles';
import { userHasAnyRole } from '../../common/utils/user-roles.util';
import { Prisma } from '@prisma/client';
import { JwtPayloadUser } from '../../common/decorators/current-user.decorator';
import { resolveBranchIdForFilter } from '../../common/utils/branch-scope.util';
import { requireTenantId } from '../../common/utils/require-tenant-id';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { CashEntryQueryDto } from './dto/cash-entry-query.dto';
import { CreateCashEntryDto } from './dto/create-cash-entry.dto';

function startOfDay(d: Date) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0);
}

function endOfDay(d: Date) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59, 999);
}

function parseEntryDate(raw?: string): Date {
  if (!raw?.trim()) {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate());
  }
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(raw.trim());
  if (!m) {
    throw new BadRequestException('entry_date harus format YYYY-MM-DD');
  }
  const d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  if (Number.isNaN(d.getTime())) {
    throw new BadRequestException('entry_date tidak valid');
  }
  return d;
}

function resolveRange(query?: CashEntryQueryDto) {
  const now = new Date();
  const from = query?.date_from ? new Date(query.date_from) : now;
  const to = query?.date_to ? new Date(query.date_to) : from;
  return { from: startOfDay(from), to: endOfDay(to) };
}

const entrySelect = {
  id: true,
  tenantId: true,
  branchId: true,
  entryDate: true,
  type: true,
  category: true,
  amount: true,
  notes: true,
  createdAt: true,
  createdBy: {
    select: { id: true, fullName: true, email: true },
  },
  branch: { select: { id: true, name: true, code: true } },
} satisfies Prisma.CashEntrySelect;

@Injectable()
export class CashEntriesService {
  constructor(private prisma: PrismaService) {}

  async create(user: JwtPayloadUser, dto: CreateCashEntryDto) {
    const tenantId = requireTenantId(user);
    const branchId = resolveBranchIdForFilter(user, dto.branch_id);
    const entryDate = parseEntryDate(dto.entry_date);

    return this.prisma.cashEntry.create({
      data: {
        tenantId,
        branchId,
        entryDate,
        type: dto.type,
        category: dto.category?.trim() || null,
        amount: dto.amount,
        notes: dto.notes?.trim() || null,
        createdById: user.sub,
      },
      select: entrySelect,
    });
  }

  async findAll(user: JwtPayloadUser, query: CashEntryQueryDto) {
    const tenantId = requireTenantId(user);
    const branchId = resolveBranchIdForFilter(user, query.branch_id);
    const range = resolveRange(query);
    const page = query.page ?? 1;
    const limit = query.limit ?? 50;
    const skip = (page - 1) * limit;

    const where: Prisma.CashEntryWhereInput = {
      tenantId,
      branchId,
      entryDate: {
        gte: range.from,
        lte: range.to,
      },
    };

    const [items, total] = await Promise.all([
      this.prisma.cashEntry.findMany({
        where,
        orderBy: [{ entryDate: 'desc' }, { createdAt: 'desc' }],
        skip,
        take: limit,
        select: entrySelect,
      }),
      this.prisma.cashEntry.count({ where }),
    ]);

    return {
      items,
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async summary(user: JwtPayloadUser, query: CashEntryQueryDto) {
    const tenantId = requireTenantId(user);
    const branchId = resolveBranchIdForFilter(user, query.branch_id);
    const range = resolveRange(query);

    const [salesAgg, ordersCount, entries] = await Promise.all([
      this.prisma.payment.aggregate({
        where: {
          order: {
            tenantId,
            branchId,
            status: 'PAID',
            paidAt: { gte: range.from, lte: range.to },
          },
        },
        _sum: { amount: true },
      }),
      this.prisma.order.count({
        where: {
          tenantId,
          branchId,
          status: 'PAID',
          paidAt: { gte: range.from, lte: range.to },
        },
      }),
      this.prisma.cashEntry.groupBy({
        by: ['type'],
        where: {
          tenantId,
          branchId,
          entryDate: { gte: range.from, lte: range.to },
        },
        _sum: { amount: true },
      }),
    ]);

    let cashIn = 0;
    let cashOut = 0;
    for (const row of entries) {
      const sum = Number(row._sum.amount ?? 0);
      if (row.type === 'CASH_IN') cashIn += sum;
      if (row.type === 'CASH_OUT') cashOut += sum;
    }

    const salesTotal = Number(salesAgg._sum.amount ?? 0);

    return {
      date_from: range.from.toISOString(),
      date_to: range.to.toISOString(),
      branch_id: branchId,
      sales_total: salesTotal,
      sales_orders: ordersCount,
      cash_in: cashIn,
      cash_out: cashOut,
      net_manual: cashIn - cashOut,
      net_total: salesTotal + cashIn - cashOut,
    };
  }

  async remove(user: JwtPayloadUser, id: string) {
    const tenantId = requireTenantId(user);
    const entry = await this.prisma.cashEntry.findFirst({
      where: { id, tenantId },
    });
    if (!entry) throw new NotFoundException('Pencatatan kas tidak ditemukan');

    if (!userHasAnyRole(user, [AppRole.MANAGER, AppRole.OWNER])) {
      if (entry.createdById !== user.sub) {
        throw new ForbiddenException('Hanya pembuat atau manajer yang dapat menghapus');
      }
    }

    await this.prisma.cashEntry.delete({ where: { id } });
  }
}
