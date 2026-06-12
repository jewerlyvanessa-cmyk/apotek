import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { PlatformPrismaService } from '../../infrastructure/prisma/platform-prisma.service';
import { ProvisionOwnerDto } from './dto/provision-owner.dto';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';
import { CreateBranchDto } from '../branches/dto/create-branch.dto';
import { CreateTenantDto } from './dto/create-tenant.dto';
import { setCentralWarehouseFlag } from '../../common/utils/central-warehouse';
import { ensureBranchStockLocations } from '../../common/utils/stock-location.util';
import { UpdateBranchDto } from './dto/update-branch.dto';
import { UpdateTenantDto } from './dto/update-tenant.dto';
import { LicenseService } from '../license/license.service';
import {
  resolveLicensePlan,
  resolveTenantSubscriptionPlan,
} from '../license/license-plans';
import { LicenseType } from '../license/license.types';
import { ensureDefaultMedicineUnits } from '../../common/utils/medicine-unit-defaults.util';
import { ensureDefaultProductTypes } from '../../common/utils/product-type-defaults.util';

@Injectable()
export class PlatformService {
  constructor(
    private prisma: PlatformPrismaService,
    private license: LicenseService,
  ) {}

  async listTenants(query: PaginationQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where = {
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
      this.prisma.tenant.findMany({
        where,
        skip,
        take: limit,
        orderBy: { name: 'asc' },
        include: { _count: { select: { branches: true, users: true } } },
      }),
      this.prisma.tenant.count({ where }),
    ]);

    return {
      items,
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async getTenant(id: string) {
    const tenant = await this.prisma.tenant.findUnique({
      where: { id },
      include: {
        _count: { select: { branches: true, users: true } },
        users: {
          where: { roles: { has: UserRole.OWNER } },
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            isActive: true,
            createdAt: true,
          },
          orderBy: { createdAt: 'asc' },
        },
      },
    });
    if (!tenant) throw new NotFoundException('Tenant not found');
    const { users, ...rest } = tenant;
    const counts = await this.tenantRelationCounts(id);
    const deleteBlockers = this.formatBlockers(counts, { includeCatalog: true });
    const businessBlockers = this.formatBlockers(counts, {
      includeCatalog: false,
    });
    return {
      ...rest,
      owner: users[0] ?? null,
      owners: users,
      canDeletePermanently: businessBlockers.length === 0,
      deleteBlockers: businessBlockers,
      catalogRemnants: this.formatBlockers(counts, {
        includeCatalog: true,
        catalogOnly: true,
      }),
    };
  }

  private async tenantRelationCounts(tenantId: string) {
    const where = { tenantId };
    const [
      branches,
      users,
      customers,
      suppliers,
      categories,
      medicineUnits,
      productTypes,
      medicines,
      stocks,
      stockMoves,
      orders,
      opnames,
      transfers,
      procurements,
      cashEntries,
      auditLogs,
      deviceTokens,
      stockInternalMoves,
    ] = await Promise.all([
      this.prisma.branch.count({ where }),
      this.prisma.user.count({ where }),
      this.prisma.customer.count({ where }),
      this.prisma.supplier.count({ where }),
      this.prisma.medicineCategory.count({ where }),
      this.prisma.medicineUnit.count({ where }),
      this.prisma.productTypeDefinition.count({ where }),
      this.prisma.medicine.count({ where }),
      this.prisma.stock.count({ where }),
      this.prisma.stockMovement.count({ where }),
      this.prisma.order.count({ where }),
      this.prisma.stockOpname.count({ where }),
      this.prisma.transferStock.count({ where }),
      this.prisma.procurement.count({ where }),
      this.prisma.cashEntry.count({ where }),
      this.prisma.auditLog.count({ where }),
      this.prisma.deviceToken.count({ where }),
      this.prisma.stockInternalMove.count({ where }),
    ]);
    return {
      branches,
      users,
      customers,
      suppliers,
      categories,
      medicineUnits,
      productTypes,
      medicines,
      stocks,
      stockMoves,
      orders,
      opnames,
      transfers,
      procurements,
      cashEntries,
      auditLogs,
      deviceTokens,
      stockInternalMoves,
    };
  }

