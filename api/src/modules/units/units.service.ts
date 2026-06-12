import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';
import {
  ensureDefaultMedicineUnits,
  normalizeMedicineUnitName,
} from '../../common/utils/medicine-unit-defaults.util';
import { CreateUnitDto } from './dto/create-unit.dto';
import { UpdateUnitDto } from './dto/update-unit.dto';

@Injectable()
export class UnitsService {
  constructor(private prisma: PrismaService) {}

  async findAll(tenantId: string, query: PaginationQueryDto) {
    await ensureDefaultMedicineUnits(this.prisma, tenantId);

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
      this.prisma.medicineUnit.findMany({
        where,
        skip,
        take: limit,
        orderBy: { name: 'asc' },
      }),
      this.prisma.medicineUnit.count({ where }),
    ]);

    return {
      items,
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async findOne(tenantId: string, id: string) {
    const item = await this.prisma.medicineUnit.findFirst({
      where: { id, tenantId },
    });
    if (!item) throw new NotFoundException('Satuan tidak ditemukan');
    return item;
  }

  async create(tenantId: string, dto: CreateUnitDto) {
    const name = normalizeMedicineUnitName(dto.name);
    if (!name) {
      throw new BadRequestException('Nama satuan wajib diisi');
    }
    try {
      return await this.prisma.medicineUnit.create({
        data: { tenantId, name },
      });
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        throw new ConflictException(`Satuan "${name}" sudah ada`);
      }
      throw e;
    }
  }

  async update(tenantId: string, id: string, dto: UpdateUnitDto) {
    const existing = await this.findOne(tenantId, id);
    const name = normalizeMedicineUnitName(dto.name);
    if (!name) {
      throw new BadRequestException('Nama satuan wajib diisi');
    }

    try {
      return await this.prisma.$transaction(async (tx) => {
        const updated = await tx.medicineUnit.update({
          where: { id },
          data: { name },
        });
        if (existing.name !== name) {
          await tx.medicine.updateMany({
            where: { tenantId, unit: existing.name },
            data: { unit: name },
          });
        }
        return updated;
      });
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        throw new ConflictException(`Satuan "${name}" sudah ada`);
      }
      throw e;
    }
  }

  async remove(tenantId: string, id: string) {
    const item = await this.findOne(tenantId, id);

    const used = await this.prisma.medicine.count({
      where: { tenantId, unit: item.name, isActive: true },
    });
    if (used > 0) {
      throw new BadRequestException(
        `Satuan masih dipakai oleh ${used} produk aktif`,
      );
    }

    return this.prisma.medicineUnit.delete({ where: { id } });
  }
}
