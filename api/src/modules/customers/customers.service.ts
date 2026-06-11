import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { CustomerTransactionsQueryDto } from './dto/customer-transactions-query.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';

export type ResolveCustomerInput = {
  customer_id?: string;
  customer_name?: string;
  customer_phone?: string;
};

@Injectable()
export class CustomersService {
  constructor(private prisma: PrismaService) {}

  async findAll(tenantId: string, query: PaginationQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where: Prisma.CustomerWhereInput = {
      tenantId,
      isActive: true,
      ...(query.search
        ? {
            OR: [
              { name: { contains: query.search, mode: 'insensitive' } },
              { phone: { contains: query.search, mode: 'insensitive' } },
              { email: { contains: query.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.customer.findMany({
        where,
        skip,
        take: limit,
        orderBy: { name: 'asc' },
      }),
      this.prisma.customer.count({ where }),
    ]);

    return {
      items,
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async findOne(tenantId: string, id: string) {
    const item = await this.prisma.customer.findFirst({
      where: { id, tenantId },
    });
    if (!item) throw new NotFoundException('Customer not found');
    return item;
  }

  async getTransactions(
    tenantId: string,
    customerId: string,
    query: CustomerTransactionsQueryDto,
  ) {
    const customer = await this.findOne(tenantId, customerId);
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

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
      tenantId,
      customerId,
      ...(createdAtFilter ? { createdAt: createdAtFilter } : {}),
    };

    const [items, total, paidAgg] = await Promise.all([
      this.prisma.order.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          orderNumber: true,
          status: true,
          total: true,
          customerName: true,
          paidAt: true,
          createdAt: true,
          branch: { select: { id: true, name: true } },
        },
      }),
      this.prisma.order.count({ where }),
      this.prisma.order.aggregate({
        where: { ...where, status: 'PAID' },
        _sum: { total: true },
        _count: { id: true },
      }),
    ]);

    return {
      customer,
      summary: {
        transaction_count: total,
        paid_count: paidAgg._count.id,
        total_spent: Number(paidAgg._sum.total ?? 0),
        date_from: query.date_from ?? null,
        date_to: query.date_to ?? null,
      },
      items,
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async create(tenantId: string, dto: CreateCustomerDto) {
    return this.prisma.customer.create({
      data: {
        tenantId,
        name: dto.name.trim(),
        phone: dto.phone?.trim() || null,
        email: dto.email?.trim() || null,
        address: dto.address?.trim() || null,
        notes: dto.notes?.trim() || null,
      },
    });
  }

  async update(tenantId: string, id: string, dto: UpdateCustomerDto) {
    await this.findOne(tenantId, id);
    return this.prisma.customer.update({
      where: { id },
      data: {
        ...(dto.name !== undefined ? { name: dto.name.trim() } : {}),
        ...(dto.phone !== undefined ? { phone: dto.phone?.trim() || null } : {}),
        ...(dto.email !== undefined ? { email: dto.email?.trim() || null } : {}),
        ...(dto.address !== undefined ? { address: dto.address?.trim() || null } : {}),
        ...(dto.notes !== undefined ? { notes: dto.notes?.trim() || null } : {}),
        ...(dto.is_active !== undefined ? { isActive: dto.is_active } : {}),
      },
    });
  }

  async remove(tenantId: string, id: string) {
    await this.findOne(tenantId, id);
    return this.prisma.customer.update({
      where: { id },
      data: { isActive: false },
    });
  }

  /** Link order to tenant customer; create record when name is new. */
  async resolveForOrder(
    tenantId: string,
    input: ResolveCustomerInput,
    tx?: Prisma.TransactionClient,
  ) {
    const db = tx ?? this.prisma;

    if (input.customer_id) {
      const existing = await db.customer.findFirst({
        where: { id: input.customer_id, tenantId, isActive: true },
      });
      if (!existing) throw new NotFoundException('Customer not found');
      return existing;
    }

    const name = input.customer_name?.trim();
    if (!name) return null;

    const phone = input.customer_phone?.trim() || undefined;

    if (phone) {
      const byPhone = await db.customer.findFirst({
        where: { tenantId, phone, isActive: true },
      });
      if (byPhone) return byPhone;
    }

    const byName = await db.customer.findFirst({
      where: {
        tenantId,
        isActive: true,
        name: { equals: name, mode: 'insensitive' },
      },
    });
    if (byName) {
      if (phone && !byName.phone) {
        return db.customer.update({
          where: { id: byName.id },
          data: { phone },
        });
      }
      return byName;
    }

    return db.customer.create({
      data: { tenantId, name, phone: phone ?? null },
    });
  }
}