  private formatBlockers(
    counts: Awaited<ReturnType<PlatformService['tenantRelationCounts']>>,
    opts: { includeCatalog: boolean; catalogOnly?: boolean },
  ): string[] {
    const blockers: string[] = [];
    const push = (count: number, label: string) => {
      if (count > 0) blockers.push(`${count} ${label}`);
    };
    if (opts.catalogOnly) {
      push(counts.categories, 'kategori');
      push(counts.medicineUnits, 'satuan');
      push(counts.productTypes, 'tipe produk');
      return blockers;
    }
    push(counts.branches, 'cabang');
    push(counts.users, 'pengguna');
    push(counts.customers, 'pelanggan');
    push(counts.suppliers, 'supplier');
    if (opts.includeCatalog) {
      push(counts.categories, 'kategori');
      push(counts.medicineUnits, 'satuan');
      push(counts.productTypes, 'tipe produk');
    }
    push(counts.medicines, 'obat');
    push(counts.stocks, 'stok');
    push(counts.stockMoves, 'mutasi stok');
    push(counts.orders, 'order');
    push(counts.opnames, 'opname');
    push(counts.transfers, 'transfer stok');
    push(counts.procurements, 'pengadaan');
    push(counts.cashEntries, 'jurnal kas');
    push(counts.auditLogs, 'log audit');
    push(counts.deviceTokens, 'perangkat notifikasi');
    push(counts.stockInternalMoves, 'mutasi stok internal');
    return blockers;
  }

  private async tenantBusinessBlockers(tenantId: string): Promise<string[]> {
    const counts = await this.tenantRelationCounts(tenantId);
    return this.formatBlockers(counts, { includeCatalog: false });
  }

  /** Hapus sisa katalog default + tenant row (tanpa data bisnis). */
  private async purgeTenantPermanently(tenantId: string) {
    await this.prisma.$transaction(async (tx) => {
      await tx.deviceToken.deleteMany({ where: { tenantId } });
      await tx.auditLog.deleteMany({ where: { tenantId } });
      await tx.customer.deleteMany({ where: { tenantId } });
      await tx.supplier.deleteMany({ where: { tenantId } });
      await tx.medicineCategory.deleteMany({ where: { tenantId } });
      await tx.medicineUnit.deleteMany({ where: { tenantId } });
      await tx.productTypeDefinition.deleteMany({ where: { tenantId } });
      await tx.tenant.delete({ where: { id: tenantId } });
    });
  }

  async createTenant(dto: CreateTenantDto) {
    const exists = await this.prisma.tenant.findUnique({
      where: { code: dto.code },
    });
    if (exists) throw new ConflictException('Tenant code already exists');

    if (dto.owner) {
      await this.assertOwnerEmailAvailable(dto.owner.email);
    }

    const createCentral =
      dto.create_central_warehouse ?? (dto.owner != null ? true : false);

    return this.prisma.$transaction(async (tx) => {
      const tenant = await tx.tenant.create({
        data: {
          name: dto.name,
          code: dto.code,
          phone: dto.phone,
          email: dto.email,
          address: dto.address,
          subscriptionPlan: dto.subscription_plan,
          subscriptionExpiredAt: this.subscriptionExpiredFromPlan(
            dto.subscription_plan,
          ),
        },
      });

      await ensureDefaultProductTypes(tx, tenant.id);
      await ensureDefaultMedicineUnits(tx, tenant.id);

      let centralBranch: { id: string; name: string; code: string | null } | null =
        null;
      if (createCentral) {
        const branchCode = dto.central_branch_code?.trim() || 'PUSAT';
        const branchExists = await tx.branch.findFirst({
          where: { tenantId: tenant.id, code: branchCode },
        });
        if (branchExists) {
          throw new ConflictException(
            `Kode cabang ${branchCode} sudah dipakai di tenant ini`,
          );
        }
        centralBranch = await tx.branch.create({
          data: {
            tenantId: tenant.id,
            name: dto.central_branch_name?.trim() || 'Gudang Pusat',
            code: branchCode,
            isCentralWarehouse: true,
          },
          select: { id: true, name: true, code: true },
        });
      }

      let owner: {
        id: string;
        email: string;
        fullName: string;
        role: UserRole;
      } | null = null;
      if (dto.owner) {
        const passwordHash = await bcrypt.hash(dto.owner.password, 10);
        owner = await tx.user.create({
          data: {
            tenantId: tenant.id,
            branchId: null,
            fullName: dto.owner.full_name.trim(),
            email: dto.owner.email.trim().toLowerCase(),
            phone: dto.owner.phone?.trim() || null,
            passwordHash,
            role: UserRole.OWNER,
            roles: [UserRole.OWNER],
            globalRoles: [UserRole.OWNER],
          },
          select: { id: true, email: true, fullName: true, role: true },
        });
      }

      return {
        ...tenant,
        central_branch: centralBranch,
        owner,
      };
    });
  }

