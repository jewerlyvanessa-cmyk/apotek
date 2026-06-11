import { ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

type SessionScope = {
  tenantId?: string | null;
  branchId?: string | null;
  role: UserRole | string;
};

function isSuperAdmin(role: UserRole | string): boolean {
  return role === UserRole.SUPER_ADMIN;
}

/**
 * Tenant / cabang nonaktif — blokir semua user tenant kecuali Super Admin.
 */
export async function assertActiveTenantAndBranch(
  prisma: PrismaService,
  user: SessionScope,
  options?: { useUnauthorized?: boolean },
): Promise<void> {
  if (isSuperAdmin(user.role)) return;
  if (!user.tenantId) return;

  const deny = (message: string, code: string) => {
    const err = options?.useUnauthorized
      ? new UnauthorizedException({ message, code })
      : new ForbiddenException({ message, code });
    throw err;
  };

  const tenant = await prisma.tenant.findUnique({
    where: { id: user.tenantId },
    select: { isActive: true },
  });
  if (!tenant?.isActive) {
    deny('Tenant dinonaktifkan', 'TENANT_INACTIVE');
  }

  if (user.branchId) {
    const branch = await prisma.branch.findFirst({
      where: { id: user.branchId, tenantId: user.tenantId },
      select: { isActive: true },
    });
    if (!branch?.isActive) {
      deny('Cabang dinonaktifkan', 'BRANCH_INACTIVE');
    }
  }
}

export async function assertBranchIsActive(
  prisma: PrismaService,
  tenantId: string,
  branchId: string,
): Promise<void> {
  const branch = await prisma.branch.findFirst({
    where: { id: branchId, tenantId },
    select: { isActive: true },
  });
  if (!branch?.isActive) {
    throw new ForbiddenException({
      message: 'Cabang dinonaktifkan',
      code: 'BRANCH_INACTIVE',
    });
  }
}
