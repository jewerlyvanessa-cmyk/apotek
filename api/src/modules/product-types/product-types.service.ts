import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';
import { ensureDefaultProductTypes } from '../../common/utils/product-type-defaults.util';
import { CreateProductTypeDto } from './dto/create-product-type.dto';
import { UpdateProductTypeDto } from './dto/update-product-type.dto';

@Injectable()
export class ProductTypesService {
  constructor(private prisma: PrismaService) {}

  async findAll(tenantId: string, query: PaginationQueryDto) {
    await ensureDefaultProductTypes(this.prisma, tenantId);

    const page = query.page ?? 1;
    const limit = query.limit ?? 50;
    const skip = (page - 1) * limit;

    const where = {
      tenantId,
      ...(query.search
        ? {
            OR: [
              { name: { contains: query.search, mode: 'insensitive' as const } },
              { code: { contains: query.search, mode: 'insensitive' as const } },
            ],
          }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.productTypeDefinition.findMany({
        where,
        skip,
        take: limit,
        orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      }),
      this.prisma.productTypeDefinition.count({ where }),
    ]);

    return {
      items,
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async findOne(tenantId: string, id: string) {
    await ensureDefaultProductTypes(this.prisma, tenantId);
    const item = await this.prisma.productTypeDefinition.findFirst({
      where: { id, tenantId },
    });
    if (!item) throw new NotFoundException('Tipe produk tidak ditemukan');
    return item;
  }

  async create(tenantId: string, dto: CreateProductTypeDto) {
    await ensureDefaultProductTypes(this.prisma, tenantId);
    const code = dto.code.trim().toUpperCase();

    const exists = await this.prisma.productTypeDefinition.findFirst({
      where: { tenantId, code },
    });
    if (exists) {
      throw new ConflictException(`Kode tipe produk ${code} sudah dipakai`);
    }

    return this.prisma.productTypeDefinition.create({
      data: {
        tenantId,
        code,
        name: dto.name.trim(),
        allowsPrescription: dto.allows_prescription ?? false,
        sortOrder: dto.sort_order ?? 0,
      },
    });
  }

  async update(tenantId: string, id: string, dto: UpdateProductTypeDto) {
    const existing = await this.findOne(tenantId, id);

    if (dto.code && dto.code.trim().toUpperCase() !== existing.code) {
      const code = dto.code.trim().toUpperCase();
      const dup = await this.prisma.productTypeDefinition.findFirst({
        where: { tenantId, code, NOT: { id } },
      });
      if (dup) {
        throw new ConflictException(`Kode tipe produk ${code} sudah dipakai`);
      }
    }

    return this.prisma.productTypeDefinition.update({
      where: { id },
      data: {
        code: dto.code?.trim().toUpperCase(),
        name: dto.name?.trim(),
        allowsPrescription: dto.allows_prescription,
        isActive: dto.is_active,
        sortOrder: dto.sort_order,
      },
    });
  }

  async remove(tenantId: string, id: string) {
    await this.findOne(tenantId, id);

    const used = await this.prisma.medicine.count({
      where: { tenantId, productTypeId: id, isActive: true },
    });
    if (used > 0) {
      throw new BadRequestException(
        `Tipe produk masih dipakai oleh ${used} produk aktif`,
      );
    }

    return this.prisma.productTypeDefinition.delete({ where: { id } });
  }
}
