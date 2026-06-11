import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';
import { CreateSupplierDto } from './dto/create-supplier.dto';
import { UpdateSupplierDto } from './dto/update-supplier.dto';

@Injectable()
export class SuppliersService {
  constructor(private prisma: PrismaService) {}

  async findAll(tenantId: string, query: PaginationQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where = {
      tenantId,
      ...(query.search
        ? { name: { contains: query.search, mode: 'insensitive' as const } }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.supplier.findMany({
        where,
        skip,
        take: limit,
        orderBy: { name: 'asc' },
      }),
      this.prisma.supplier.count({ where }),
    ]);

    return {
      items,
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async findOne(tenantId: string, id: string) {
    const item = await this.prisma.supplier.findFirst({
      where: { id, tenantId },
    });
    if (!item) throw new NotFoundException('Supplier not found');
    return item;
  }

  async create(tenantId: string, dto: CreateSupplierDto) {
    return this.prisma.supplier.create({
      data: { tenantId, ...dto },
    });
  }

  async update(tenantId: string, id: string, dto: UpdateSupplierDto) {
    await this.findOne(tenantId, id);
    return this.prisma.supplier.update({ where: { id }, data: dto });
  }

  async remove(tenantId: string, id: string) {
    await this.findOne(tenantId, id);

    const used = await this.prisma.medicine.count({
      where: { tenantId, supplierId: id, isActive: true },
    });
    if (used > 0) {
      throw new BadRequestException(
        `Supplier masih dipakai oleh ${used} produk aktif`,
      );
    }

    return this.prisma.supplier.delete({ where: { id } });
  }
}