  async provisionOwner(tenantId: string, dto: ProvisionOwnerDto) {
    await this.getTenant(tenantId);
    await this.assertOwnerEmailAvailable(dto.email);

    const existingOwner = await this.prisma.user.findFirst({
      where: { tenantId, roles: { has: UserRole.OWNER } },
    });
    if (existingOwner) {
      throw new BadRequestException(
        'Tenant sudah memiliki owner. Gunakan kelola user sebagai owner.',
      );
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);
    return this.prisma.user.create({
      data: {
        tenantId,
        branchId: null,
        fullName: dto.full_name.trim(),
        email: dto.email.trim().toLowerCase(),
        phone: dto.phone?.trim() || null,
        passwordHash,
        role: UserRole.OWNER,
        roles: [UserRole.OWNER],
        globalRoles: [UserRole.OWNER],
        mustChangePassword: true,
      },
      select: {
        id: true,
        fullName: true,
        email: true,
        role: true,
        roles: true,
        tenantId: true,
      },
    });
  }

  private async assertOwnerEmailAvailable(email: string) {
    const exists = await this.prisma.user.findUnique({
      where: { email: email.trim().toLowerCase() },
    });
    if (exists) throw new ConflictException('Email owner sudah terdaftar');
  }

  private subscriptionExpiredFromPlan(planId?: string | null): Date | null {
    const plan = resolveLicensePlan(planId ?? undefined, 'subscription');
    if (!plan?.days) return null;
    return new Date(Date.now() + plan.days * 86_400_000);
  }

  async extendTenantSubscription(
    tenantId: string,
    input: { plan?: string; extend_days?: number },
  ) {
    const tenant = await this.getTenant(tenantId);
    const plan = input.plan ?? tenant.subscriptionPlan ?? undefined;
    let expiredAt: Date | null = null;

    if (input.extend_days) {
      const base = tenant.subscriptionExpiredAt;
      const start =
        base && base.getTime() > Date.now() ? base.getTime() : Date.now();
      expiredAt = new Date(start + input.extend_days * 86_400_000);
    } else if (plan) {
      expiredAt = this.subscriptionExpiredFromPlan(plan);
    }

    return this.prisma.tenant.update({
      where: { id: tenantId },
      data: {
        ...(plan ? { subscriptionPlan: plan } : {}),
        ...(expiredAt ? { subscriptionExpiredAt: expiredAt } : {}),
        isActive: true,
      },
    });
  }

  async syncTenantSubscriptionFromLicense(
    tenantId: string,
    input: {
      plan?: string;
      type?: string;
      expiresAt?: string | null;
    },
  ) {
    await this.getTenant(tenantId);
    const licenseType: LicenseType =
      input.type === 'subscription' ? 'subscription' : 'perpetual';
    const subscriptionPlan = resolveTenantSubscriptionPlan({
      type: licenseType,
      plan: input.plan,
    });
    const subscriptionExpiredAt = input.expiresAt
      ? new Date(input.expiresAt)
      : null;
    return this.prisma.tenant.update({
      where: { id: tenantId },
      data: {
        subscriptionPlan,
        subscriptionExpiredAt,
        isActive: true,
      },
    });
  }

