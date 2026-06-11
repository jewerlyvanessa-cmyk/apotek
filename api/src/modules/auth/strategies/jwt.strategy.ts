import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { UserRole } from '@prisma/client';
import { PrismaService } from '../../../infrastructure/prisma/prisma.service';
import { JwtPayloadUser } from '../../../common/decorators/current-user.decorator';
import { assertActiveTenantAndBranch } from '../../../common/utils/tenant-access.util';
import { normalizeUserRoles } from '../../../common/utils/user-roles.util';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    config: ConfigService,
    private prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_SECRET') ?? 'dev-secret',
    });
  }

  async validate(payload: {
    sub: string;
    email: string;
    tenantId?: string;
    branchId?: string;
    role: string;
    roles?: UserRole[];
  }): Promise<JwtPayloadUser> {
    const user = await this.prisma.user.findFirst({
      where: { id: payload.sub, isActive: true },
      include: {
        userBranches: { select: { branchId: true, roles: true } },
      },
    });
    if (!user) throw new UnauthorizedException('User not found');
    await assertActiveTenantAndBranch(
      this.prisma,
      {
        tenantId: user.tenantId,
        branchId: user.branchId,
        role: user.role,
      },
      { useUnauthorized: true },
    );
    const roles = normalizeUserRoles(user.roles, user.role);
    const activeRole = user.role;
    const allBranchIds = user.userBranches.map((ub) => ub.branchId);
    const roleScopedIds = user.userBranches
      .filter((ub) => ub.roles.includes(activeRole))
      .map((ub) => ub.branchId);
    const branchIds =
      roleScopedIds.length > 0 ? roleScopedIds : allBranchIds;
    let branchId = user.branchId ?? undefined;
    if (branchId && branchIds.length > 0 && !branchIds.includes(branchId)) {
      branchId = branchIds.length === 1 ? branchIds[0] : undefined;
    }
    if (!branchId && branchIds.length === 1) {
      branchId = branchIds[0];
    }
    return {
      sub: user.id,
      email: user.email,
      tenantId: user.tenantId ?? undefined,
      branchId,
      branchIds: branchIds.length ? branchIds : undefined,
      role: user.role,
      roles,
    };
  }
}
