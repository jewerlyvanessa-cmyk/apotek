import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';

@Injectable()
export class CategoriesService {
  constructor(private prisma: PrismaService) {}

  async findAll(tenantId: string, query: PaginationQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 50;
    const skip = (page - 1) * limit;

    const where = {
      tenantId,
      ...(query.search
        ? { name: { contains: query.search, mode: 'insensitive' as const } }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.medicineCategory.findMany({
        where,
        skip,
        take: limit,
        orderBy: { name: 'asc' },
      }),
      this.prisma.medicineCategory.count({ where }),
    ]);

    return {
      items,
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async findOne(tenantId: string, id: string) {
    const item = await this.prisma.medicineCategory.findFirst({
      where: { id, tenantId },
    });
    if (!item) throw new NotFoundException('Kategori tidak ditemukan');
    return item;
  }

  async create(tenantId: string, dto: CreateCategoryDto) {
    const name = dto.name.trim();
    try {
      return await this.prisma.medicineCategory.create({
        data: { tenantId, name },
      });
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        throw new ConflictException(`Kategori "${name}" sudah ada`);
      }
      throw e;
    }
  }

  async update(tenantId: string, id: string, dto: UpdateCategoryDto) {
    await this.findOne(tenantId, id);
    const name = dto.name.trim();
    try {
      return await this.prisma.medicineCategory.update({
        where: { id },
        data: { name },
      });
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        throw new ConflictException(`Kategori "${name}" sudah ada`);
      }
      throw e;
    }
  }

  async remove(tenantId: string, id: string) {
    await this.findOne(tenantId, id);

    const used = await this.prisma.medicine.count({
      where: { tenantId, categoryId: id, isActive: true },
    });
    if (used > 0) {
      throw new BadRequestException(
        `Kategori masih dipakai oleh ${used} produk aktif`,
      );
    }

    return this.prisma.medicineCategory.delete({ where: { id } });
  }
}
