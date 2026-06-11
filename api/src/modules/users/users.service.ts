import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';
import {
  assertTenantRoles,
  normalizeUserRoles,
  resolveActiveRole,
} from '../../common/utils/user-roles.util';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateRoleDto } from './dto/update-role.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import {
  assertValidAssignments,
  resolveAssignmentsFromDto,
  sessionRolesForContext,
  syncUserBranchAssignments,
} from './user-branches.util';

const userListSelect = {
  id: true,
  fullName: true,
  email: true,
  phone: true,
  role: true,
  roles: true,
  globalRoles: true,
  branchId: true,
  isActive: true,
  createdAt: true,
  branch: { select: { id: true, name: true } },
  userBranches: {
    select: {
      branchId: true,
      roles: true,
      branch: { select: { id: true, name: true, code: true } },
    },
  },
} as const;

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async findAll(tenantId: string, query: PaginationQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where = {
      tenantId,
      ...(query.search
        ? {
            OR: [
              { fullName: { contains: query.search, mode: 'insensitive' as const } },
              { email: { contains: query.search, mode: 'insensitive' as const } },
            ],
          }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        skip,
        take: limit,
        select: userListSelect,
        orderBy: { fullName: 'asc' },
      }),
      this.prisma.user.count({ where }),
    ]);

    return {
      items: items.map((u) => this.mapUserBranches(u)),
      meta: { page, limit, total, last_page: Math.ceil(total / limit) || 1 },
    };
  }

  private mapUserBranches<
    T extends {
      globalRoles?: UserRole[];
      userBranches?: {
        branchId: string;
        roles: UserRole[];
        branch: { id: string; name: string; code: string | null };
      }[];
    },
  >(user: T) {
    const branchAssignments =
      user.userBranches?.map((ub) => ({
        branch_id: ub.branch.id,
        roles: ub.roles,
        branch: {
          id: ub.branch.id,
          name: ub.branch.name,
          code: ub.branch.code,
        },
      })) ?? [];
    const branches = branchAssignments.map((a) => a.branch);
    const { userBranches: _drop, globalRoles, ...rest } = user as T & {
      userBranches?: unknown;
      globalRoles?: UserRole[];
    };
    return {
      ...rest,
      global_roles: globalRoles ?? [],
      branch_assignments: branchAssignments,
      branches,
    };
  }

  async create(tenantId: string, dto: CreateUserDto) {
    const { globalRoles, assignments } = resolveAssignmentsFromDto(dto);
    assertValidAssignments(globalRoles, assignments);
    assertTenantRoles([...globalRoles, ...assignments.flatMap((a) => a.roles)]);

    const exists = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (exists) throw new ConflictException('Email already registered');

    const unionRoles = [
      ...new Set([...globalRoles, ...assignments.flatMap((a) => a.roles)]),
    ];
    const contextBranchId =
      dto.branch_id ?? assignments[0]?.branchId ?? null;
    const contextRoles = sessionRolesForContext(
      globalRoles,
      assignments,
      contextBranchId,
    );
    const roles = normalizeUserRoles(
      contextRoles.length ? contextRoles : unionRoles,
      dto.active_role ?? unionRoles[0],
    );
    const activeRole = resolveActiveRole(roles, dto.active_role);
    const passwordHash = await bcrypt.hash(dto.password, 10);

    const user = await this.prisma.user.create({
      data: {
        tenantId,
        branchId: contextBranchId,
        fullName: dto.full_name,
        email: dto.email,
        phone: dto.phone,
        passwordHash,
        role: activeRole,
        roles: unionRoles,
        globalRoles,
      },
      select: userListSelect,
    });

    if (assignments.length || globalRoles.length) {
      await syncUserBranchAssignments(this.prisma, {
        userId: user.id,
        tenantId,
        globalRoles,
        assignments,
        primaryBranchId: contextBranchId,
      });
    }

    const refreshed = await this.prisma.user.findUnique({
      where: { id: user.id },
      select: userListSelect,
    });
    return this.mapUserBranches(refreshed!);
  }

  async updateRole(tenantId: string, userId: string, dto: UpdateRoleDto) {
    assertTenantRoles(dto.roles);
    const user = await this.prisma.user.findFirst({
      where: { id: userId, tenantId },
      include: { userBranches: { select: { branchId: true, roles: true } } },
    });
    if (!user) throw new NotFoundException('User not found');

    const contextRoles = sessionRolesForContext(
      user.globalRoles,
      user.userBranches.map((ub) => ({
        branchId: ub.branchId,
        roles: ub.roles,
      })),
      user.branchId,
    );
    const roles = normalizeUserRoles(
      contextRoles.length ? contextRoles : dto.roles,
      user.role,
    );
    const activeRole = resolveActiveRole(roles, dto.active_role, user.role);

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: { role: activeRole, roles: dto.roles },
      select: userListSelect,
    });
    return this.mapUserBranches(updated);
  }

  async update(
    tenantId: string,
    userId: string,
    dto: UpdateUserDto,
    actorId?: string,
  ) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, tenantId },
    });
    if (!user) throw new NotFoundException('User not found');

    if (dto.is_active === false && actorId && userId === actorId) {
      throw new BadRequestException('Tidak dapat menonaktifkan akun sendiri');
    }

    if (dto.is_active === false) {
      await this.prisma.refreshToken.deleteMany({ where: { userId } });
    }

    let primaryBranchId = dto.branch_id;
    let dataPatch: Record<string, unknown> = {
      ...(dto.full_name !== undefined ? { fullName: dto.full_name } : {}),
      ...(dto.phone !== undefined ? { phone: dto.phone } : {}),
      ...(dto.is_active !== undefined ? { isActive: dto.is_active } : {}),
    };

    if (
      dto.branch_assignments !== undefined ||
      dto.global_roles !== undefined ||
      dto.branch_ids !== undefined
    ) {
      const existing = await this.prisma.user.findFirst({
        where: { id: userId, tenantId },
        include: {
          userBranches: { select: { branchId: true, roles: true } },
        },
      });
      const currentGlobal = existing!.globalRoles ?? [];
      const currentAssignments =
        existing!.userBranches.map((ub) => ({
          branchId: ub.branchId,
          roles: ub.roles,
        })) ?? [];

      const { globalRoles, assignments } = resolveAssignmentsFromDto({
        global_roles: dto.global_roles ?? currentGlobal,
        branch_assignments: dto.branch_assignments,
        branch_ids: dto.branch_ids,
        branch_id: dto.branch_id,
        roles: existing!.roles,
      });
      assertValidAssignments(globalRoles, assignments);
      assertTenantRoles([...globalRoles, ...assignments.flatMap((a) => a.roles)]);

      const synced = await syncUserBranchAssignments(this.prisma, {
        userId,
        tenantId,
        globalRoles,
        assignments,
        primaryBranchId: dto.branch_id ?? undefined,
      });
      primaryBranchId = synced.primaryBranchId;
    } else if (dto.branch_id !== undefined) {
      primaryBranchId = dto.branch_id;
    }

    if (primaryBranchId !== undefined) {
      dataPatch = { ...dataPatch, branchId: primaryBranchId };
    }

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: dataPatch,
      select: userListSelect,
    });
    return this.mapUserBranches(updated);
  }

  async remove(tenantId: string, userId: string, actorId?: string) {
    return this.update(tenantId, userId, { is_active: false }, actorId);
  }

  async resetPassword(tenantId: string, userId: string, newPassword: string) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, tenantId },
    });
    if (!user) throw new NotFoundException('User not found');

    const passwordHash = await bcrypt.hash(newPassword, 10);
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: { passwordHash },
      }),
      this.prisma.refreshToken.deleteMany({ where: { userId } }),
    ]);

    return { id: userId };
  }
}
