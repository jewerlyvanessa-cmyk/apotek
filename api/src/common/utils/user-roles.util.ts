import { BadRequestException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { AppRole, AppRoleName } from '../constants/app-roles';
import { JwtPayloadUser } from '../decorators/current-user.decorator';

const TENANT_ROLES: AppRoleName[] = [
  AppRole.OWNER,
  AppRole.MANAGER,
  AppRole.PHARMACIST,
  AppRole.WAREHOUSE,
  AppRole.CASHIER,
  AppRole.STAFF,
];

const ROLE_PRIORITY: AppRoleName[] = [AppRole.SUPER_ADMIN, ...TENANT_ROLES];

export function normalizeUserRoles(
  roles: UserRole[] | undefined | null,
  fallback: UserRole,
): UserRole[] {
  if (fallback === AppRole.SUPER_ADMIN) return [UserRole.SUPER_ADMIN];
  const merged = [...(roles?.length ? roles : []), fallback].filter(
    (r) => r !== AppRole.SUPER_ADMIN,
  );
  return [...new Set(merged)];
}

export function pickDefaultActiveRole(roles: UserRole[]): UserRole {
  for (const r of ROLE_PRIORITY) {
    if (roles.includes(r)) return r;
  }
  return roles[0];
}

export function resolveActiveRole(
  roles: UserRole[],
  requested?: UserRole,
  current?: UserRole,
): UserRole {
  if (!roles.length) {
    throw new BadRequestException('At least one role is required');
  }
  if (requested) {
    if (!roles.includes(requested)) {
      throw new BadRequestException('active_role must be one of assigned roles');
    }
    return requested;
  }
  if (current && roles.includes(current)) return current;
  return pickDefaultActiveRole(roles);
}

/** Peran aktif sesi (JWT) — untuk otorisasi & scope cabang. */
export function userHasRole(
  user: Pick<JwtPayloadUser, 'role' | 'roles'>,
  role: UserRole,
): boolean {
  return user.role === role;
}

/** Salah satu peran yang ditugaskan ke akun (bukan sesi). */
export function userHasAssignedRole(
  user: Pick<JwtPayloadUser, 'role' | 'roles'>,
  role: UserRole,
): boolean {
  if (user.roles?.includes(role)) return true;
  return user.role === role;
}

/** Otorisasi endpoint — salah satu peran ditugaskan di sesi (bukan hanya peran aktif). */
export function userHasAnyRole(
  user: Pick<JwtPayloadUser, 'role' | 'roles'>,
  roles: readonly (AppRoleName | UserRole)[],
): boolean {
  return roles.some((r) => userHasAssignedRole(user, r));
}

export function isOwnerOrManager(user: Pick<JwtPayloadUser, 'role' | 'roles' | 'branchId'>): boolean {
  if (user.role === AppRole.OWNER) return true;
  return user.role === AppRole.MANAGER && !user.branchId;
}

export function assertTenantRoles(roles: UserRole[]) {
  if (roles.includes(UserRole.SUPER_ADMIN)) {
    throw new BadRequestException('Cannot assign SUPER_ADMIN via tenant user API');
  }
}
