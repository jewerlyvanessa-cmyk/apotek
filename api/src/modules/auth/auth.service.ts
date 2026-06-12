import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { User, UserRole } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';
import { AuditLogRequestMeta, AuditLogsService } from '../audit-logs/audit-logs.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import {
  normalizeUserRoles,
  resolveActiveRole,
} from '../../common/utils/user-roles.util';
import {
  assertActiveTenantAndBranch,
  assertBranchIsActive,
} from '../../common/utils/tenant-access.util';
import { TENANT_PUBLIC_SELECT } from '../../common/utils/tenant-access.context';
import { LicenseService } from '../license/license.service';
import {
  assertRoleAllowedInContext,
  pickRoleForBranch,
  resolveSessionRoles,
} from '../users/user-branches.util';
import { ChangePasswordDto } from './dto/change-password.dto';
import { LoginDto } from './dto/login.dto';
import { SwitchBranchDto } from './dto/switch-branch.dto';
import { SwitchRoleDto } from './dto/switch-role.dto';

const branchPublicSelect = {
  id: true,
  name: true,
  code: true,
  isActive: true,
} as const;

const userRelationsInclude = {
  tenant: { select: TENANT_PUBLIC_SELECT },
  branch: { select: branchPublicSelect },
  userBranches: {
    select: {
      branchId: true,
      roles: true,
      branch: { select: branchPublicSelect },
    },
  },
} as const;