  async updateTenant(id: string, dto: UpdateTenantDto) {
    await this.getTenant(id);
    return this.prisma.tenant.update({
      where: { id },
      data: {
        ...(dto.name !== undefined ? { name: dto.name } : {}),
        ...(dto.phone !== undefined ? { phone: dto.phone } : {}),
        ...(dto.email !== undefined ? { email: dto.email } : {}),
        ...(dto.address !== undefined ? { address: dto.address } : {}),
        ...(dto.subscription_plan !== undefined
          ? { subscriptionPlan: dto.subscription_plan }
          : {}),
        ...(dto.is_active !== undefined ? { isActive: dto.is_active } : {}),
      },
    });
  }

  async listBranches(tenantId: string, query: PaginationQueryDto) {
    await this.getTenant(tenantId);
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
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  async createBranch(tenantId: string, dto: CreateBranchDto) {
    await this.getTenant(tenantId);
    await this.license.assertBranchLimit(tenantId);
    const branch = await this.prisma.branch.create({
      data: {
        tenantId,
        name: dto.name,
        code: dto.code,
        address: dto.address,
        phone: dto.phone,
      },
    });
    await ensureBranchStockLocations(this.prisma, branch);
    return branch;
  }

  async deleteTenant(id: string) {
    const tenant = await this.prisma.tenant.findUnique({ where: { id } });
    if (!tenant) throw new NotFoundException('Tenant not found');

    const businessBlockers = await this.tenantBusinessBlockers(id);
    if (businessBlockers.length === 0) {
      await this.purgeTenantPermanently(id);
      return {
        id: tenant.id,
        name: tenant.name,
        code: tenant.code,
        permanent: true,
      };
    }

    if (!tenant.isActive) {
      throw new BadRequestException(
        `Tenant tidak dapat dihapus permanen karena masih memiliki: ${businessBlockers.join(', ')}`,
      );
    }

    const deactivated = await this.prisma.$transaction(async (tx) => {
      const users = await tx.user.findMany({
        where: { tenantId: id },
        select: { id: true },
      });
      const userIds = users.map((u) => u.id);
      if (userIds.length) {
        await tx.refreshToken.deleteMany({
          where: { userId: { in: userIds } },
        });
        await tx.user.updateMany({
          where: { tenantId: id },
          data: { isActive: false },
        });
      }
      await tx.branch.updateMany({
        where: { tenantId: id },
        data: { isActive: false },
      });
      return tx.tenant.update({
        where: { id },
        data: { isActive: false },
      });
    });

    return {
      ...deactivated,
      permanent: false,
      deleteBlockers: businessBlockers,
    };
  }

  async deleteBranch(tenantId: string, branchId: string) {
    const branch = await this.prisma.branch.findFirst({
      where: { id: branchId, tenantId },
    });
    if (!branch) throw new NotFoundException('Branch not found');
    if (!branch.isActive) return branch;

    if (branch.isCentralWarehouse) {
      throw new BadRequestException(
        'Cabang gudang pusat tidak dapat dihapus. Jadikan cabang lain sebagai gudang pusat terlebih dahulu.',
      );
    }

    return this.prisma.branch.update({
      where: { id: branchId },
      data: { isActive: false },
    });
  }

  async updateBranch(tenantId: string, branchId: string, dto: UpdateBranchDto) {
    const branch = await this.prisma.branch.findFirst({
      where: { id: branchId, tenantId },
    });
    if (!branch) throw new NotFoundException('Branch not found');

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
        ...(dto.name !== undefined ? { name: dto.name } : {}),
        ...(dto.code !== undefined ? { code: dto.code } : {}),
        ...(dto.address !== undefined ? { address: dto.address } : {}),
        ...(dto.phone !== undefined ? { phone: dto.phone } : {}),
        ...(dto.is_active !== undefined ? { isActive: dto.is_active } : {}),
      },
    });
  }
}
