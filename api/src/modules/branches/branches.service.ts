import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  getCentralWarehouseBranch,
  setCentralWarehouseFlag,
} from '../../common/utils/central-warehouse';
import { ensureBranchStockLocations } from '../../common/utils/stock-location.util';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { LicenseService } from '../license/license.service';
import { BranchQueryDto } from './dto/branch-query.dto';
import { CreateBranchDto } from './dto/create-branch.dto';
import { UpdateBranchDto } from './dto/update-branch.dto';

@Injectable()
export class BranchesService {
  constructor(
    private prisma: PrismaService,
    private license: LicenseService,
  ) {}

  async findAll(tenantId: string, query: BranchQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 50;
    const skip = (page - 1) * limit;

    const where = {
      tenantId,
      isActive: true,
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
      this.prisma.branch.findMany({
        where,
        skip,
        take: limit,
        orderBy: { name: 'asc' },
      }),
      this.prisma.branch.count({ where }),
    ]);

    return {
      items,
      meta: {
        page,
        limit,
        total,
        last_page: Math.ceil(total / limit) || 1,
      },
    };
  }

  async findOne(tenantId: string, branchId: string) {
    const branch = await this.prisma.branch.findFirst({
      where: { id: branchId, tenantId },
    });
    if (!branch) throw new NotFoundException('Cabang tidak ditemukan');
    return branch;
  }

  async create(tenantId: string, dto: CreateBranchDto) {
    await this.license.assertBranchLimit(tenantId);
    if (dto.code?.trim()) {
      const exists = await this.prisma.branch.findFirst({
        where: { tenantId, code: dto.code.trim() },
      });
      if (exists) {
        throw new BadRequestException('Kode cabang sudah dipakai');
      }
    }

    const branch = await this.prisma.branch.create({
      data: {
        tenantId,
        name: dto.name.trim(),
        code: dto.code?.trim() || null,
        address: dto.address?.trim() || null,
        phone: dto.phone?.trim() || null,
      },
    });
    await ensureBranchStockLocations(this.prisma, branch);
    return branch;
  }

  async update(tenantId: string, branchId: string, dto: UpdateBranchDto) {
    await this.findOne(tenantId, branchId);

    if (dto.code !== undefined && dto.code.trim()) {
      const exists = await this.prisma.branch.findFirst({
        where: {
          tenantId,
          code: dto.code.trim(),
          NOT: { id: branchId },
        },
      });
      if (exists) {
        throw new BadRequestException('Kode cabang sudah dipakai');
      }
    }

    if (dto.is_central_warehouse !== undefined) {
      await setCentralWarehouseFlag(
        this.prisma,
        tenantId,
        branchId,
        dto.is_central_warehouse,
      );
    }

    return this.prisma.branch.update({
      where: { id: branchId },
      data: {
        ...(dto.name !== undefined ? { name: dto.name.trim() } : {}),
        ...(dto.code !== undefined
          ? { code: dto.code.trim() || null }
          : {}),
        ...(dto.address !== undefined
          ? { address: dto.address.trim() || null }
          : {}),
        ...(dto.phone !== undefined ? { phone: dto.phone.trim() || null } : {}),
        ...(dto.is_active !== undefined ? { isActive: dto.is_active } : {}),
      },
    });
  }

  async getCentralWarehouse(tenantId: string) {
    return getCentralWarehouseBranch(this.prisma, tenantId);
  }
}