type UserWithRelations = User & {
  tenant: { id: string; name: string; code: string } | null;
  branch: {
    id: string;
    name: string;
    code: string | null;
    isActive: boolean;
  } | null;
  globalRoles: UserRole[];
  userBranches: {
    branchId: string;
    roles: UserRole[];
    branch: {
      id: string;
      name: string;
      code: string | null;
      isActive: boolean;
    };
  }[];
};

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private config: ConfigService,
    private auditLogs: AuditLogsService,
    private license: LicenseService,
  ) {}

  private branchAssignments(user: UserWithRelations) {
    return user.userBranches.map((ub) => ({
      branchId: ub.branchId,
      roles: ub.roles,
    }));
  }

  async changePassword(userId: string, dto: ChangePasswordDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    const valid = await bcrypt.compare(dto.current_password, user.passwordHash);
    if (!valid) {
      throw new BadRequestException('Password saat ini tidak sesuai');
    }

    if (dto.current_password === dto.new_password) {
      throw new BadRequestException(
        'Password baru harus berbeda dari password saat ini',
      );
    }

    const passwordHash = await bcrypt.hash(dto.new_password, 10);
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        passwordHash,
        mustChangePassword: false,
      },
    });

    return { message: 'Password berhasil diperbarui' };
  }

  async login(dto: LoginDto, meta?: AuditLogRequestMeta) {
    const user = await this.prisma.user.findFirst({
      where: { email: dto.email, isActive: true },
      include: userRelationsInclude,
    });

    if (!user) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const sessionUser = await this.applySessionRole(user, dto.active_role);
    if (sessionUser.tenantId) {
      await this.license.assertTenantAccess(sessionUser.tenantId);
      await assertActiveTenantAndBranch(this.prisma, sessionUser);
    }
    const sessionRoles = this.sessionRoles(sessionUser);
    const tokens = await this.generateTokens(sessionUser, sessionRoles);
    await this.saveRefreshToken(
      sessionUser.id,
      tokens.refresh_token,
      dto.device_name,
    );

    if (sessionUser.tenantId) {
      await this.auditLogs.log({
        tenantId: sessionUser.tenantId,
        userId: sessionUser.id,
        module: 'AUTH',
        action: 'LOGIN',
        referenceId: sessionUser.id,
        newData: {
          device_name: dto.device_name,
          email: sessionUser.email,
          role: sessionUser.role,
          roles: sessionRoles,
          branch_id: sessionUser.branchId,
        },
        ...meta,
      });
    }

    return {
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      expires_in: parseInt(this.config.get('JWT_EXPIRES_IN', '3600'), 10),
      user: this.formatUser(sessionUser),
    };
  }

  async switchRole(userId: string, dto: SwitchRoleDto) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, isActive: true },
      include: userRelationsInclude,
    });
    if (!user) throw new UnauthorizedException('User not found');

    const sessionUser = await this.applySessionRole(user, dto.role);
    if (sessionUser.tenantId) {
      await this.license.assertTenantAccess(sessionUser.tenantId);
      await assertActiveTenantAndBranch(this.prisma, sessionUser);
    }
    const sessionRoles = this.sessionRoles(sessionUser);
    const tokens = await this.generateTokens(sessionUser, sessionRoles);
    await this.prisma.refreshToken.deleteMany({ where: { userId } });
    await this.saveRefreshToken(userId, tokens.refresh_token);

    return {
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      expires_in: parseInt(this.config.get('JWT_EXPIRES_IN', '3600'), 10),
      user: this.formatUser(sessionUser),
    };
  }

  async switchBranch(userId: string, dto: SwitchBranchDto) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, isActive: true },
      include: userRelationsInclude,
    });
    if (!user) throw new UnauthorizedException('User not found');

    const assignments = this.branchAssignments(user);
    const allowed = assignments.map((a) => a.branchId);
    if (!allowed.includes(dto.branch_id)) {
      throw new ForbiddenException('Cabang tidak ditugaskan ke akun ini');
    }
    if (user.tenantId) {
      await assertBranchIsActive(this.prisma, user.tenantId, dto.branch_id);
    }

    const branchRoles = assignments.find((a) => a.branchId === dto.branch_id)?.roles ?? [];
    let nextRole: UserRole;
    if (dto.role) {
      assertRoleAllowedInContext(
        dto.role,
        dto.branch_id,
        user.globalRoles ?? [],
        assignments,
      );
      nextRole = dto.role;
    } else if (branchRoles.includes(user.role)) {
      nextRole = user.role;
    } else {
      nextRole = pickRoleForBranch(assignments, dto.branch_id, user.role);
    }

    const sessionUser = await this.prisma.user.update({
      where: { id: userId },
      data: { branchId: dto.branch_id, role: nextRole },
      include: userRelationsInclude,
    });

    if (sessionUser.tenantId) {
      await this.license.assertTenantAccess(sessionUser.tenantId);
      await assertActiveTenantAndBranch(this.prisma, sessionUser);
    }
    const sessionRoles = this.sessionRoles(sessionUser);
    const tokens = await this.generateTokens(sessionUser, sessionRoles);
    await this.prisma.refreshToken.deleteMany({ where: { userId } });
    await this.saveRefreshToken(userId, tokens.refresh_token);

    return {
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      expires_in: parseInt(this.config.get('JWT_EXPIRES_IN', '3600'), 10),
      user: this.formatUser(sessionUser),
    };
  }

  async refresh(refreshToken: string) {
    const stored = await this.prisma.refreshToken.findUnique({
      where: { token: refreshToken },
    });
    if (!stored || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const user = await this.prisma.user.findFirst({
      where: { id: stored.userId, isActive: true },
      include: {
        userBranches: { select: { branchId: true, roles: true } },
      },
    });
    if (!user) throw new UnauthorizedException('User not found');
    if (user.tenantId) {
      await this.license.assertTenantAccess(user.tenantId);
      await assertActiveTenantAndBranch(this.prisma, user, {
        useUnauthorized: true,
      });
    }

    await this.prisma.refreshToken.delete({ where: { id: stored.id } });
    const sessionRoles = resolveSessionRoles(
      user,
      user.userBranches.map((ub) => ({
        branchId: ub.branchId,
        roles: ub.roles,
      })),
      user.branchId,
    );
    const tokens = await this.generateTokens(user, sessionRoles);
    await this.saveRefreshToken(user.id, tokens.refresh_token);

    return {
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      expires_in: parseInt(this.config.get('JWT_EXPIRES_IN', '3600'), 10),
    };
  }

  async logout(refreshToken?: string) {
    if (refreshToken) {
      await this.prisma.refreshToken.deleteMany({
        where: { token: refreshToken },
      });
    }
    return { message: 'Logged out' };
  }

  async me(userId: string) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, isActive: true },
      include: userRelationsInclude,
    });
    if (!user) throw new UnauthorizedException('User not found');

    return this.formatUser(user);
  }

  private sessionRoles(user: UserWithRelations): UserRole[] {
    return resolveSessionRoles(user, this.branchAssignments(user), user.branchId);
  }

  private async applySessionRole(
    user: UserWithRelations,
    requested?: UserRole,
  ): Promise<UserWithRelations> {
    let sessionUser = user;

    const isOwner =
      sessionUser.role === UserRole.OWNER ||
      sessionUser.roles?.includes(UserRole.OWNER);
    if (isOwner && !(sessionUser.globalRoles ?? []).includes(UserRole.OWNER)) {
      sessionUser = await this.prisma.user.update({
        where: { id: sessionUser.id },
        data: {
          globalRoles: [UserRole.OWNER],
          branchId:
            sessionUser.userBranches.length > 0 ? sessionUser.branchId : null,
        },
        include: userRelationsInclude,
      });
    }

    const assignments = this.branchAssignments(sessionUser);
    const contextRoles = resolveSessionRoles(
      sessionUser,
      assignments,
      sessionUser.branchId,
    );
    if (!contextRoles.length) {
      throw new BadRequestException('Akun tidak memiliki peran yang valid');
    }

    const roles = normalizeUserRoles(contextRoles, sessionUser.role);
    const activeRole = resolveActiveRole(roles, requested, sessionUser.role);

    if (!roles.includes(activeRole)) {
      throw new BadRequestException('Peran tidak sesuai cabang aktif');
    }

    const needsRoleUpdate = activeRole !== sessionUser.role;

    if (!needsRoleUpdate) return sessionUser;

    return this.prisma.user.update({
      where: { id: sessionUser.id },
      data: { role: activeRole },
      include: userRelationsInclude,
    });
  }

  private formatUser(user: UserWithRelations) {
    const activeUserBranches = user.userBranches.filter(
      (ub) => ub.branch.isActive !== false,
    );
    const assignments = activeUserBranches.map((ub) => ({
      branch_id: ub.branch.id,
      roles: ub.roles,
      branch: {
        id: ub.branch.id,
        name: ub.branch.name,
        code: ub.branch.code ?? '',
      },
    }));
    const branches = assignments.map((a) => a.branch);
    const branchIds = branches.map((b) => b.id);
    const sessionRoles = this.sessionRoles(user);
    const branchIsActive = (id: string | null | undefined) =>
      id != null &&
      (user.branch?.id === id
        ? user.branch.isActive !== false
        : activeUserBranches.some(
            (ub) => ub.branchId === id && ub.branch.isActive !== false,
          ));

    let activeBranchId =
      user.branchId ?? (branchIds.length === 1 ? branchIds[0] : null);
    if (activeBranchId && !branchIsActive(activeBranchId)) {
      activeBranchId = branchIds.length === 1 ? branchIds[0] : null;
    }
    const activeBranch =
      (user.branch?.isActive !== false ? user.branch : null) ??
      (activeBranchId
        ? branches.find((b) => b.id === activeBranchId) ?? null
        : null);

    return {
      id: user.id,
      name: user.fullName,
      email: user.email,
      must_change_password: user.mustChangePassword,
      role: user.role,
      roles: sessionRoles,
      global_roles: user.globalRoles ?? [],
      tenant_id: user.tenantId,
      branch_id: activeBranchId,
      branch_ids: branchIds.length ? branchIds : undefined,
      branch_assignments: assignments.length ? assignments : undefined,
      tenant: user.tenant
        ? {
            id: user.tenant.id,
            name: user.tenant.name,
            code: user.tenant.code,
          }
        : null,
      branch: activeBranch
        ? {
            id: activeBranch.id,
            name: activeBranch.name,
            code: activeBranch.code ?? '',
          }
        : null,
      branches: branches.length ? branches : undefined,
    };
  }

  private async generateTokens(
    user: Pick<User, 'id' | 'email' | 'tenantId' | 'branchId' | 'role'>,
    roles: UserRole[],
  ) {
    const payload = {
      sub: user.id,
      email: user.email,
      ...(user.tenantId ? { tenantId: user.tenantId } : {}),
      branchId: user.branchId ?? undefined,
      role: user.role,
      roles,
    };

    const access_token = await this.jwt.signAsync(payload, {
      secret: this.config.get('JWT_SECRET'),
      expiresIn: parseInt(this.config.get('JWT_EXPIRES_IN', '3600'), 10),
    });

    const refresh_token = randomBytes(48).toString('hex');
    return { access_token, refresh_token };
  }

  private async saveRefreshToken(
    userId: string,
    token: string,
    deviceName?: string,
  ) {
    const days = 7;
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + days);

    await this.prisma.refreshToken.create({
      data: {
        userId,
        token,
        deviceName,
        expiresAt,
      },
    });
  }
}
